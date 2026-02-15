---
date: 2026-02-14
status: draft
description: API reference for air quality and weather data collection (OpenAQ, Open-Meteo, aqicn.org)
---

# Data Collection API Reference

R + httr2 for all collection. This document covers three data sources plus
geographic/domain context for the yellow dust transport analysis.

---

## Table of Contents

1. [Monitoring Cities](#1-monitoring-cities)
2. [OpenAQ — Air Quality Measurements](#2-openaq--air-quality-measurements)
3. [Open-Meteo — Historical Weather](#3-open-meteo--historical-weather)
4. [Open-Meteo — Air Quality & Dust](#4-open-meteo--air-quality--dust)
5. [aqicn.org — Real-Time AQI](#5-aqicnorg--real-time-aqi)
6. [Yellow Dust Context](#6-yellow-dust-context)
7. [Data Strategy Summary](#7-data-strategy-summary)

---

## 1. Monitoring Cities

Transect from Gobi Desert source region through NE China to Korea and Japan.

| # | City | Role | Lat | Lon | Notes |
|---|------|------|-----|-----|-------|
| 1 | Sainshand, Mongolia | Gobi source | 44.89 | 110.12 | Southern Mongolia desert edge |
| 2 | Erlian/Erenhot, Inner Mongolia | Border entry | 43.65 | 111.98 | Mongolia-China border crossing |
| 3 | Hohhot, Inner Mongolia | Transit | 40.85 | 111.73 | Inner Mongolia capital |
| 4 | Beijing | Transit | 39.91 | 116.40 | North China Plain, major emitter |
| 5 | Shenyang, Liaoning | Transit | 41.80 | 123.40 | NE China industrial corridor |
| 6 | Dalian, Liaoning | Coastal transit | 38.91 | 121.60 | Bohai Sea coast, used in transboundary studies |
| 7 | Seoul | Primary receptor | 37.57 | 126.98 | |
| 8 | Incheon | Primary receptor | 37.46 | 126.70 | Western coast, first landfall |
| 9 | Busan | Receptor | 35.18 | 129.08 | Southern Korea |
| 10 | Fukuoka | First Japan receptor | 33.59 | 130.40 | Closest major city to continent |
| 11 | Osaka | Japan receptor | 34.69 | 135.50 | |
| 12 | Tokyo | Japan receptor | 35.68 | 139.69 | |

**Optional reference stations:**

- Baengnyeongdo (37.97N, 124.63E) — remote Yellow Sea island, used as background/transboundary reference
- Ulaanbaatar (47.92N, 106.91E) — Mongolia capital, lidar monitoring since 2007

---

## 2. OpenAQ — Air Quality Measurements

**Purpose:** Historical air quality data (multi-year backfill). Government monitoring station data.

### Basics

| | |
|---|---|
| Base URL | `https://api.openaq.org/v3` |
| Auth | API key required via `X-API-Key` header |
| Register | https://explore.openaq.org/register |
| Rate limit | **60 req/min, 2000 req/hr** (free tier) |
| Data since | ~2015 (varies by country) |
| Python SDK | `pip install openaq` |
| R package | https://openaq.github.io/openaq-r |

### Key Endpoints

#### List locations by country

```
GET /v3/locations?iso={CC}&limit=1000
```

Country codes: `CN` (China), `KR` (South Korea), `JP` (Japan), `MN` (Mongolia)

Filter by pollutant: `&parameters_id=2` (PM2.5)

Bounding box: `&bbox=100.0,30.0,145.0,50.0`

Radius from point: `&coordinates=37.57,126.98&radius=25000`

#### Get sensors at a location

```
GET /v3/locations/{locations_id}/sensors
```

Each sensor measures one parameter. You need the `sensors_id` to pull measurements.

#### Pull measurements (the main data endpoint)

```
GET /v3/sensors/{sensors_id}/days?datetime_from=2023-01-01&datetime_to=2024-01-01&limit=1000
```

Aggregation levels:

| Endpoint | Resolution |
|----------|------------|
| `/v3/sensors/{id}/measurements` | Raw (10min-24hr, varies) |
| `/v3/sensors/{id}/hours` | Hourly averages |
| `/v3/sensors/{id}/days` | **Daily averages** (recommended) |
| `/v3/sensors/{id}/years` | Yearly averages |

Rollups are also available: `/days/monthly`, `/days/yearly`, `/hours/hourofday`, `/hours/dayofweek`, `/days/monthofyear`

**Date filtering params:** `datetime_from`, `datetime_to` (ISO 8601 date or datetime)

**Pagination:** `limit` (max 1000), `page` (1-indexed). Check `meta.found` for total count.

**Performance:** Always constrain to ≤1 year per request. Unbounded queries can 408 timeout.

### Available Pollutants

| Parameter ID | Name | Units |
|---|---|---|
| 1 | PM10 | ug/m3 |
| 2 | PM2.5 | ug/m3 |
| 7 | NO2 | ug/m3 or ppm |
| 8 | CO | ug/m3 or ppm |
| 9 | SO2 | ug/m3 or ppm |
| 10 | O3 | ug/m3 or ppm |

List all: `GET /v3/parameters`

### Country Coverage

| Country | ISO | Stations | Source | Notes |
|---------|-----|----------|--------|-------|
| China | CN | ~1400+ | CNEMC | PM2.5, PM10, O3, NO2, SO2, CO. Occasional access gaps. |
| South Korea | KR | ~650+ | AirKorea | Good coverage, all criteria pollutants |
| Japan | JP | varies | soramame.taiki.go.jp | Coverage available but station count unclear |
| Mongolia | MN | limited | — | Likely Ulaanbaatar only or very sparse |

### S3 Bulk Archive (Preferred for Backfill)

Public S3 bucket — **no API key, no rate limit**, just HTTP GET.

**URL pattern:**

```
https://openaq-data-archive.s3.amazonaws.com/records/csv.gz/locationid={id}/year={yyyy}/month={mm}/location-{id}-{yyyymmdd}.csv.gz
```

**CSV schema** (9 columns, long/stacked format, hourly resolution):

```
location_id, sensors_id, location, datetime, lat, lon, parameter, units, value
```

- One row per sensor per hour; all parameters for a station stacked vertically in a single file
- Each parameter has its own `sensors_id`
- Parameters include whatever that station measures (pm10, pm25, no2, co, so2, o3, no, nox, etc.)
- Units vary by source country (ug/m3 for PM; Chinese stations may use ug/m3 for gases, US/Korean may use ppm)
- `datetime` includes timezone offset (e.g. `2026-02-10T01:00:00-07:00`)

**Example row:**

```csv
"location_id","sensors_id","location","datetime","lat","lon","parameter","units","value"
2178,3919,"Del Norte-2178","2026-02-10T01:00:00-07:00","35.1353","-106.584702","pm10","µg/m³","21.0"
```

**Freshness lag:** Documented as ~72hr, **observed ~4 days** (Feb 14 → latest file Feb 10). May vary by station.

**Data volume:** For one station over 5 years ≈ 1,825 small gzipped files (1–5 KB each). Minutes to download.

**Workflow:** Use the API (rate-limited) to discover `location_id` values for target cities, then download in bulk from S3 (no limit). Aggregate hourly → daily yourself in R.

**httr2 S3 download pattern (R):**

```r
download_openaq_s3 <- function(location_id, date) {
  yr <- format(date, "%Y")
  mo <- format(date, "%m")
  ds <- format(date, "%Y%m%d")
  url <- paste0(
    "https://openaq-data-archive.s3.amazonaws.com/records/csv.gz/",
    "locationid=", location_id,
    "/year=", yr, "/month=", mo,
    "/location-", location_id, "-", ds, ".csv.gz"
  )
  # direct GET, no auth needed
  request(url) |>
    req_retry(max_tries = 3, backoff = ~ 2) |>
    req_perform()
}
```

### httr2 Pattern (R)

```r
library(httr2)

openaq_req <- function(path, ..., api_key = Sys.getenv("OPENAQ_API_KEY")) {
  request("https://api.openaq.org/v3") |>
    req_url_path_append(path) |>
    req_url_query(...) |>
    req_headers(`X-API-Key` = api_key) |>
    req_retry(max_tries = 3, backoff = ~ 2) |>
    req_throttle(rate = 55 / 60)  # stay under 60/min
}

# list PM2.5 stations in Korea
resp <- openaq_req("locations", iso = "KR", parameters_id = 2, limit = 1000) |>
  req_perform() |>
  resp_body_json()

# daily data for a sensor
resp <- openaq_req(
  paste0("sensors/", sensor_id, "/days"),
  datetime_from = "2023-01-01",
  datetime_to = "2024-01-01",
  limit = 1000
) |>
  req_perform() |>
  resp_body_json()
```

---

## 3. Open-Meteo — Historical Weather

**Purpose:** Wind speed, wind direction, temperature, humidity, precipitation. Multi-decade backfill.

### Basics

| | |
|---|---|
| Base URL | `https://archive-api.open-meteo.com/v1/archive` |
| Auth | None required (free tier) |
| Rate limit | **10,000/day**, 5,000/hr, 600/min |
| Data since | **1940** (ERA5) or 1950 (ERA5-Land at 11km) |
| Commercial use | Requires paid plan |

### Request Parameters

**Required:** `latitude`, `longitude`, `start_date`, `end_date`

**Optional:**

| Param | Default | Options |
|---|---|---|
| `daily` | (none) | comma-separated variable names |
| `hourly` | (none) | comma-separated variable names |
| `temperature_unit` | celsius | fahrenheit |
| `wind_speed_unit` | kmh | **ms**, mph, kn |
| `precipitation_unit` | mm | inch |
| `timezone` | GMT | any IANA string or `auto` |
| `models` | best_match | era5, era5_land, ecmwf_ifs, cerra |

### Daily Variables (Relevant Subset)

**Temperature:**
`temperature_2m_max`, `temperature_2m_min`, `mean_temperature_2m`

**Humidity:**
`mean_relative_humidity_2m`, `maximum_relative_humidity_2m`, `minimum_relative_humidity_2m`

**Wind:**
`wind_speed_10m_max`, `mean_wind_speed_10m`, **`wind_direction_10m_dominant`**

**Precipitation:**
`precipitation_sum`, `rain_sum`, `snowfall_sum`, `precipitation_hours`

**Pressure:**
`mean_sea_level_pressure`

### Hourly Variables (Relevant Subset)

`temperature_2m`, `relative_humidity_2m`, `wind_speed_10m`, **`wind_direction_10m`**, `precipitation`, `rain`, `snowfall`, `pressure_msl`, `cloud_cover`, `weather_code`

### Data Models

| Model | Resolution | Coverage | Since |
|---|---|---|---|
| ERA5 | 25 km | Global | 1940 |
| ERA5-Land | 11 km | Global | 1950 |
| ECMWF IFS | 9 km | Global | 2017 |

### Response Format

```json
{
  "latitude": 37.57,
  "longitude": 126.98,
  "elevation": 38.0,
  "daily": {
    "time": ["2024-03-01", "2024-03-02"],
    "temperature_2m_max": [12.3, 14.1],
    "wind_direction_10m_dominant": [285, 310]
  },
  "daily_units": {
    "temperature_2m_max": "°C",
    "wind_direction_10m_dominant": "°"
  }
}
```

### Example URL

```
https://archive-api.open-meteo.com/v1/archive
  ?latitude=37.5665&longitude=126.978
  &start_date=2020-01-01&end_date=2024-12-31
  &daily=temperature_2m_max,temperature_2m_min,mean_relative_humidity_2m,
         wind_speed_10m_max,mean_wind_speed_10m,wind_direction_10m_dominant,
         precipitation_sum,rain_sum,snowfall_sum,mean_sea_level_pressure
  &wind_speed_unit=ms
  &timezone=Asia/Seoul
```

### httr2 Pattern (R)

```r
openmeteo_weather <- function(lat, lon, start, end, daily_vars,
                              wind_unit = "ms", tz = "auto") {
  request("https://archive-api.open-meteo.com/v1/archive") |>
    req_url_query(
      latitude = lat,
      longitude = lon,
      start_date = start,
      end_date = end,
      daily = paste(daily_vars, collapse = ","),
      wind_speed_unit = wind_unit,
      timezone = tz
    ) |>
    req_retry(max_tries = 3, backoff = ~ 2) |>
    req_throttle(rate = 500 / 60)  # stay under 600/min
}

daily_vars <- c(
  "temperature_2m_max", "temperature_2m_min",
  "mean_relative_humidity_2m",
  "wind_speed_10m_max", "mean_wind_speed_10m",
  "wind_direction_10m_dominant",
  "precipitation_sum", "rain_sum", "snowfall_sum",
  "mean_sea_level_pressure"
)

resp <- openmeteo_weather(37.5665, 126.978, "2020-01-01", "2024-12-31", daily_vars) |>
  req_perform() |>
  resp_body_json()
```

---

## 4. Open-Meteo — Air Quality & Dust

**Purpose:** Modeled PM2.5, PM10, mineral dust concentration (CAMS). Useful for dust tracking where OpenAQ has no station coverage (Mongolia, Inner Mongolia).

### Basics

| | |
|---|---|
| Base URL | `https://air-quality-api.open-meteo.com/v1/air-quality` |
| Auth | None required |
| Rate limit | Same as weather: 10,000/day |
| Data since | **Aug 2022** (CAMS Global, the only option for East Asia) |
| Resolution | 25 km, 3-hourly |

### Key Variables

| Variable | Unit | Description |
|---|---|---|
| **`dust`** | ug/m3 | **Mineral dust concentration** (total of fine + coarse + super-coarse bins) |
| `pm10` | ug/m3 | Modeled PM10 |
| `pm2_5` | ug/m3 | Modeled PM2.5 |
| `aerosol_optical_depth` | — | Column-integrated AOD |
| `ozone` | ug/m3 | O3 |
| `nitrogen_dioxide` | ug/m3 | NO2 |
| `sulphur_dioxide` | ug/m3 | SO2 |
| `carbon_monoxide` | ug/m3 | CO |
| `us_aqi` | — | Composite US AQI |
| `us_aqi_pm2_5` | — | PM2.5 sub-index |
| `us_aqi_pm10` | — | PM10 sub-index |

**Important:** Set `domains=cams_global` to ensure global model is used for East Asia (the default `auto` may try to use the Europe-only model).

### Request Parameters

Same lat/lon/date pattern as the weather API:

```
?latitude=37.5665&longitude=126.978
&hourly=dust,pm10,pm2_5,aerosol_optical_depth
&start_date=2023-03-01&end_date=2023-05-31
&domains=cams_global
&timezone=Asia/Seoul
```

Historical range: `start_date`/`end_date` work back to at least Aug 2022. The documented `past_days` param caps at 92 but explicit dates go further.

### Dust Variable Details

The CAMS `dust` variable aggregates three mineral dust size bins:

- Fine: 0.03–0.55 um radius
- Coarse: 0.55–0.9 um
- Super-coarse: 0.9–20 um

All bins assume density 2610 kg/m3. This is **mineral/natural dust only**, not industrial PM.

### httr2 Pattern (R)

```r
openmeteo_airquality <- function(lat, lon, start, end, hourly_vars, tz = "auto") {
  request("https://air-quality-api.open-meteo.com/v1/air-quality") |>
    req_url_query(
      latitude = lat,
      longitude = lon,
      start_date = start,
      end_date = end,
      hourly = paste(hourly_vars, collapse = ","),
      domains = "cams_global",
      timezone = tz
    ) |>
    req_retry(max_tries = 3, backoff = ~ 2) |>
    req_throttle(rate = 500 / 60)
}

aq_vars <- c("dust", "pm10", "pm2_5", "aerosol_optical_depth")

resp <- openmeteo_airquality(37.5665, 126.978, "2023-03-01", "2023-05-31", aq_vars) |>
  req_perform() |>
  resp_body_json()
```

---

## 5. aqicn.org — Real-Time AQI

**Purpose:** Prospective daily collection going forward. Supplements OpenAQ.

### Basics

| | |
|---|---|
| Base URL | `https://api.waqi.info` |
| Auth | Token as query param: `?token=YOUR_TOKEN` |
| Rate limit | 1,000 req/sec (generous) |
| Historical data | **None via API.** Real-time/current only. |
| Data platform | Manual request at aqicn.org/data-platform/query/ for historical |

### Key Endpoints

#### Get current feed by city

```
GET https://api.waqi.info/feed/{city}/?token=YOUR_TOKEN
```

City can be a name (`beijing`) or station ID (`@1437`).

#### Search stations

```
GET https://api.waqi.info/search/?keyword={query}&token=YOUR_TOKEN
```

#### Get feed by lat/lon

```
GET https://api.waqi.info/feed/geo:{lat};{lon}/?token=YOUR_TOKEN
```

### Response Fields

```json
{
  "status": "ok",
  "data": {
    "aqi": 65,
    "dominentpol": "pm25",
    "iaqi": {
      "pm25": {"v": 65},
      "pm10": {"v": 36},
      "o3": {"v": 23.5},
      "no2": {"v": 22.1},
      "so2": {"v": 3.9},
      "co": {"v": 6.4},
      "h": {"v": 20},
      "t": {"v": 6},
      "w": {"v": 3},
      "p": {"v": 1027}
    },
    "city": {
      "name": "Beijing",
      "geo": [39.9, 116.4]
    },
    "time": {
      "s": "2024-01-15 12:00:00",
      "tz": "+08:00"
    },
    "forecast": {
      "daily": {
        "pm25": [{"avg": 55, "day": "2024-01-16", "max": 70, "min": 40}],
        "pm10": [...],
        "o3": [...]
      }
    }
  }
}
```

**`iaqi` fields:** pm25, pm10, o3, no2, so2, co (pollutants), h (humidity), t (temperature), w (wind speed), p (pressure). **No wind direction.**

### Limitations for This Project

- No historical endpoint — real-time snapshots only
- No wind direction
- Useful as a supplementary daily cron job going forward, not for backfill
- TOS prohibits redistribution of cached/archived data (relevant if publishing the dataset)

### httr2 Pattern (R)

```r
aqicn_feed <- function(city, token = Sys.getenv("AQICN_TOKEN")) {
  request("https://api.waqi.info/feed") |>
    req_url_path_append(paste0(city, "/")) |>
    req_url_query(token = token) |>
    req_retry(max_tries = 3, backoff = ~ 2)
}

# by city name
resp <- aqicn_feed("seoul") |> req_perform() |> resp_body_json()

# by coordinates
resp <- aqicn_feed("geo:37.57;126.98") |> req_perform() |> resp_body_json()
```

---

## 6. Yellow Dust Context

### Source Regions

| Source | Location | Role |
|--------|----------|------|
| **Gobi Desert** | Southern Mongolia + Inner Mongolia (Badain Jaran, Tengger, Hobq deserts) | **Dominant source** for dust reaching Korea/Japan. ~42%+ of dust in N. China. Flat terrain + westerlies = efficient eastward transport. |
| Taklamakan Desert | Tarim Basin, Xinjiang (western China) | Largest emitter by area but dust is **trapped in the basin** by surrounding mountains + low-level easterlies. Minimal influence on Korea/Japan. |
| Loess Plateau | Shaanxi, Shanxi, Gansu, Ningxia | Primarily a **deposition zone**. Can re-emit in strong winds but secondary. |

**Answer to your question:** The dust reaching Korea/Japan is predominantly from the **Gobi Desert** — southern Mongolia and Inner Mongolia, not western China. The Taklamakan (Xinjiang) is too basin-trapped to contribute meaningfully to eastward transport. Inner Mongolia and Mongolia proper are the key source areas.

### Transport Path

```
Gobi Desert (southern Mongolia)
  ↓  northwesterly winds / Mongolian cyclone
Inner Mongolia (Erlian → Hohhot)
  ↓
North China Plain (Beijing → Tianjin)
  ↓
NE China (Shenyang corridor)
  ↓  crosses Yellow Sea / Bohai Sea
Korean Peninsula (Incheon → Seoul → Busan)
  ↓  crosses Korea Strait
Western Japan (Fukuoka → Osaka → Tokyo)
  ↓
Pacific Ocean
```

Meteorological driver: **Mongolian cyclones** (explain ~34-47% of Gobi dust emissions and nearly all high-impact events). These create strong NW winds that loft dust into the boundary layer and push it eastward along the jet stream.

### Seasonality

**Peak: March–May (spring), April worst month.**

- Spring = 61% of Mongolian dust storms
- Seoul averages ~9 yellow dust days/year (1991-2020): 2.2 Mar, 3.1 Apr
- Fall is secondary (22%), winter 10%, summer 7%
- Worst year on record: 2001 (27 yellow dust days in Seoul)

Spring peak because: source regions are dry/bare pre-monsoon, frozen ground thaws loosening soil, Mongolian cyclones most active from land-sea temperature contrasts.

### Distinguishing Dust vs. Industrial Pollution

**PM2.5/PM10 ratio is the primary quick indicator:**

| Source | PM2.5/PM10 | Dominant Size | Typical Season |
|--------|------------|---------------|----------------|
| Natural dust | Low (0.3–0.5) | Coarse (PM2.5-10) | Spring |
| Industrial | High (0.6–0.8+) | Fine (PM2.5) | Winter |
| Mixed | 0.4–0.6 | Both | Spring (dust picks up pollution in transit) |

**Practical rules for visualization:**

1. PM10 spike + low PM2.5/PM10 ratio + spring + NW wind = **DUST**
2. PM2.5 spike + high PM2.5/PM10 ratio + winter + stagnant air = **INDUSTRIAL**
3. Both elevated + moderate ratio + spring = **MIXED** (dust carrying industrial pollutants from NE China transit)
4. Time-lagged correlation: dust wave shows as 1-3 day lagged spike moving sequentially through the transect (Sainshand → Beijing → Seoul → Fukuoka)
5. Wind direction: NW winds = dust origin; SW winds = NE China industrial corridor

**The mixing problem:** During transport through industrialized NE China, dust particles pick up sulfate and nitrate on their surfaces (heterogeneous chemistry). A "dust event" arriving in Seoul often carries industrial pollutants as passengers. This mixed category is actually the most common real-world scenario. Transboundary transport contributes ~53% of PM2.5 in South Korea and ~61% in Japan.

The Open-Meteo `dust` variable (CAMS model) isolates mineral dust specifically, which is valuable for separating the dust signal from total PM. Comparing OpenAQ station PM10 vs Open-Meteo modeled `dust` gives you a way to estimate the anthropogenic fraction.

---

## 7. Data Strategy Summary

### Sources by Variable

| Variable | Historical Source | Going Forward |
|----------|-------------------|---------------|
| PM2.5, PM10, O3, NO2, SO2, CO | **OpenAQ** (station, ~2015+) | OpenAQ + aqicn.org cron |
| Wind speed, wind direction | **Open-Meteo Weather** (ERA5, 1940+) | Open-Meteo Weather |
| Temperature, humidity, pressure | **Open-Meteo Weather** | Open-Meteo Weather |
| Precipitation (amount + type) | **Open-Meteo Weather** | Open-Meteo Weather |
| Mineral dust concentration | **Open-Meteo AQ** (CAMS, Aug 2022+) | Open-Meteo AQ |
| Composite AQI | aqicn.org (real-time only) | aqicn.org cron |

### Recommended Resolution

**Daily** for the multi-year cross-country correlation study. Hourly adds noise without improving the cross-border transport signal (which operates on ~1-3 day timescales).

### Coverage Gaps

- **Mongolia stations:** Very sparse in OpenAQ. Use Open-Meteo CAMS `dust` for Gobi source monitoring instead.
- **Open-Meteo AQ history:** Only Aug 2022+. For dust events before 2022, would need CAMS reanalysis directly from Copernicus CDS.
- **aqicn.org historical:** Requires manual data platform request, not guaranteed.
- **Wind direction:** Only from Open-Meteo, not aqicn.org or OpenAQ.

### Later Enhancement

If surface wind correlations are noisy, pull **850 hPa wind** data from ERA5 via the Copernicus Climate Data Store. Boundary-layer winds are more representative of actual long-range transport than 10m surface winds.
