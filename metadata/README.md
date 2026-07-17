# Required wavelength metadata

Add `wavelengths.csv` to this directory before publication. It must contain
exactly 273 data rows and the following columns:

```text
band_index,wavelength_nm,fwhm_nm
```

Use the values exported from the actual Specim acquisition metadata. Do not
interpolate or reconstruct them from the approximate 1000-2500 nm range.
