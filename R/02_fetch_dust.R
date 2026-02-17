# 02_fetch_dust.R — Fetch CAMS AQ data for 30 cities, aggregate hourly → daily
#
# 30 cities along the dust transport corridor (Gobi → China → Korea → Japan).
# Batched in groups of 50, with manual retry + backoff.
# Outputs CSV to data/.
#
# Usage: Rscript R/02_fetch_dust.R

source(here::here("R", "00_config.R"))
library(purrr)

BATCH_SIZE <- 50

# ── 30 cities along the dust corridor ──────────────────────────────────────

AQ_CITIES <- tribble(
  ~city,              ~lat,   ~lon,   ~country,
  # Mongolia
  "Ulaanbaatar",      47.91,  106.91, "Mongolia",
  "Choibalsan",       48.07,  114.54, "Mongolia",
  # Inner Mongolia / NW China
  "Erenhot",          43.65,  111.98, "China",
  "Hohhot",           40.85,  111.73, "China",
  "Baotou",           40.66,  109.84, "China",
  "Ordos",            39.63,  109.97, "China",
  # North China
  "Zhangjiakou",      40.82,  114.88, "China",
  "Beijing",          39.91,  116.40, "China",
  "Tianjin",          39.09,  117.20, "China",
  "Shijiazhuang",     38.04,  114.50, "China",
  "Jinan",            36.67,  116.98, "China",
  "Qingdao",          36.06,  120.38, "China",
  # NE China
  "Harbin",           45.75,  126.65, "China",
  "Changchun",        43.88,  125.32, "China",
  "Shenyang",         41.80,  123.40, "China",
  "Dalian",           38.91,  121.60, "China",
  "Dandong",          40.00,  124.35, "China",
  # Korea
  "Pyongyang",        39.02,  125.75, "North Korea",
  "Seoul",            37.57,  126.98, "South Korea",
  "Incheon",          37.46,  126.70, "South Korea",
  "Daejeon",          36.35,  127.38, "South Korea",
  "Daegu",            35.87,  128.60, "South Korea",
  "Gwangju",          35.16,  126.85, "South Korea",
  "Busan",            35.18,  129.08, "South Korea",
  "Jeju",             33.35,  126.53, "South Korea",
  # Japan
  "Fukuoka",          33.59,  130.40, "Japan",
  "Hiroshima",        34.39,  132.46, "Japan",
  "Osaka",            34.69,  135.50, "Japan",
  "Nagoya",           35.18,  136.91, "Japan",
  "Tokyo",            35.68,  139.69, "Japan",
)

CITY_AQ_VARS <- c(
  "us_aqi", "european_aqi",
  "pm2_5", "pm10",
  "dust", "aerosol_optical_depth",
  "carbon_monoxide", "nitrogen_dioxide", "sulphur_dioxide", "ozone"
)

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

# ── Parse multi-location AQ response (hourly → daily) ──────────────────────

parse_aq_response <- function(resp_json, cities, aq_vars) {
  locations <- if (is.null(names(resp_json))) resp_json else list(resp_json)

  map2(locations, seq_along(locations), function(loc, i) {
    hourly <- loc$hourly
    times <- unlist(hourly$time)

    cols <- list(
      datetime = times,
      city     = cities$city[i],
      country  = cities$country[i],
      lat      = cities$lat[i],
      lon      = cities$lon[i]
    )
    for (v in aq_vars) {
      cols[[v]] <- if (!is.null(hourly[[v]])) safe_dbl(hourly[[v]]) else rep(NA_real_, length(times))
    }

    as_tibble(cols) |>
      mutate(date = substr(datetime, 1, 10)) |>
      group_by(date, city, country, lat, lon) |>
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
  cli_h1("City AQ: {GRID_DATE_START} to {GRID_DATE_END}")
  cli_alert_info("{nrow(AQ_CITIES)} cities, {length(CITY_AQ_VARS)} hourly vars → daily mean")

  batch_ids <- ceiling(seq_len(nrow(AQ_CITIES)) / BATCH_SIZE)
  batches <- split(AQ_CITIES, batch_ids)
  cli_alert_info("Batches: {length(batches)} × {BATCH_SIZE} cities")

  all_aq <- map(seq_along(batches), function(b) {
    batch <- batches[[b]]
    cli_h2("Batch {b}/{length(batches)} ({nrow(batch)} cities)")

    resp <- perform_with_retry(
      openmeteo_aq_grid_req(
        lats        = batch$lat,
        lons        = batch$lon,
        start       = GRID_DATE_START,
        end         = GRID_DATE_END,
        hourly_vars = CITY_AQ_VARS
      ),
      label = paste0("AQ batch ", b)
    )

    aq <- parse_aq_response(resp, batch, CITY_AQ_VARS)
    cli_alert_success("Batch {b}: {nrow(aq)} rows")

    if (b < length(batches)) {
      cli_alert_info("Waiting 60s before next batch...")
      Sys.sleep(60)
    }

    aq
  }) |> list_rbind()

  cli_alert_success("Total: {nrow(all_aq)} rows")

  # ── Write CSV ──
  out_path <- here("data", "city-aq.csv")
  ensure_dir(out_path)
  readr::write_csv(all_aq, out_path)
  cli_alert_success("Wrote {.path {out_path}} ({round(file.size(out_path) / 1e6, 1)} MB)")

  # ── Summary ──
  cli_h2("Summary")
  all_aq |>
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
