# R data pipeline

Scripts are numbered in execution order. All source `00_config.R` for shared constants.

| Script | Purpose |
|--------|---------|
| `00_config.R` | Shared config: grid bounds, API builders, output paths |
| `01_fetch_weather.R` | Fetch per-city historical weather |
| `02_fetch_dust.R` | Fetch per-city historical dust/AQ |
| `03_check_data.R` | Data quality checks |
| `04_plots.R` | Exploratory plots |
| `05_fetch_grid_history.R` | Batch-fetch 2° grid wind + AQ → `ui/public/grid-history.parquet` |
| `06_inspect_grid.R` | Inspect/validate the grid parquet |
| `07_repack_parquet.R` | Repack existing parquet with compression optimizations |

## Parquet compression

`grid-history.parquet` is served to the browser and parsed client-side by [hyparquet](https://github.com/hyparam/hyparquet), so file size directly affects load time.

### Optimizations applied (07_repack_parquet.R)

1. **Drop unused columns** — 6 `us_aqi_*` sub-index columns (pm2.5, pm10, ozone, no2, so2, co breakdowns) are not used by the frontend. Removes ~29% of columns.
2. **Round floats** — AQ values are daily averages of hourly data, so 4+ decimal places add no information. Rounded to 1 decimal. Wind speed rounded to 2 decimals.
3. **Downcast integers** — `lat`, `lon`, and `wind_direction` are whole numbers stored as float64. Cast to int32 (halves their storage).
4. **Snappy compression** — hyparquet supports snappy natively (zstd requires an additional plugin). Snappy is the default parquet codec and provides good compression with fast decompression.

These are applied both in `07_repack_parquet.R` (for repacking an existing file) and in `05_fetch_grid_history.R` (so fresh fetches produce the optimized format directly).

### Result

8.7 MB → 4.6 MB (47% smaller), fully lossless for the frontend's purposes.

### Backup

`ui/public/grid-history-full.parquet` is a copy of the original uncompressed file with all 21 columns and full float64 precision, kept in case the sub-index columns are needed later.
