# Release checklist

## Before creating the repository

- [x] Written authorisation to redistribute the dataset was obtained.
- [x] CC BY 4.0 was approved for the data release.
- [ ] Add and validate `metadata/wavelengths.csv` with exactly 273 rows.
- [ ] Validate the released XRF table has 1,132 unique sample identifiers and
      the expected 51 elemental columns.
- [ ] Confirm the required project, funder, sample-provider and institutional
      acknowledgements, then add them to `README.md`.
- [ ] Confirm the dataset creator order in `CITATION.cff`.
- [ ] Add author ORCID identifiers to `CITATION.cff`, if available.

## Build and verify the data assets

```bash
chmod +x build_release_assets.sh
./build_release_assets.sh /absolute/path/to/linear_unmixing
```

- [ ] Confirm that every ZIP file in `release_assets/` is below 2 GiB.
- [ ] Verify `SHA256SUMS` locally.
- [ ] Extract the archives into a clean folder.
- [ ] Load several cubes, including the first and last samples.
- [ ] Confirm all 1,132 cube IDs match `index.csv` and `xrf_elements.csv`.
- [ ] Confirm each cube has 273 bands and `float32` dtype.
- [ ] Confirm background pixels are `NaN` and valid spectra contain finite
      reflectance values.

## Publish on GitHub

- [ ] Create a public repository named `minerals-in-the-wild`.
- [ ] Upload the lightweight repository files, but not `release_assets/`.
- [ ] Replace any remaining placeholders and inspect the rendered README.
- [ ] Commit and push the repository.
- [ ] Draft release `v1.0.0`.
- [ ] Upload every file from `release_assets/` to the draft release.
- [ ] Publish the release only after all assets and checksums are present.

## Archive and DOI

- [ ] Connect the GitHub repository to Zenodo.
- [ ] Create the archived dataset release and obtain its DOI.
- [ ] Add the DOI to `CITATION.cff` and the README.
- [ ] Add the final paper citation and DOI when available.
