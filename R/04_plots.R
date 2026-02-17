# 04_plots.R — Exploratory ggplots from city AQ data
#
# Reads data/city-aq.csv (output of 02_fetch_dust.R) and produces
# a handful of diagnostic plots saved to plots/.
#
# Usage: Rscript R/04_plots.R

source(here::here("R", "00_config.R"))
library(tidyverse)

df <- read_csv(here("data", "city-aq.csv"), show_col_types = FALSE) |>
  mutate(date = as.Date(date))

plots_dir <- here("plots")
ensure_dir(plots_dir)

# ── 1. Daily US AQI time series, faceted by city ────────────────────────────

p1 <- ggplot(df, aes(date, us_aqi, colour = country)) +
  geom_line(linewidth = 0.3, alpha = 0.7) +
  facet_wrap(~city, ncol = 5, scales = "free_y") +
  labs(title = "Daily US AQI by city (2025)", x = NULL, y = "US AQI") +
  theme_minimal(base_size = 9) +
  theme(legend.position = "bottom")

ggsave(file.path(plots_dir, "01_aqi_timeseries.png"), p1,
       width = 14, height = 10, dpi = 150)
cli_alert_success("Saved 01_aqi_timeseries.png")

# ── 2. PM2.5 vs PM10 scatter, coloured by dust ─────────────────────────────

p2 <- df |>
  filter(!is.na(pm2_5), !is.na(pm10)) |>
  ggplot(aes(pm10, pm2_5, colour = dust)) +
  geom_point(size = 0.4, alpha = 0.5) +
  scale_colour_viridis_c(option = "inferno", name = "Dust") +
  geom_abline(slope = 1, linetype = "dashed", colour = "grey50") +
  facet_wrap(~country, ncol = 2) +
  labs(title = "PM2.5 vs PM10 (coloured by dust concentration)",
       x = "PM10", y = "PM2.5") +
  theme_minimal(base_size = 10)

ggsave(file.path(plots_dir, "02_pm25_vs_pm10.png"), p2,
       width = 10, height = 8, dpi = 150)
cli_alert_success("Saved 02_pm25_vs_pm10.png")

# ── 3. Monthly boxplots of dust by country ──────────────────────────────────

p3 <- df |>
  mutate(month = floor_date(date, "month")) |>
  ggplot(aes(month, dust, fill = country, group = interaction(month, country))) +
  geom_boxplot(outlier.size = 0.3, alpha = 0.7) +
  labs(title = "Monthly dust concentration by country",
       x = NULL, y = "Dust (µg/m³)") +
  theme_minimal(base_size = 10) +
  theme(legend.position = "bottom")

ggsave(file.path(plots_dir, "03_dust_monthly_boxplot.png"), p3,
       width = 12, height = 6, dpi = 150)
cli_alert_success("Saved 03_dust_monthly_boxplot.png")

# ── 4. Heatmap: city × month mean AQI ──────────────────────────────────────

p4 <- df |>
  mutate(month = format(date, "%b")) |>
  mutate(month = factor(month, levels = format(
    seq(as.Date("2025-01-01"), as.Date("2025-12-01"), by = "month"), "%b"
  ))) |>
  group_by(city, month) |>
  summarise(aqi = mean(us_aqi, na.rm = TRUE), .groups = "drop") |>
  ggplot(aes(month, city, fill = aqi)) +
  geom_tile() +
  scale_fill_viridis_c(option = "rocket", direction = -1, name = "US AQI") +
  labs(title = "Mean US AQI by city and month", x = NULL, y = NULL) +
  theme_minimal(base_size = 10)

ggsave(file.path(plots_dir, "04_aqi_heatmap.png"), p4,
       width = 10, height = 8, dpi = 150)
cli_alert_success("Saved 04_aqi_heatmap.png")

cli_alert_success("All plots saved to {.path {plots_dir}}")
