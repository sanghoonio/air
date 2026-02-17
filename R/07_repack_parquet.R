# 07_repack_parquet.R — Repack grid-history.parquet for smaller file size
#
# Lossless optimizations:
#   1. Drop us_aqi_* sub-index columns (unused by frontend)
#   2. Round AQ daily averages to 1 decimal
#   3. Round wind_speed to 2 decimals
#   4. Downcast lat/lon/wind_direction to integer
#   5. Write with zstd compression level 9
#
# Usage: Rscript R/07_repack_parquet.R

source(here::here("R", "00_config.R"))
library(arrow)

path <- PATH_GRID_HISTORY
size_before <- file.size(path)
cli_alert_info("Reading {path} ({round(size_before / 1e6, 1)} MB)")

df <- read_parquet(path)
cli_alert_info("Rows: {nrow(df)}, Cols: {ncol(df)}")

# 1. Drop unused sub-index columns
drop_cols <- grep("^us_aqi_", names(df), value = TRUE)
cli_alert_info("Dropping {length(drop_cols)} columns: {paste(drop_cols, collapse = ', ')}")
df <- df[, setdiff(names(df), drop_cols)]

# 2. Round AQ values to 1 decimal
aq_cols <- c("us_aqi", "european_aqi", "pm2_5", "pm10", "dust",
             "aerosol_optical_depth", "carbon_monoxide",
             "nitrogen_dioxide", "sulphur_dioxide", "ozone")
for (col in aq_cols) {
  if (col %in% names(df)) df[[col]] <- round(df[[col]], 1)
}

# 3. Round wind_speed to 2 decimals
df$wind_speed <- round(df$wind_speed, 2)

# 4. Downcast lat/lon/wind_direction to integer
df$lat <- as.integer(df$lat)
df$lon <- as.integer(df$lon)
df$wind_direction <- as.integer(df$wind_direction)

# 5. Write with zstd compression
write_parquet(df, path, compression = "snappy")

size_after <- file.size(path)
pct <- round((1 - size_after / size_before) * 100)
cli_alert_success(
  "Repacked: {round(size_before / 1e6, 1)} MB \u2192 {round(size_after / 1e6, 1)} MB ({pct}% smaller)"
)
