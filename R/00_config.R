# 00_config.R — Shared configuration for data collection pipeline
# Source this file at the top of every script: source(here::here("R", "00_config.R"))

library(httr2)
library(dplyr)
library(tibble)
library(here)
library(cli)

# ── Cities ────────────────────────────────────────────────────────────────────

CITIES <- tribble(
  ~city,                ~lat,    ~lon,    ~country,    ~tz,
  "Sainshand",          44.89,   110.12,  "Mongolia",  "Asia/Ulaanbaatar",
  "Erlian",             43.65,   111.98,  "China",     "Asia/Shanghai",
  "Hohhot",             40.85,   111.73,  "China",     "Asia/Shanghai",
  "Beijing",            39.91,   116.40,  "China",     "Asia/Shanghai",
  "Shenyang",           41.80,   123.40,  "China",     "Asia/Shanghai",
  "Dalian",             38.91,   121.60,  "China",     "Asia/Shanghai",
  "Seoul",              37.57,   126.98,  "South Korea", "Asia/Seoul",
  "Incheon",            37.46,   126.70,  "South Korea", "Asia/Seoul",
  "Busan",              35.18,   129.08,  "South Korea", "Asia/Seoul",
  "Fukuoka",            33.59,   130.40,  "Japan",     "Asia/Tokyo",
  "Osaka",              34.69,   135.50,  "Japan",     "Asia/Tokyo",
  "Tokyo",              35.68,   139.69,  "Japan",     "Asia/Tokyo"
)

# ── Date ranges ───────────────────────────────────────────────────────────────

DATE_START <- "2022-08-01"
DATE_END   <- "2025-12-31"

# ── Parameters ────────────────────────────────────────────────────────────────

WEATHER_DAILY_VARS <- c(
  "temperature_2m_max", "temperature_2m_min",
  "relative_humidity_2m_mean",
  "wind_speed_10m_max", "wind_speed_10m_mean",
  "wind_direction_10m_dominant",
  "precipitation_sum", "rain_sum", "snowfall_sum",
  "pressure_msl_mean"
)

DUST_HOURLY_VARS <- c("dust", "pm10", "pm2_5", "aerosol_optical_depth")

# ── Output paths ──────────────────────────────────────────────────────────────

PATH_WEATHER_OUT   <- here("data", "processed", "weather.parquet")
PATH_DUST_OUT      <- here("data", "processed", "dust.parquet")
PATH_ALL_OUT       <- here("data", "processed", "all.csv")

# ── Helpers ───────────────────────────────────────────────────────────────────

ensure_dir <- function(path) {
  dir <- if (grepl("\\.[a-zA-Z0-9]+$", path)) dirname(path) else path
  if (!dir.exists(dir)) dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  invisible(path)
}

# ── Grid constants (for historical grid data) ───────────────────────────────

GRID_LON_MIN    <- 88
GRID_LON_MAX    <- 162
GRID_LAT_MIN    <- 18
GRID_LAT_MAX    <- 58
GRID_STEP       <- 2
GRID_DATE_START <- "2023-02-15"
GRID_DATE_END   <- "2026-02-15"

PATH_GRID_HISTORY <- here("ui", "public", "grid-history.parquet")

# ── httr2 request builders ────────────────────────────────────────────────────

#' Build an Open-Meteo historical weather request
openmeteo_weather_req <- function(lat, lon, start, end, daily_vars,
                                  wind_unit = "ms", tz = "auto") {
  request("https://archive-api.open-meteo.com/v1/archive") |>
    req_url_query(
      latitude  = lat,
      longitude = lon,
      start_date = start,
      end_date   = end,
      daily = paste(daily_vars, collapse = ","),
      wind_speed_unit = wind_unit,
      timezone = tz
    ) |>
    req_retry(max_tries = 3, backoff = ~ 2) |>
    req_throttle(rate = 5 / 60)
}

#' Build an Open-Meteo CAMS air quality request
openmeteo_dust_req <- function(lat, lon, start, end, hourly_vars,
                               tz = "auto") {
  request("https://air-quality-api.open-meteo.com/v1/air-quality") |>
    req_url_query(
      latitude  = lat,
      longitude = lon,
      start_date = start,
      end_date   = end,
      hourly  = paste(hourly_vars, collapse = ","),
      domains = "cams_global",
      timezone = tz
    ) |>
    req_retry(max_tries = 3, backoff = ~ 2) |>
    req_throttle(rate = 5 / 60)
}

#' Build a multi-location weather archive request (comma-separated coords)
openmeteo_weather_grid_req <- function(lats, lons, start, end, daily_vars,
                                       wind_unit = "ms") {
  request("https://archive-api.open-meteo.com/v1/archive") |>
    req_url_query(
      latitude  = paste(lats, collapse = ","),
      longitude = paste(lons, collapse = ","),
      start_date = start,
      end_date   = end,
      daily = paste(daily_vars, collapse = ","),
      wind_speed_unit = wind_unit,
      timezone = "UTC"
    ) |>
    req_retry(max_tries = 5, backoff = ~ 15) |>
    req_throttle(rate = 4 / 60, realm = "open-meteo.com")
}

#' Build a multi-location air quality request (comma-separated coords)
openmeteo_aq_grid_req <- function(lats, lons, start, end, hourly_vars) {
  request("https://air-quality-api.open-meteo.com/v1/air-quality") |>
    req_url_query(
      latitude  = paste(lats, collapse = ","),
      longitude = paste(lons, collapse = ","),
      start_date = start,
      end_date   = end,
      hourly  = paste(hourly_vars, collapse = ","),
      domains = "cams_global",
      timezone = "UTC"
    ) |>
    req_retry(max_tries = 5, backoff = ~ 15) |>
    req_throttle(rate = 4 / 60, realm = "open-meteo.com")
}
