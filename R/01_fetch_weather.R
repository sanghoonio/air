# 01_fetch_weather.R — Fetch historical daily weather for all cities
#
# Multi-location request for 12 cities (single batch),
# with manual retry + backoff. Outputs CSV to data/.
#
# Usage: Rscript R/01_fetch_weather.R

source(here::here("R", "00_config.R"))
library(purrr)

# ── Helpers ─────────────────────────────────────────────────────────────────

safe_dbl <- function(x) {
  vapply(
    x,
    function(v) if (is.null(v)) NA_real_ else as.numeric(v),
    double(1)
  )
}

perform_with_retry <- function(req, label = "request",
                               max_retries = 6, wait_secs = 60) {
  for (attempt in seq_len(max_retries + 1)) {
    result <- tryCatch(
      req |> req_perform() |> resp_body_json(),
      error = function(e) e
    )
    if (!inherits(result, "error")) return(result)
    if (attempt > max_retries) stop(result)
    cli_alert_warning(
      paste0(
        "{label} failed (attempt {attempt}/{max_retries + 1}): ",
        "{conditionMessage(result)}"
      )
    )
    cli_alert_info("Waiting {wait_secs}s before retry...")
    Sys.sleep(wait_secs)
  }
}

# ── Parse multi-location weather response ───────────────────────────────────

parse_weather_response <- function(resp_json, cities) {
  locations <- if (is.null(names(resp_json))) resp_json else list(resp_json)

  map2(locations, seq_along(locations), function(loc, i) {
    daily <- loc$daily
    dates <- unlist(daily$time)

    df <- tibble(
      city    = cities$city[i],
      country = cities$country[i],
      lat     = cities$lat[i],
      lon     = cities$lon[i],
      date    = dates
    )

    for (var in WEATHER_DAILY_VARS) {
      df[[var]] <- safe_dbl(daily[[var]])
    }

    df
  }) |> list_rbind()
}

# ── Main ────────────────────────────────────────────────────────────────────

main <- function() {
  cli_h1("City Weather: {DATE_START} to {DATE_END}")
  cli_alert_info("{nrow(CITIES)} cities, {length(WEATHER_DAILY_VARS)} daily vars")

  resp <- perform_with_retry(
    openmeteo_weather_grid_req(
      lats       = CITIES$lat,
      lons       = CITIES$lon,
      start      = DATE_START,
      end        = DATE_END,
      daily_vars = WEATHER_DAILY_VARS
    ),
    label = "Weather (all cities)"
  )

  all_weather <- parse_weather_response(resp, CITIES)
  cli_alert_success("Parsed {nrow(all_weather)} rows")

  # ── Write CSV ──
  out_path <- here("data", "city-weather.csv")
  ensure_dir(out_path)
  readr::write_csv(all_weather, out_path)
  cli_alert_success("Wrote {.path {out_path}} ({round(file.size(out_path) / 1e6, 1)} MB)")

  # ── Summary ──
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
