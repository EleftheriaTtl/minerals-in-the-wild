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
import os
import shutil
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

shutil.copyfile(xrf_source, os.path.join(out, "xrf_elements.csv"))

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
