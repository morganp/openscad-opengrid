# Changelog

All notable changes to this project are documented here. This project uses
[Semantic Versioning 2.0.0](https://semver.org).

## 1.1.0 - 2026-09-26

### Added

- `opengrid_bin()`: open top bin with snaps on its back wall, sized in grid
  columns, with optional dividers in both directions.
- Snap centres land on board cells for odd and even column counts alike, so bins
  of mixed widths pack flush along a row.
- Sizing helpers: `og_bin_width()`, `og_cols_for()`, `og_cols_for_inner()`,
  `og_bin_rows()`, `og_bin_snap_cols()`, `og_bin_snap_positions()`.
- `examples/opengrid_bin_example.scad` and `images/opengrid_bin.png`.
- Print orientation guidance for bins: front face down, snaps up.

## 1.0.0 - 2026-08-28

### Added

- `opengrid_snap()`, `opengrid_snaps()`, `opengrid_snap_grid()`,
  `opengrid_tile()` and `opengrid_cell_void()`, full and lite variants.
