---
date: 2026-02-14
status: complete
description: R data collection pipeline for East Asian transboundary air quality analysis
---

# Data Collection Pipeline — R Scripts

## Context

Collect air quality, weather, and dust data for 12 cities along the Gobi→NE China→Korea→Japan
dust transport corridor (2020-2025). The user will do all EDA and visualization; we're building
the collection pipeline only. R + httr2, parquet output, standalone scripts.

## Directory Structure

```
air/
  R/
    00_config.R              # Cities, dates, paths, shared httr2 helpers
    01_discover_openaq.R     # Find OpenAQ station IDs near target cities
    02_fetch_openaq.R        # S3 bulk download → daily aggregation → parquet
    03_fetch_weather.R       # Open-Meteo historical weather → parquet
    04_fetch_dust.R          # Open-Meteo CAMS dust/AQ → parquet
  data/
    stations.csv             # User-curated station picks (output of 01, input to 02)
    openaq_candidates.csv    # All candidates from discovery (reference)
    raw/openaq/{loc_id}/     # Raw .csv.gz files from S3
    processed/
      openaq.parquet
      weather.parquet
      dust.parquet
```

## Execution Order

```
01_discover_openaq.R  →  [user picks stations]  →  02_fetch_openaq.R
                                                    03_fetch_weather.R   (independent)
                                                    04_fetch_dust.R      (independent)
```

02, 03, 04 are independent of each other. Only 02 depends on `stations.csv`.

## Scripts

### 00_config.R

Sourced by all scripts. Defines:

- `CITIES` tibble: 12 rows with `city`, `lat`, `lon`, `country`, `tz`
- Date range constants: `DATE_START = "2020-01-01"`, `DATE_END = "2025-12-31"`, `DUST_DATE_START = "2022-08-01"`
- Output paths for parquet files, raw directory
- `OPENAQ_PARAMS`: `c("pm25", "pm10", "no2", "co", "so2", "o3")`
- `WEATHER_DAILY_VARS`: the 10 Open-Meteo variable names
- `DUST_HOURLY_VARS`: `c("dust", "pm10", "pm2_5", "aerosol_optical_depth")`
- Shared httr2 request builders with throttle/retry baked in
- `ensure_dir()` helper

### 01_discover_openaq.R — Station Discovery

- For each city, query `GET /v3/locations?coordinates={lat},{lon}&radius=25000&limit=100`
- If zero results, widen to 50km, then 100km
- Rank candidates by: (a) number of target params available, (b) total measurement count
- Write `data/openaq_candidates.csv` with: `city`, `location_id`, `station_name`, `lat`, `lon`, `distance_km`, `params_available`, `total_measurements`, `datetime_first`, `datetime_last`
- Print top-3 per city to console
- Instruct user to create `data/stations.csv` with one `city, location_id, station_name` per row
- Sainshand/Mongolia will likely have zero stations — print clear message, leave row blank in stations.csv

### 02_fetch_openaq.R — S3 Bulk Download + Aggregation

**Download phase:**
- Read `stations.csv`, skip cities with empty `location_id`
- For each station × each date in range: construct S3 URL, check if local `.csv.gz` exists, skip if so (resumable)
- Download via `httr2::req_perform()` — no auth, no rate limit
- HTTP 404 = no data for that day, record and continue. 5xx = retry 3x.
- Progress via `cli::cli_progress_bar()`
- ~22,000 files, estimated 30-45 min

**Aggregation phase:**
- Read all raw `.csv.gz` files with `readr::read_csv()`
- Assign date using local timezone (from config `tz` column)
- Filter to target parameters only
- Group by `city, date, parameter, units` → compute `mean`, `max`, `n_obs`
- Pivot wider: each param gets `{param}_mean`, `{param}_max`, `{param}_n` columns
- Preserve `units` per parameter as a separate lookup (handle ug/m3 vs ppm across countries)
- Write `data/processed/openaq.parquet`

**Output columns:** `city, country, date, location_id, station_name, lat, lon, pm25_mean, pm25_max, pm25_n, pm10_mean, pm10_max, pm10_n, no2_mean, ...` (same pattern for co, so2, o3)

### 03_fetch_weather.R — Open-Meteo Historical Weather

- For each of 12 cities: one API call covering full 2020-2025 range
- Request 10 daily variables, `wind_speed_unit=ms`, city timezone
- Parse JSON response arrays into data frame
- Bind all cities, write `data/processed/weather.parquet`
- 12 API calls total, under 1 minute

**Output columns:** `city, country, lat, lon, date, temperature_2m_max, temperature_2m_min, mean_relative_humidity_2m, wind_speed_10m_max, mean_wind_speed_10m, wind_direction_10m_dominant, precipitation_sum, rain_sum, snowfall_sum, mean_sea_level_pressure`

### 04_fetch_dust.R — Open-Meteo CAMS Dust

- Date range: Aug 2022 → Dec 2025 only (CAMS Global limitation)
- For each city: one API call requesting hourly `dust, pm10, pm2_5, aerosol_optical_depth`
- Must set `domains=cams_global` for East Asia
- Aggregate 3-hourly → daily: `mean`, `max`, `min` per variable
- Write `data/processed/dust.parquet`

**Output columns:** `city, country, lat, lon, date, dust_mean, dust_max, dust_min, pm10_mean, pm10_max, pm2_5_mean, pm2_5_max, aod_mean, aod_max`

## Key Design Decisions

1. **One parquet per source, not per city.** ~12 cities × 2190 days is tiny. Single files with a `city` column are simpler to join.

2. **S3 archive for OpenAQ, not the API.** No rate limit, no pagination. API used only for station discovery (small number of calls).

3. **Manual station selection.** Auto-selecting nearest station risks picking one with poor coverage or wrong type (roadside vs background). The discovery script surfaces candidates; the user picks.

4. **Raw files retained.** The ~100MB of raw `.csv.gz` stays in `data/raw/` for re-aggregation if needed.

5. **Units preserved, not normalized.** Different countries report gases in different units. The parquet stores what the source provides. Normalization is an analysis concern.

6. **Aggregation: mean + max + n_obs.** The `n_obs` count lets the user filter days with insufficient hourly coverage during analysis.

## Dependencies

httr2, arrow, dplyr, tidyr, readr, purrr, lubridate, cli, here

## Verification

1. Run `01_discover_openaq.R` — should produce `openaq_candidates.csv` with candidates for ≥10 of 12 cities (Sainshand likely empty)
2. Create `stations.csv`, run `02_fetch_openaq.R` — check that `openaq.parquet` has daily data, reasonable PM2.5 ranges (0-500 ug/m3), no all-NA cities
3. Run `03_fetch_weather.R` — check that `weather.parquet` has 2190 rows per city (6 years × 365), wind direction values 0-360
4. Run `04_fetch_dust.R` — check that `dust.parquet` starts Aug 2022, dust values spike in March-May (spring dust season)
5. Quick sanity: load all three parquets, join on `city + date`, confirm rows align
