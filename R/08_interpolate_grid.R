# 08_interpolate_grid.R — Bicubic (Catmull-Rom) interpolation of grid parquet
#
# Reads grid-history.parquet, averages all days into a single annual mean
# on the coarse 2° grid, then interpolates once to 5× density using the
# same Catmull-Rom spline as the frontend. Outputs CSV to data/.
#
# Usage: Rscript R/08_interpolate_grid.R
#
# Output: data/grid-interpolated.csv (~20K rows, ~2 MB)

source(here::here("R", "00_config.R"))
library(arrow)

INTERP <- 5
STEP   <- GRID_STEP
FINE   <- STEP / INTERP

AQ_VARS <- c(
  "us_aqi", "european_aqi",
  "pm2_5", "pm10",
  "dust", "aerosol_optical_depth",
  "carbon_monoxide", "nitrogen_dioxide", "sulphur_dioxide", "ozone"
)

# ── Catmull-Rom cubic (matches frontend) ────────────────────────────────────

cubic <- function(p0, p1, p2, p3, t) {
  0.5 * (
    2 * p1 +
    (-p0 + p2) * t +
    (2 * p0 - 5 * p1 + 4 * p2 - p3) * t^2 +
    (-p0 + 3 * p1 - 3 * p2 + p3) * t^3
  )
}

snap_down <- function(v) floor(v / STEP) * STEP

r1 <- function(v) round(v * 10) / 10

# ── Lookup helper: returns value or 0 if missing ───────────────────────────

grid_val <- function(lookup, lat, lon, field) {
  key <- paste0(r1(lat), ",", r1(lon))
  row <- lookup[[key]]
  if (is.null(row)) return(0)
  v <- row[[field]]
  if (is.na(v)) return(0)
  v
}

# ── Interpolate a single averaged grid ─────────────────────────────────────

interpolate_grid <- function(avg_df, lat_min, lat_max, lon_min, lon_max) {
  # Decompose wind to u,v for averaging/interpolation
  avg_df$u <- -avg_df$wind_speed * sin(avg_df$wind_direction * pi / 180)
  avg_df$v <- -avg_df$wind_speed * cos(avg_df$wind_direction * pi / 180)

  # Build lookup: "lat,lon" -> named list
  lookup <- new.env(hash = TRUE, parent = emptyenv())
  for (i in seq_len(nrow(avg_df))) {
    key <- paste0(avg_df$lat[i], ",", avg_df$lon[i])
    assign(key, as.list(avg_df[i, ]), envir = lookup)
  }
  lookup <- as.list(lookup)

  fine_lats <- seq(lat_min, lat_max, by = FINE)
  fine_lons <- seq(lon_min, lon_max, by = FINE)

  n <- length(fine_lats) * length(fine_lons)
  out_lat <- numeric(n)
  out_lon <- numeric(n)
  out_ws  <- numeric(n)
  out_wd  <- numeric(n)
  out_aq  <- matrix(NA_real_, nrow = n, ncol = length(AQ_VARS))

  idx <- 0
  for (lat in fine_lats) {
    for (lon in fine_lons) {
      idx <- idx + 1
      lat_base <- snap_down(lat)
      lon_base <- snap_down(lon)
      fy <- (lat - lat_base) / STEP
      fx <- (lon - lon_base) / STEP

      lat_rows <- lat_base + c(-1, 0, 1, 2) * STEP
      lon_cols <- lon_base + c(-1, 0, 1, 2) * STEP

      row_u <- numeric(4)
      row_v <- numeric(4)
      row_m <- matrix(0, nrow = 4, ncol = length(AQ_VARS))

      for (ri in 1:4) {
        rl <- lat_rows[ri]
        row_u[ri] <- cubic(
          grid_val(lookup, rl, lon_cols[1], "u"),
          grid_val(lookup, rl, lon_cols[2], "u"),
          grid_val(lookup, rl, lon_cols[3], "u"),
          grid_val(lookup, rl, lon_cols[4], "u"), fx
        )
        row_v[ri] <- cubic(
          grid_val(lookup, rl, lon_cols[1], "v"),
          grid_val(lookup, rl, lon_cols[2], "v"),
          grid_val(lookup, rl, lon_cols[3], "v"),
          grid_val(lookup, rl, lon_cols[4], "v"), fx
        )
        for (mi in seq_along(AQ_VARS)) {
          row_m[ri, mi] <- cubic(
            grid_val(lookup, rl, lon_cols[1], AQ_VARS[mi]),
            grid_val(lookup, rl, lon_cols[2], AQ_VARS[mi]),
            grid_val(lookup, rl, lon_cols[3], AQ_VARS[mi]),
            grid_val(lookup, rl, lon_cols[4], AQ_VARS[mi]), fx
          )
        }
      }

      u <- cubic(row_u[1], row_u[2], row_u[3], row_u[4], fy)
      v <- cubic(row_v[1], row_v[2], row_v[3], row_v[4], fy)

      out_lat[idx] <- r1(lat)
      out_lon[idx] <- r1(lon)
      out_ws[idx]  <- sqrt(u^2 + v^2)
      out_wd[idx]  <- (atan2(-u, -v) * 180 / pi + 360) %% 360

      for (mi in seq_along(AQ_VARS)) {
        out_aq[idx, mi] <- max(0, cubic(row_m[1, mi], row_m[2, mi], row_m[3, mi], row_m[4, mi], fy))
      }
    }
  }

  result <- tibble(
    lat            = out_lat[1:idx],
    lon            = out_lon[1:idx],
    wind_speed     = round(out_ws[1:idx], 2),
    wind_direction = round(out_wd[1:idx])
  )
  for (mi in seq_along(AQ_VARS)) {
    result[[AQ_VARS[mi]]] <- round(out_aq[1:idx, mi], 1)
  }
  result
}

# ── Main ────────────────────────────────────────────────────────────────────

main <- function() {
  cli_h1("Bicubic grid interpolation ({INTERP}×, annual mean)")

  df <- read_parquet(PATH_GRID_HISTORY)
  df$lat <- as.numeric(df$lat)
  df$lon <- as.numeric(df$lon)
  cli_alert_info("Loaded {nrow(df)} rows, {n_distinct(df$date)} days")

  # Average across all days per grid point
  cli_alert_info("Computing annual mean per grid point...")
  avg <- df |>
    group_by(lat, lon) |>
    summarise(
      wind_speed     = mean(wind_speed, na.rm = TRUE),
      wind_direction = mean(wind_direction, na.rm = TRUE),
      across(all_of(AQ_VARS), ~ mean(.x, na.rm = TRUE)),
      .groups = "drop"
    ) |>
    mutate(across(where(is.numeric), ~ ifelse(is.finite(.x), .x, NA_real_)))

  cli_alert_success("Averaged to {nrow(avg)} grid points")

  # Interpolate once
  cli_alert_info("Interpolating at {INTERP}× ({FINE}° step)...")
  result <- interpolate_grid(
    avg,
    lat_min = GRID_LAT_MIN,
    lat_max = GRID_LAT_MAX,
    lon_min = GRID_LON_MIN,
    lon_max = GRID_LON_MAX
  )
  cli_alert_success("Interpolated: {nrow(result)} rows")

  out_path <- here("data", "grid-interpolated.csv")
  ensure_dir(out_path)
  readr::write_csv(result, out_path)
  cli_alert_success("Wrote {.path {out_path}} ({round(file.size(out_path) / 1e6, 1)} MB)")
}

main()
