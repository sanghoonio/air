# 01_fetch_weather.R — Fetch historical daily weather from Open-Meteo for all cities
#
# Usage: Rscript R/01_fetch_weather.R
#
# No API key required. 12 API calls total.
# Output: data/processed/weather.parquet

source(here::here("R", "00_config.R"))
library(purrr)
library(arrow)

# ── Fetch weather for one city ────────────────────────────────────────────────

fetch_weather_city <- function(city_row) {
  cli_alert_info("Fetching weather for {city_row$city}...")

  resp <- openmeteo_weather_req(
    lat        = city_row$lat,
    lon        = city_row$lon,
    start      = DATE_START,
    end        = DATE_END,
    daily_vars = WEATHER_DAILY_VARS,
    tz         = city_row$tz
  ) |>
    req_perform() |>
    resp_body_json()

  daily <- resp$daily

  # Each element is a parallel array; bind into a data frame
  df <- tibble(date = as.Date(unlist(daily$time)))

  for (var in WEATHER_DAILY_VARS) {
    vals <- daily[[var]]
    # Replace NULL entries with NA
    df[[var]] <- map_dbl(vals, ~ if (is.null(.x)) NA_real_ else as.numeric(.x))
  }

  # Add city metadata
  df <- df |>
    mutate(
      city    = city_row$city,
      country = city_row$country,
      lat     = city_row$lat,
      lon     = city_row$lon,
      .before = date
    )

  cli_alert_success("{city_row$city}: {nrow(df)} days")
  df
}

# ── Main ──────────────────────────────────────────────────────────────────────

main <- function() {
  cli_h1("Open-Meteo Historical Weather")

  all_weather <- map(seq_len(nrow(CITIES)), function(i) {
    fetch_weather_city(CITIES[i, ])
  }) |> list_rbind()

  ensure_dir(PATH_WEATHER_OUT)
  write_parquet(all_weather, PATH_WEATHER_OUT)
  cli_alert_success("Wrote {nrow(all_weather)} rows to {PATH_WEATHER_OUT}")

  # Summary
  cli_h2("Summary")
  all_weather |>
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
