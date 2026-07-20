# Minerals in the Wild

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.21414930.svg)](https://doi.org/10.5281/zenodo.21414930)

**A paired hyperspectral-XRF dataset for elemental composition estimation**

Minerals in the Wild contains calibrated short-wave infrared (SWIR)
hyperspectral image cubes and matched X-ray fluorescence (XRF) elemental
compositions for **1,132 natural rock specimens collected across Europe**.
Each `sample_N.npy` cube corresponds one-to-one with the `sample_N` row in the
XRF table.

## Dataset overview

| Property | Value |
|---|---|
| Specimens | 1,132 |
| HSI sensor | Specim SWIR push-broom camera |
| Spectral bands | 273 |
| Spectral range | 996.34-2504.28 nm |
| Cube format | NumPy `.npy`, `float32`, shape `(height, width, 273)` |
| Released spatial dimensions | Heights 6-100 pixels; widths 9-347 pixels |
| XRF instrument | Bruker S1 TITAN handheld XRF analyser |
| XRF protocol | Five measurements per specimen; 8 mm analysis spot |
| XRF target | 51 harmonised elemental mass fractions |
| Pairing | One HSI cube and one XRF row per specimen |
| Approximate HSI volume | 4.1 GB before release packaging |

## Repository and release contents

The Git repository contains documentation and lightweight metadata. The HSI
cubes and XRF table are distributed as assets attached to the latest GitHub
Release.

```text
.
|-- README.md
|-- LICENSE
|-- CITATION.cff
|-- index.csv
|-- metadata/
|   `-- wavelengths.csv
|-- build_release_assets.sh
`-- RELEASE_CHECKLIST.md
```

Release assets:

```text
hsi_cubes_part01.zip
hsi_cubes_part02.zip
...
xrf_elements.csv
SHA256SUMS
asset_manifest.csv
```

## Data acquisition and processing

### Hyperspectral imaging

Specimens were scanned on a conveyor belt using a Specim SWIR push-broom
camera positioned approximately 30 cm above the belt. The sensor recorded 273
bands in the approximately 1000-2500 nm range.

Raw digital numbers were converted to reflectance using detector-position- and
wavelength-dependent dark and white references:

```text
reflectance = (raw - dark) / (white - dark)
```

A manual binary spatial mask was created for each specimen. Background pixels
inside each released rectangular crop are represented by `NaN` across all
bands; they must be excluded from spectral statistics.

### XRF measurements

Each specimen was measured at five visually different surface locations using
an 8 mm XRF analysis spot. The five measurements were averaged to obtain one
specimen-level composition.

The original XRF output contained a mixture of elemental and compound labels.
Compound values were decomposed into elemental contributions using
stoichiometric mass fractions. This decomposition produces oxygen and carbon
as arithmetic byproducts; they are not direct XRF measurements. The internal
conversion also includes a `Missing` closure residual.

For the public release, `O`, `C`, and `Missing` are removed. The remaining 51
calibrated elements are rescaled proportionally so that each row sums to the
original retained fraction (`1 - Missing`), matching the evaluation pipeline.
Consequently, released row sums range from approximately **0.1707 to 1.0000**
and should not be assumed to equal 1.

## Index

`index.csv` contains one row per specimen:

| Column | Meaning |
|---|---|
| `sample_id` | Stable identifier, from `sample_0` to `sample_1131` |
| `hsi_file` | Cube path after extraction |
| `height`, `width`, `n_bands` | Cube dimensions |
| `dtype` | NumPy data type (`float32`) |
| `n_pixels` | Rectangular crop size (`height * width`), including masked locations |
| `has_xrf` | Whether a paired XRF row exists |
| `xrf_row` | Matching identifier in `xrf_elements.csv` |

## Download

Download all assets from the [latest release](../../releases/latest). With the
GitHub CLI:

```bash
gh release download --pattern '*'
```

Verify the downloads before extracting:

```bash
shasum -a 256 -c SHA256SUMS   # macOS
# or: sha256sum -c SHA256SUMS # Linux
```

Extract every archive into the same directory:

```bash
mkdir -p hsi_cubes
for archive in hsi_cubes_part*.zip; do
  unzip -o "$archive" -d hsi_cubes
done
```

## Python example

```python
import numpy as np
import pandas as pd

sample_id = "sample_0"

cube = np.load(f"hsi_cubes/{sample_id}.npy")
xrf = pd.read_csv("xrf_elements.csv", index_col="Name")
wavelengths = pd.read_csv("metadata/wavelengths.csv")

# Exclude background NaNs when producing the specimen mean spectrum.
mean_spectrum = np.nanmean(cube, axis=(0, 1))
elemental_composition = xrf.loc[sample_id]

print(cube.shape)
print(mean_spectrum.shape)
print(elemental_composition)
```

## Intended uses

- Specimen-level elemental composition estimation from HSI
- Spectral unmixing and library matching
- Cross-modal HSI-XRF representation learning
- Benchmarking mineral-analysis methods

## Limitations

- XRF measurements represent five selected surface locations, whereas HSI
  covers the visible specimen surface.
- XRF provides elemental composition, not direct mineralogical labels.
- SWIR spectra do not uniquely identify every element or mineral phase.
- Natural specimens can be spatially heterogeneous.
- The specimens were collected across multiple sites, so acquisition context
  and class balance should not be assumed to be uniform.
- Background locations are encoded as `NaN` and require NaN-aware processing.

## Citation

Please cite version 1.0.0 of the dataset using the DOI:
[10.5281/zenodo.21414930](https://doi.org/10.5281/zenodo.21414930).
Citation metadata is also available in [`CITATION.cff`](./CITATION.cff).

Associated manuscript:

> E. Tetoula-Tsonga, G. Arvanitakis, and T. Giannakas, "Minerals in the
> Wild: A Paired Hyperspectral-XRF Dataset for Elemental Composition
> Estimation," manuscript, 2026.

## Licence

The dataset, metadata and documentation are licensed under the
[Creative Commons Attribution 4.0 International licence](./LICENSE). Reuse,
adaptation and commercial use are permitted provided appropriate attribution
is given, the licence is linked, and changes are indicated.

## Contact

For questions or corrections, open an issue in this repository or contact
[Eleftheria Tetoula-Tsonga](mailto:tetoula.tsonga@hotmail.com).
