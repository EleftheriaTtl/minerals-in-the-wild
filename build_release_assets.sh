#!/usr/bin/env bash
# Build the GitHub Release assets from the local source dataset.
#
# Usage:
#   ./build_release_assets.sh /absolute/path/to/linear_unmixing
# or:
#   SRC=/absolute/path/to/linear_unmixing ./build_release_assets.sh
set -euo pipefail

SRC="${1:-${SRC:-}}"
if [[ -z "$SRC" ]]; then
  echo "Error: provide the source dataset directory as the first argument or SRC." >&2
  exit 2
fi

SRC="$(cd "$SRC" && pwd)"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$ROOT/release_assets"
MASKED="$SRC/masked"
XRF="$SRC/final_xrf_elements.csv"

[[ -d "$MASKED" ]] || { echo "Error: missing directory: $MASKED" >&2; exit 2; }
[[ -f "$XRF" ]] || { echo "Error: missing file: $XRF" >&2; exit 2; }

mkdir -p "$OUT"

python3 - "$MASKED" "$XRF" "$OUT" <<'PY'
import csv
import glob
import hashlib
import math
import os
import sys
import zipfile

masked, xrf_source, out = sys.argv[1:]
limit = 1_400 * 1024 * 1024

for old in glob.glob(os.path.join(out, "hsi_cubes_part*.zip")):
    os.remove(old)
for name in ("xrf_elements.csv", "SHA256SUMS", "asset_manifest.csv"):
    path = os.path.join(out, name)
    if os.path.exists(path):
        os.remove(path)

files = sorted(
    glob.glob(os.path.join(masked, "sample_*.npy")),
    key=lambda path: int(os.path.basename(path)[7:-4]),
)
if not files:
    raise SystemExit(f"No sample_*.npy cubes found in {masked}")

expected_names = [f"sample_{i}.npy" for i in range(len(files))]
actual_names = [os.path.basename(path) for path in files]
if actual_names != expected_names:
    raise SystemExit("Cube identifiers are missing, duplicated, or non-contiguous")

# Filter the internal conversion output to the exact 51-element target used by
# the unmixing evaluation. O and C are stoichiometric byproducts, while Missing
# is a closure residual rather than an element. The retained elements are
# rescaled to preserve the original measured fraction (1 - Missing), matching
# filter_and_renormalize and making this operation idempotent downstream.
kept_elements = (
    "Ag", "Al", "As", "Au", "Ba", "Bi", "Br", "Ca", "Cd", "Ce", "Cl",
    "Co", "Cr", "Cu", "Fe", "Ga", "Hf", "Hg", "In", "K", "La", "Mg",
    "Mn", "Mo", "Nb", "Ni", "P", "Pb", "Pd", "Pt", "Rb", "Re", "Rh",
    "Ru", "S", "Sb", "Se", "Si", "Sn", "Sr", "Ta", "Te", "Th", "Ti",
    "Tl", "U", "V", "W", "Y", "Zn", "Zr",
)
if len(kept_elements) != 51 or len(set(kept_elements)) != 51:
    raise SystemExit("Internal error: the release schema must contain 51 unique elements")

with open(xrf_source, newline="", encoding="utf-8-sig") as stream:
    reader = csv.DictReader(stream)
    source_header = reader.fieldnames or []
    required = {"Name", "O", "C", "Missing", *kept_elements}
    missing_columns = sorted(required - set(source_header))
    unexpected_columns = sorted(set(source_header) - required)
    if missing_columns:
        raise SystemExit(f"XRF input is missing required columns: {missing_columns}")
    if unexpected_columns:
        raise SystemExit(f"XRF input contains unexpected columns: {unexpected_columns}")
    source_rows = list(reader)

if len(source_rows) != len(files):
    raise SystemExit(
        f"XRF/cube count mismatch: {len(source_rows)} XRF rows vs {len(files)} cubes"
    )

expected_ids = {os.path.splitext(os.path.basename(path))[0] for path in files}
actual_ids = [row["Name"] for row in source_rows]
if len(set(actual_ids)) != len(actual_ids):
    raise SystemExit("XRF sample identifiers are duplicated")
if set(actual_ids) != expected_ids:
    raise SystemExit("XRF sample identifiers do not match the HSI cube identifiers")

xrf_output = os.path.join(out, "xrf_elements.csv")
with open(xrf_output, "w", newline="", encoding="utf-8") as stream:
    writer = csv.writer(stream)
    writer.writerow(("Name", *kept_elements))
    for row in source_rows:
        values = {
            name: float(row[name])
            for name in (*kept_elements, "O", "C", "Missing")
        }
        if any(not math.isfinite(value) for value in values.values()):
            raise SystemExit(f"Invalid XRF value in {row['Name']}")
        if values["Missing"] < -1e-12 or any(values[name] < 0 for name in (*kept_elements, "O", "C")):
            raise SystemExit(f"Negative XRF value in {row['Name']}")
        values["Missing"] = max(0.0, values["Missing"])
        original_element_total = sum(values[name] for name in kept_elements) + values["O"] + values["C"]
        retained_total = sum(values[name] for name in kept_elements)
        if retained_total <= 0:
            raise SystemExit(f"No retained elemental mass in {row['Name']}")
        if not math.isclose(original_element_total + values["Missing"], 1.0, abs_tol=1e-9):
            raise SystemExit(f"XRF row does not close to 1.0: {row['Name']}")
        scale = original_element_total / retained_total
        transformed = [values[name] * scale for name in kept_elements]
        if not math.isclose(sum(transformed), original_element_total, abs_tol=1e-12):
            raise SystemExit(f"XRF renormalisation failed for {row['Name']}")
        writer.writerow((row["Name"], *transformed))

print(f"Built XRF table: {len(source_rows)} rows x {len(kept_elements)} elements")

part = 1
accumulated = 0
archive = None

def open_archive(number):
    path = os.path.join(out, f"hsi_cubes_part{number:02d}.zip")
    print(f"Opening {os.path.basename(path)}")
    return zipfile.ZipFile(
        path,
        mode="w",
        compression=zipfile.ZIP_DEFLATED,
        compresslevel=1,
        allowZip64=True,
    )

archive = open_archive(part)
for path in files:
    size = os.path.getsize(path)
    if accumulated and accumulated + size > limit:
        archive.close()
        part += 1
        accumulated = 0
        archive = open_archive(part)
    archive.write(path, arcname=os.path.basename(path))
    accumulated += size
archive.close()

assets = sorted(
    path for path in glob.glob(os.path.join(out, "*"))
    if os.path.basename(path) not in {"SHA256SUMS", "asset_manifest.csv"}
)

rows = []
for path in assets:
    digest = hashlib.sha256()
    with open(path, "rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    rows.append((os.path.basename(path), os.path.getsize(path), digest.hexdigest()))

with open(os.path.join(out, "SHA256SUMS"), "w", encoding="utf-8") as stream:
    for name, _, digest in rows:
        stream.write(f"{digest}  {name}\n")

with open(os.path.join(out, "asset_manifest.csv"), "w", newline="", encoding="utf-8") as stream:
    writer = csv.writer(stream)
    writer.writerow(("filename", "size_bytes", "sha256"))
    writer.writerows(rows)

print(f"Built {len(files)} cubes across {part} ZIP archive(s).")
for name, size, _ in rows:
    print(f"{name}: {size / (1024 ** 2):.1f} MiB")
PY
