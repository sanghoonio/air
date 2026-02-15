# 02_fetch_dust.R — Fetch CAMS dust/AQ data from Open-Meteo, aggregate hourly → daily
#
# Usage: Rscript R/02_fetch_dust.R
#
# No API key required. 12 API calls total.
# Date range: Aug 2022 → Dec 2025 (CAMS Global availability)
# Output: data/processed/dust.parquet

source(here::here("R", "00_config.R"))
library(purrr)
library(lubridate)
library(arrow)

# ── Fetch dust for one city ───────────────────────────────────────────────────

fetch_dust_city <- function(city_row) {
  cli_alert_info("Fetching dust data for {city_row$city}...")

  resp <- openmeteo_dust_req(
    lat         = city_row$lat,
    lon         = city_row$lon,
    start       = DATE_START,
    end         = DATE_END,
    hourly_vars = DUST_HOURLY_VARS,
    tz          = city_row$tz
  ) |>
    req_perform() |>
    resp_body_json()

  hourly <- resp$hourly

  # Parse the hourly arrays into a data frame
  df <- tibble(
    datetime = ymd_hm(unlist(hourly$time), quiet = TRUE)
  )

  for (var in DUST_HOURLY_VARS) {
    vals <- hourly[[var]]
    df[[var]] <- map_dbl(vals, ~ if (is.null(.x)) NA_real_ else as.numeric(.x))
  }

  # Add date column for daily aggregation
  df <- df |> mutate(date = as.Date(datetime))

  # Aggregate hourly → daily: mean, max, min per variable
  daily <- suppressWarnings(
    df |>
      group_by(date) |>
      summarise(
        dust_mean  = mean(dust, na.rm = TRUE),
        dust_max   = max(dust, na.rm = TRUE),
        dust_min   = min(dust, na.rm = TRUE),
        pm10_mean  = mean(pm10, na.rm = TRUE),
        pm10_max   = max(pm10, na.rm = TRUE),
        pm2_5_mean = mean(pm2_5, na.rm = TRUE),
        pm2_5_max  = max(pm2_5, na.rm = TRUE),
        aod_mean   = mean(aerosol_optical_depth, na.rm = TRUE),
        aod_max    = max(aerosol_optical_depth, na.rm = TRUE),
        .groups    = "drop"
      )
  )

  # Replace NaN/Inf from all-NA days
  daily <- daily |>
    mutate(across(where(is.numeric), ~ ifelse(is.finite(.x), .x, NA_real_)))

  # Add city metadata
  daily <- daily |>
    mutate(
      city    = city_row$city,
      country = city_row$country,
      lat     = city_row$lat,
      lon     = city_row$lon,
      .before = date
    )

  cli_alert_success("{city_row$city}: {nrow(daily)} days")
  daily
}

# ── Main ──────────────────────────────────────────────────────────────────────

main <- function() {
  cli_h1("Open-Meteo CAMS Dust Data")
  cli_alert_info("Date range: {DATE_START} to {DATE_END}")

  all_dust <- map(seq_len(nrow(CITIES)), function(i) {
    fetch_dust_city(CITIES[i, ])
  }) |> list_rbind()

  ensure_dir(PATH_DUST_OUT)
  write_parquet(all_dust, PATH_DUST_OUT)
  cli_alert_success("Wrote {nrow(all_dust)} rows to {PATH_DUST_OUT}")

  # Summary
  cli_h2("Summary")
  all_dust |>
    group_by(city) |>
    summarise(
      n_days   = n(),
      date_min = min(date),
      date_max = max(date),
      .groups  = "drop"
    ) |>
    print()
}

main()
