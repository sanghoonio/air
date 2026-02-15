# 01_discover_openaq.R — Find OpenAQ station candidates near target cities
#
# Usage: Rscript R/01_discover_openaq.R
#
# Requires: OPENAQ_API_KEY environment variable (register at explore.openaq.org)
# Output:   data/openaq_candidates.csv
#
# After running, review the candidates and create data/stations.csv with
# one row per city: city, location_id, station_name

source(here::here("R", "00_config.R"))
library(purrr)

# ── Discover stations for one city ────────────────────────────────────────────

discover_city <- function(city_row) {
  city_name <- city_row$city
  lat <- city_row$lat
  lon <- city_row$lon

  cli_h2("Searching: {city_name}")

  candidates <- NULL

  # API caps radius at 25000m, so use bounding box for wider searches
  search_radii_km <- c(25, 50, 100)

  for (r_km in search_radii_km) {
    cli_alert_info("Trying radius {r_km} km...")

    if (r_km <= 25) {
      # Use the native coordinates+radius for ≤25km
      resp <- openaq_req(
        "locations",
        coordinates = paste0(lat, ",", lon),
        radius = r_km * 1000,
        limit  = 100
      ) |>
        req_perform() |>
        resp_body_json()
    } else {
      # Use bounding box for wider searches
      # ~1 degree lat ≈ 111km; lon varies with cos(lat)
      dlat <- r_km / 111
      dlon <- r_km / (111 * cos(lat * pi / 180))
      bbox <- paste(lon - dlon, lat - dlat, lon + dlon, lat + dlat, sep = ",")

      resp <- openaq_req(
        "locations",
        bbox  = bbox,
        limit = 100
      ) |>
        req_perform() |>
        resp_body_json()
    }

    results <- resp$results
    if (length(results) > 0) {
      cli_alert_success("Found {length(results)} location(s) at {r_km} km")
      candidates <- results
      break
    }
  }

  if (is.null(candidates) || length(candidates) == 0) {
    cli_alert_warning("No stations found for {city_name} within 100 km")
    return(tibble(
      city = city_name, location_id = NA_integer_, station_name = NA_character_,
      lat = NA_real_, lon = NA_real_, distance_km = NA_real_,
      params_available = NA_character_, n_target_params = 0L,
      total_measurements = 0L, datetime_first = NA_character_,
      datetime_last = NA_character_
    ))
  }

  # Parse each location into a row
  rows <- map(candidates, function(loc) {
    loc_id   <- loc$id
    loc_name <- loc$name %||% NA_character_
    loc_lat  <- loc$coordinates$latitude %||% NA_real_
    loc_lon  <- loc$coordinates$longitude %||% NA_real_

    # Distance from target city (Haversine approximation)
    dist_km <- haversine(lat, lon, loc_lat, loc_lon)

    # Extract parameter names
    param_names <- map_chr(loc$sensors %||% list(), function(s) {
      s$parameter$name %||% NA_character_
    }) |> unique() |> tolower()

    # Count how many of our target params this station has
    target_hits <- intersect(param_names, OPENAQ_PARAMS)

    tibble(
      city               = city_name,
      location_id        = loc_id,
      station_name       = loc_name,
      lat                = loc_lat,
      lon                = loc_lon,
      distance_km        = round(dist_km, 1),
      params_available   = paste(param_names, collapse = ", "),
      n_target_params    = length(target_hits),
      total_measurements = loc$totalMeasurements %||% 0L,
      datetime_first     = loc$datetimeFirst$utc %||% NA_character_,
      datetime_last      = loc$datetimeLast$utc %||% NA_character_
    )
  }) |> list_rbind()

  # Rank: most target params first, then most measurements

  rows <- rows |>
    arrange(desc(n_target_params), desc(total_measurements))

  rows
}

# ── Haversine distance (km) ──────────────────────────────────────────────────

haversine <- function(lat1, lon1, lat2, lon2) {
  R <- 6371
  to_rad <- pi / 180
  dlat <- (lat2 - lat1) * to_rad
  dlon <- (lon2 - lon1) * to_rad
  a <- sin(dlat / 2)^2 + cos(lat1 * to_rad) * cos(lat2 * to_rad) * sin(dlon / 2)^2
  2 * R * asin(sqrt(a))
}

# ── Main ──────────────────────────────────────────────────────────────────────

main <- function() {
  if (Sys.getenv("OPENAQ_API_KEY") == "") {
    cli_abort("Set OPENAQ_API_KEY environment variable before running this script.")
  }

  cli_h1("OpenAQ Station Discovery")

  all_candidates <- map(seq_len(nrow(CITIES)), function(i) {
    discover_city(CITIES[i, ])
  }) |> list_rbind()

  # Write full candidates file
  ensure_dir(PATH_CANDIDATES)
  readr::write_csv(all_candidates, PATH_CANDIDATES)
  cli_alert_success("Wrote {nrow(all_candidates)} candidates to {PATH_CANDIDATES}")

  # Print top 3 per city
  cli_h1("Top 3 Candidates per City")
  for (cn in unique(all_candidates$city)) {
    top3 <- all_candidates |>
      filter(city == cn) |>
      head(3)

    cli_h2(cn)
    if (nrow(top3) == 0 || all(is.na(top3$location_id))) {
      cli_alert_warning("No stations found")
    } else {
      for (j in seq_len(nrow(top3))) {
        r <- top3[j, ]
        cli_alert_info(paste0(
          "ID {r$location_id}: {r$station_name} ({r$distance_km} km, ",
          "{r$n_target_params} params, {format(r$total_measurements, big.mark = ',')} meas)"
        ))
      }
    }
  }

  cli_rule()
  cli_alert_info(paste0(
    "Next step: review {PATH_CANDIDATES} and create {PATH_STATIONS}\n",
    "with columns: city, location_id, station_name (one row per city).\n",
    "Leave location_id blank for cities with no suitable station."
  ))
}

main()
