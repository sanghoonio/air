# 06_inspect_grid.R — Inspect grid-history.parquet variable coverage
#
# Quick diagnostics on the fetched parquet:
#   - Dimensions and column types
#   - NA rates per variable
#   - Summary stats for each AQ variable
#   - Temporal coverage check
#
# Usage: Rscript R/06_inspect_grid.R

source(here::here("R", "00_config.R"))
library(arrow)
library(tidyr)

df <- read_parquet(PATH_GRID_HISTORY)

# ── Dimensions & types ────────────────────────────────────────────────────

cli_h1("Schema")
cli_alert_info("Rows: {nrow(df)}  Columns: {ncol(df)}")
cat("\n")
glimpse(df)

# ── NA rates ──────────────────────────────────────────────────────────────

cli_h1("NA rates")

aq_cols <- setdiff(names(df), c("date", "lat", "lon",
                                 "wind_speed", "wind_direction"))

na_rates <- df |>
  summarise(across(all_of(aq_cols), ~ mean(is.na(.x)))) |>
  pivot_longer(everything(), names_to = "variable", values_to = "na_rate") |>
  arrange(na_rate) |>
  mutate(na_pct = sprintf("%.1f%%", na_rate * 100))

print(na_rates, n = Inf)

# ── Summary stats ─────────────────────────────────────────────────────────

cli_h1("Summary stats (non-NA)")

stats <- df |>
  summarise(across(all_of(aq_cols), list(
    min    = ~ min(.x, na.rm = TRUE),
    median = ~ median(.x, na.rm = TRUE),
    mean   = ~ mean(.x, na.rm = TRUE),
    max    = ~ max(.x, na.rm = TRUE),
    sd     = ~ sd(.x, na.rm = TRUE)
  ))) |>
  pivot_longer(
    everything(),
    names_to = c("variable", "stat"),
    names_pattern = "^(.+)_(min|median|mean|max|sd)$"
  ) |>
  pivot_wider(names_from = stat, values_from = value) |>
  arrange(variable)

print(stats, n = Inf)

# ── Temporal coverage ─────────────────────────────────────────────────────

cli_h1("Temporal coverage")

date_range <- df |>
  summarise(
    date_min = min(date),
    date_max = max(date),
    n_dates  = n_distinct(date),
    n_points = n_distinct(paste(lat, lon))
  )
print(date_range)

# Dates with worst coverage (most NAs across all AQ vars)
cli_h2("Dates with highest mean NA rate (top 10)")

date_na <- df |>
  group_by(date) |>
  summarise(
    across(all_of(aq_cols), ~ mean(is.na(.x))),
    .groups = "drop"
  ) |>
  rowwise() |>
  mutate(mean_na = mean(c_across(all_of(aq_cols)))) |>
  ungroup() |>
  arrange(desc(mean_na)) |>
  select(date, mean_na) |>
  mutate(mean_na_pct = sprintf("%.1f%%", mean_na * 100)) |>
  head(10)

print(date_na)

# ── Spatial coverage per variable ─────────────────────────────────────────

cli_h1("Spatial coverage (% of grid points with data)")

spatial <- df |>
  group_by(lat, lon) |>
  summarise(
    across(all_of(aq_cols), ~ mean(!is.na(.x))),
    .groups = "drop"
  ) |>
  summarise(
    across(all_of(aq_cols), ~ mean(.x))
  ) |>
  pivot_longer(everything(), names_to = "variable",
               values_to = "coverage") |>
  arrange(desc(coverage)) |>
  mutate(coverage_pct = sprintf("%.1f%%", coverage * 100))

print(spatial, n = Inf)

# ── Export CSV ────────────────────────────────────────────────────────────

PATH_GRID_CSV <- here("data", "processed", "grid-history.csv")
ensure_dir(PATH_GRID_CSV)

readr::write_csv(df, PATH_GRID_CSV)
cli_alert_success("Wrote {nrow(df)} rows to {.path {PATH_GRID_CSV}}")
