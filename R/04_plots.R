source(here::here("R", "00_config.R"))
library(tidyverse)
library(sf)
library(rnaturalearth)
library(jsonlite)

df <- read.csv(PATH_ALL_OUT) |>
  mutate(date = as.Date(date)) |>
  filter(date >= "2024-03-01", date <= "2024-05-31")

world <- ne_countries(scale = "medium", returnclass = "sf")

# ── Static map for a single day ──────────────────────────────────────────────

plot_day <- function(d, day) {
  day_df <- d |> filter(date == day)
  ggplot() +
    geom_sf(data = world) +
    geom_spoke(
      data = day_df,
      aes(x = lon, y = lat,
          angle = (90 - wind_direction_10m_dominant) * pi / 180,
          radius = wind_speed_10m_max * 0.5),
      arrow = arrow(length = unit(0.1, "cm"))
    ) +
    coord_sf(xlim = c(100, 150), ylim = c(25, 50)) +
    labs(title = as.character(day))
}

# ── Compute wind arrow geometry ───────────────────────────────────────────────

# Shaft length scaled by wind speed (degrees of lon/lat)
shaft_len   <- 0.3
barb_len    <- 0.08
barb_angle  <- 25 * pi / 180

df <- df |>
  mutate(
    # Wind direction is "from" in meteorology; arrow points downwind
    angle_rad = (270 - wind_direction_10m_dominant) * pi / 180,
    shaft_scale = wind_speed_10m_max * shaft_len,
    # Shaft endpoint
    wind_lon = lon + cos(angle_rad) * shaft_scale,
    wind_lat = lat + sin(angle_rad) * shaft_scale,
    # Arrowhead: two barbs angled back from the tip
    back_angle = angle_rad + pi,  # reverse direction
    arrow_l_lon = wind_lon + cos(back_angle + barb_angle) * barb_len,
    arrow_l_lat = wind_lat + sin(back_angle + barb_angle) * barb_len,
    arrow_r_lon = wind_lon + cos(back_angle - barb_angle) * barb_len,
    arrow_r_lat = wind_lat + sin(back_angle - barb_angle) * barb_len,
    # Numeric date for slider
    date_num = as.numeric(date)
  )

# ── Build Vega-Lite spec ──────────────────────────────────────────────────────

proj <- list(type = "mercator", scale = 600, center = list(120, 38))

spec <- list(
  `$schema` = "https://vega.github.io/schema/vega-lite/v5.json",
  title = "Dust Transport Corridor \u2014 Spring 2024",
  width = 700,
  height = 500,
  projection = proj,
  params = list(
    list(
      name = "day",
      value = min(df$date_num),
      bind = list(
        input = "range",
        min = min(df$date_num),
        max = max(df$date_num),
        step = 1,
        name = "Date"
      )
    )
  ),
  data = list(values = df),
  transform = list(
    list(filter = "datum.date_num == day")
  ),
  layer = list(
    # Background map (uses its own data, inherits projection)
    list(
      data = list(
        url = paste0(
          "https://cdn.jsdelivr.net/npm/",
          "vega-datasets@2/data/world-110m.json"
        ),
        format = list(
          type = "topojson",
          feature = "countries"
        )
      ),
      mark = list(
        type = "geoshape",
        fill = "#f0f0f0",
        stroke = "#ccc",
        strokeWidth = 0.5
      )
    ),
    # Wind arrow shaft
    list(
      mark = list(
        type = "rule",
        stroke = "steelblue",
        strokeWidth = 1.5
      ),
      encoding = list(
        longitude  = list(field = "lon", type = "quantitative"),
        latitude   = list(field = "lat", type = "quantitative"),
        longitude2 = list(field = "wind_lon"),
        latitude2  = list(field = "wind_lat")
      )
    ),
    # Arrowhead left barb
    list(
      mark = list(
        type = "rule",
        stroke = "steelblue",
        strokeWidth = 1.5
      ),
      encoding = list(
        longitude  = list(
          field = "wind_lon", type = "quantitative"
        ),
        latitude   = list(
          field = "wind_lat", type = "quantitative"
        ),
        longitude2 = list(field = "arrow_l_lon"),
        latitude2  = list(field = "arrow_l_lat")
      )
    ),
    # Arrowhead right barb
    list(
      mark = list(
        type = "rule",
        stroke = "steelblue",
        strokeWidth = 1.5
      ),
      encoding = list(
        longitude  = list(
          field = "wind_lon", type = "quantitative"
        ),
        latitude   = list(
          field = "wind_lat", type = "quantitative"
        ),
        longitude2 = list(field = "arrow_r_lon"),
        latitude2  = list(field = "arrow_r_lat")
      )
    ),
    # Dust bubbles
    list(
      mark = list(type = "circle", opacity = 0.8),
      encoding = list(
        longitude = list(
          field = "lon", type = "quantitative"
        ),
        latitude = list(
          field = "lat", type = "quantitative"
        ),
        size = list(
          field = "dust_mean",
          type = "quantitative",
          scale = list(range = list(20, 800)),
          legend = list(title = "Dust (ug/m3)")
        ),
        color = list(
          field = "dust_mean",
          type = "quantitative",
          scale = list(scheme = "orangered"),
          legend = NULL
        ),
        tooltip = list(
          list(field = "city", type = "nominal"),
          list(field = "date", type = "temporal"),
          list(
            field = "dust_mean",
            type = "quantitative",
            title = "Dust (ug/m3)", format = ".1f"
          ),
          list(
            field = "pm_ratio",
            type = "quantitative",
            title = "PM2.5/PM10", format = ".2f"
          ),
          list(
            field = "wind_speed_10m_max",
            type = "quantitative",
            title = "Wind (m/s)", format = ".1f"
          ),
          list(
            field = "wind_direction_10m_dominant",
            type = "quantitative",
            title = "Wind dir", format = ".0f"
          )
        )
      )
    ),
    # City labels
    list(
      mark = list(type = "text", dy = -15, fontSize = 10),
      encoding = list(
        longitude = list(
          field = "lon", type = "quantitative"
        ),
        latitude = list(
          field = "lat", type = "quantitative"
        ),
        text = list(field = "city", type = "nominal")
      )
    )
  )
)

# Write spec
out_path <- here::here("data", "processed", "dust_map.vl.json")
write_json(spec, out_path, auto_unbox = TRUE, pretty = TRUE)
cli_alert_success("Wrote Vega-Lite spec to {out_path}")
