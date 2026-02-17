# 05_fetch_grid_history.R — Batch-fetch grid history → parquet
#
# Builds a 2° grid (lon 88–162, lat 18–58 = 798 points),
# fetches daily wind + hourly AQ in batches of 50 points,
# aggregates AQ hourly → daily, and writes grid-history.parquet
# to ui/public/ for the browser historical mode.
#
# Usage: Rscript R/05_fetch_grid_history.R
#
# ~32 API calls with manual retry + cooldown ≈ 20 min runtime

source(here::here("R", "00_config.R"))
library(purrr)
library(arrow)

BATCH_SIZE <- 50
GRID_WEATHER_VARS <- c("wind_speed_10m_mean", "wind_direction_10m_dominant")
GRID_AQ_VARS <- c(
  "us_aqi", "european_aqi",
  "pm2_5", "pm10",
  "dust", "aerosol_optical_depth",
  "carbon_monoxide", "nitrogen_dioxide", "sulphur_dioxide", "ozone",
  "us_aqi_pm2_5", "us_aqi_pm10",
  "us_aqi_ozone", "us_aqi_nitrogen_dioxide",
  "us_aqi_sulphur_dioxide", "us_aqi_carbon_monoxide"
)

# ── Helpers ─────────────────────────────────────────────────────────────────

safe_dbl <- function(x) {
  vapply(
    x,
    function(v) if (is.null(v)) NA_real_ else as.numeric(v),
    double(1)
  )
}

#' Perform an httr2 request with manual retry and backoff
perform_with_retry <- function(req, label = "request",
                               max_retries = 6,
                               wait_secs = 60) {
  for (attempt in seq_len(max_retries + 1)) {
    result <- tryCatch(
      req |> req_perform() |> resp_body_json(),
      error = function(e) e
    )
    if (!inherits(result, "error")) return(result)
    if (attempt > max_retries) stop(result)
    cli_alert_warning(
      paste0(
        "{label} failed (attempt {attempt}/",
        "{max_retries + 1}): ",
        "{conditionMessage(result)}"
      )
    )
    cli_alert_info("Waiting {wait_secs}s before retry...")
    Sys.sleep(wait_secs)
  }
}

# ── Build grid ──────────────────────────────────────────────────────────────

build_grid <- function() {
  expand.grid(
    lon = seq(GRID_LON_MIN, GRID_LON_MAX, by = GRID_STEP),
    lat = seq(GRID_LAT_MIN, GRID_LAT_MAX, by = GRID_STEP)
  ) |> as_tibble()
}

# ── Parse multi-location weather response ───────────────────────────────────

parse_weather_batch <- function(resp_json, batch_grid) {
  # Multi-location response is an array; single location is an object
  locations <- if (is.null(names(resp_json))) resp_json else list(resp_json)

  map2(locations, seq_along(locations), function(loc, i) {
    daily <- loc$daily
    dates <- unlist(daily$time)

    tibble(
      date           = dates,
      lat            = round(batch_grid$lat[i], 1),
      lon            = round(batch_grid$lon[i], 1),
      wind_speed     = safe_dbl(daily$wind_speed_10m_mean),
      wind_direction = safe_dbl(daily$wind_direction_10m_dominant)
    )
  }) |> list_rbind()
}

# ── Parse multi-location AQ response (hourly → daily) ──────────────────────

parse_aq_batch <- function(resp_json, batch_grid, aq_vars) {
  locations <- if (is.null(names(resp_json))) resp_json else list(resp_json)

  map2(locations, seq_along(locations), function(loc, i) {
    hourly <- loc$hourly
    times <- unlist(hourly$time)

    # Build tibble with all requested AQ variables
    cols <- list(
      datetime = times,
      lat      = round(batch_grid$lat[i], 1),
      lon      = round(batch_grid$lon[i], 1)
    )
    for (v in aq_vars) {
      cols[[v]] <- if (!is.null(hourly[[v]])) safe_dbl(hourly[[v]]) else rep(NA_real_, length(times))
    }

    as_tibble(cols) |>
      mutate(date = substr(datetime, 1, 10)) |>
      group_by(date, lat, lon) |>
      summarise(
        across(all_of(aq_vars), ~ mean(.x, na.rm = TRUE)),
        .groups = "drop"
      ) |>
      mutate(
        across(all_of(aq_vars), ~ ifelse(is.finite(.x), .x, NA_real_))
      )
  }) |> list_rbind()
}

# ── Main ────────────────────────────────────────────────────────────────────

main <- function() {
  cli_h1("Grid History: 2025 daily wind + AQ")

  grid <- build_grid()
  cli_alert_info(
    paste0(
      "Grid: {nrow(grid)} points ",
      "({GRID_LON_MIN}\u2013{GRID_LON_MAX}\u00b0E ",
      "\u00d7 {GRID_LAT_MIN}\u2013{GRID_LAT_MAX}\u00b0N, ",
      "step {GRID_STEP}\u00b0)"
    )
  )
  cli_alert_info("Date range: {GRID_DATE_START} to {GRID_DATE_END}")

  # Split into batches
  batch_ids <- ceiling(seq_len(nrow(grid)) / BATCH_SIZE)
  batches <- split(grid, batch_ids)
  cli_alert_info(
    "Batches: {length(batches)} \u00d7 {BATCH_SIZE} points"
  )

  all_data <- map(seq_along(batches), function(b) {
    batch <- batches[[b]]
    cli_h2("Batch {b}/{length(batches)} ({nrow(batch)} points)")

    # ── Weather (daily) ──
    cli_alert_info("Fetching weather...")
    w_resp <- perform_with_retry(
      openmeteo_weather_grid_req(
        lats       = batch$lat,
        lons       = batch$lon,
        start      = GRID_DATE_START,
        end        = GRID_DATE_END,
        daily_vars = GRID_WEATHER_VARS
      ),
      label = paste0("Weather batch ", b)
    )

    weather <- parse_weather_batch(w_resp, batch)
    cli_alert_success("Weather: {nrow(weather)} rows")

    # Cool down before AQ call
    cli_alert_info("Waiting 60s for rate limit cooldown...")
    Sys.sleep(60)

    # ── AQ (hourly → daily) ──
    cli_alert_info("Fetching air quality...")
    aq_resp <- perform_with_retry(
      openmeteo_aq_grid_req(
        lats        = batch$lat,
        lons        = batch$lon,
        start       = GRID_DATE_START,
        end         = GRID_DATE_END,
        hourly_vars = GRID_AQ_VARS
      ),
      label = paste0("AQ batch ", b)
    )

    aq <- parse_aq_batch(aq_resp, batch, GRID_AQ_VARS)
    cli_alert_success("AQ: {nrow(aq)} rows")

    # Cool down between batches
    if (b < length(batches)) {
      cli_alert_info("Waiting 60s before next batch...")
      Sys.sleep(60)
    }

    # ── Join ──
    left_join(weather, aq, by = c("date", "lat", "lon"))
  }) |> list_rbind()

  cli_h1("Writing output")
  cli_alert_info("Total rows: {nrow(all_data)}")

  ensure_dir(PATH_GRID_HISTORY)
  write_parquet(all_data, PATH_GRID_HISTORY)
  cli_alert_success(
    "Wrote {PATH_GRID_HISTORY} ({round(file.size(PATH_GRID_HISTORY) / 1e6, 1)} MB)"
  )

  # Summary
  cli_h2("Summary")
  all_data |>
    summarise(
      n_rows   = n(),
      n_dates  = n_distinct(date),
      n_points = n_distinct(paste(lat, lon)),
      date_min = min(date),
      date_max = max(date)
    ) |>
    print()
}

main()
