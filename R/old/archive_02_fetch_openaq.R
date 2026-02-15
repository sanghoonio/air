# 02_fetch_openaq.R — Download OpenAQ data from S3 archive + aggregate to daily parquet
#
# Usage: Rscript R/02_fetch_openaq.R
#
# Requires: data/stations.csv (from manual curation after running 01)
# Output:   data/raw/openaq/{location_id}/*.csv.gz  (raw hourly files)
#           data/processed/openaq.parquet             (daily aggregated)

source(here::here("R", "00_config.R"))
library(purrr)
library(readr)
library(lubridate)
library(tidyr)
library(arrow)

# ── Download phase ────────────────────────────────────────────────────────────

download_station <- function(location_id, date_range) {
  out_dir <- file.path(PATH_RAW_OPENAQ, location_id)
  ensure_dir(out_dir)

  n_downloaded <- 0L
  n_skipped    <- 0L
  n_missing    <- 0L
  n_errors     <- 0L

  cli_progress_bar(
    "Downloading station {location_id}",
    total = length(date_range)
  )

  for (d in date_range) {
    date <- as.Date(d, origin = "1970-01-01")
    ds   <- format(date, "%Y%m%d")
    dest <- file.path(out_dir, paste0("location-", location_id, "-", ds, ".csv.gz"))

    cli_progress_update()

    # Skip if already downloaded
    if (file.exists(dest)) {
      n_skipped <- n_skipped + 1L
      next
    }

    result <- tryCatch({
      resp <- openaq_s3_req(location_id, date) |>
        req_error(is_error = function(resp) FALSE) |>
        req_perform()

      status <- resp_status(resp)

      if (status == 404) {
        n_missing <- n_missing + 1L
        "missing"
      } else if (status >= 200 && status < 300) {
        writeBin(resp_body_raw(resp), dest)
        n_downloaded <- n_downloaded + 1L
        "ok"
      } else {
        n_errors <- n_errors + 1L
        "error"
      }
    }, error = function(e) {
      n_errors <<- n_errors + 1L
      "error"
    })
  }

  cli_progress_done()
  cli_alert_info(paste0(
    "Station {location_id}: {n_downloaded} downloaded, {n_skipped} skipped, ",
    "{n_missing} missing (404), {n_errors} errors"
  ))

  list(
    location_id  = location_id,
    downloaded   = n_downloaded,
    skipped      = n_skipped,
    missing      = n_missing,
    errors       = n_errors
  )
}

# ── Aggregation phase ─────────────────────────────────────────────────────────

aggregate_station <- function(location_id, city_row) {
  raw_dir <- file.path(PATH_RAW_OPENAQ, location_id)
  files   <- list.files(raw_dir, pattern = "\\.csv\\.gz$", full.names = TRUE)

  if (length(files) == 0) {
    cli_alert_warning("No raw files for station {location_id} ({city_row$city})")
    return(NULL)
  }

  cli_alert_info("Reading {length(files)} files for {city_row$city} (ID {location_id})...")

  raw <- map(files, function(f) {
    tryCatch(
      read_csv(f, col_types = cols(
        location_id = col_integer(),
        sensors_id  = col_integer(),
        location    = col_character(),
        datetime    = col_character(),
        lat         = col_double(),
        lon         = col_double(),
        parameter   = col_character(),
        units       = col_character(),
        value       = col_double()
      ), show_col_types = FALSE),
      error = function(e) NULL
    )
  }) |>
    compact() |>
    list_rbind()

  if (nrow(raw) == 0) return(NULL)

  # Assign local date using the city's timezone
  tz <- city_row$tz
  raw <- raw |>
    mutate(
      datetime_utc = ymd_hms(datetime, quiet = TRUE),
      datetime_local = with_tz(datetime_utc, tzone = tz),
      date = as.Date(datetime_local)
    )

  # Filter to target parameters
  raw <- raw |>
    filter(tolower(parameter) %in% OPENAQ_PARAMS) |>
    mutate(parameter = tolower(parameter))

  # Daily aggregation: mean, max, n_obs per parameter
  daily <- raw |>
    group_by(date, parameter, units) |>
    summarise(
      mean_val = mean(value, na.rm = TRUE),
      max_val  = max(value, na.rm = TRUE),
      n_obs    = n(),
      .groups  = "drop"
    )

  # Pivot wider
  daily_wide <- daily |>
    pivot_wider(
      id_cols     = date,
      names_from  = parameter,
      values_from = c(mean_val, max_val, n_obs),
      names_glue  = "{parameter}_{.value}"
    )

  # Rename columns: pm25_mean_val -> pm25_mean, etc.
  names(daily_wide) <- names(daily_wide) |>
    gsub("_mean_val$", "_mean", x = _) |>
    gsub("_max_val$", "_max", x = _) |>
    gsub("_n_obs$", "_n", x = _)

  # Add city metadata
  daily_wide <- daily_wide |>
    mutate(
      city         = city_row$city,
      country      = city_row$country,
      location_id  = as.integer(location_id),
      station_name = city_row$station_name,
      lat          = city_row$lat,
      lon          = city_row$lon,
      .before      = date
    )

  # Build units lookup (one row per parameter)
  units_lookup <- daily |>
    distinct(parameter, units) |>
    mutate(
      city        = city_row$city,
      location_id = as.integer(location_id)
    )

  list(data = daily_wide, units = units_lookup)
}

# ── Main ──────────────────────────────────────────────────────────────────────

main <- function() {
  # Read stations.csv
  if (!file.exists(PATH_STATIONS)) {
    cli_abort(paste0(
      "stations.csv not found at {PATH_STATIONS}.\n",
      "Run 01_discover_openaq.R first, then create stations.csv."
    ))
  }

  stations <- read_csv(PATH_STATIONS, col_types = cols(
    city         = col_character(),
    location_id  = col_integer(),
    station_name = col_character()
  ))

  # Drop cities with no station
  stations <- stations |> filter(!is.na(location_id))

  if (nrow(stations) == 0) {
    cli_abort("No stations with valid location_id in stations.csv.")
  }

  cli_h1("OpenAQ S3 Download")
  cli_alert_info("{nrow(stations)} station(s) to download")

  # Date range
  dates <- seq.Date(as.Date(DATE_START), as.Date(DATE_END), by = "day")

  # Download each station
  download_results <- map(seq_len(nrow(stations)), function(i) {
    download_station(stations$location_id[i], dates)
  })

  # Aggregation
  cli_h1("Aggregating to daily")

  # Join stations with CITIES to get tz, country, lat, lon
  stations_full <- stations |>
    left_join(CITIES |> select(city, country, lat, lon, tz), by = "city")

  agg_results <- map(seq_len(nrow(stations_full)), function(i) {
    row <- stations_full[i, ]
    aggregate_station(row$location_id, row)
  }) |> compact()

  if (length(agg_results) == 0) {
    cli_abort("No data aggregated. Check raw downloads.")
  }

  # Combine
  all_data  <- map(agg_results, "data") |> list_rbind()
  all_units <- map(agg_results, "units") |> list_rbind()

  # Write parquet
  ensure_dir(PATH_OPENAQ_OUT)
  write_parquet(all_data, PATH_OPENAQ_OUT)
  cli_alert_success("Wrote {nrow(all_data)} rows to {PATH_OPENAQ_OUT}")

  # Write units lookup
  units_path <- here("data", "processed", "openaq_units.csv")
  write_csv(all_units, units_path)
  cli_alert_success("Wrote units lookup to {units_path}")

  # Summary
  cli_h2("Summary")
  all_data |>
    group_by(city) |>
    summarise(
      n_days     = n(),
      date_min   = min(date),
      date_max   = max(date),
      .groups    = "drop"
    ) |>
    print()
}

main()
