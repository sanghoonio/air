# air

Wind and air quality monitoring for NE China, Korea, and Japan.

## Why

I built this to visualize how wind patterns carry air pollution across Northeast Asia. While yellow dust has been a geological phenomenon for millennia, some Koreans are still quick to blame China for all of our air quality issues. I still see the sentiment reinforced online. It even came up visiting relatives in Korea for the first time in 15 years. Just how much of the dust is actually from Central Asian deserts, Chinese manufacturing hubs, or Korea itself? Perhaps this map can help answer that.

## `ui/` — Wind & AQI Map

Svelte SPA with two modes:

- **Historical** (default) — loads a pre-built parquet file with daily wind and AQI data across an 800-point grid (2025, ~2 MB shipped; full 3yr file kept locally). Scrub through dates with a slider or hit play to animate. Transitions between days are interpolated at up to 5x grid density.
- **Live** — queries Open-Meteo's forecast and air quality APIs on demand for current conditions. Can be slow or fail under load.

Interpolates a coarse 2° grid into a dense vector field with bicubic upsampling and renders with Observable Plot on a Mercator projection. Arrows are colored by US AQI.

### Keyboard shortcuts (historical mode)

- `Space` — play/pause
- `←` / `→` — step one day
- `↑` / `↓` — change playback speed
- `a` — toggle animation

### Setup

```sh
cd ui
npm install
npm run dev
```

### Stack

Vite 6, Svelte 5, TypeScript, Tailwind CSS v4, DaisyUI v5, Observable Plot, hyparquet, world-atlas + topojson-client.

## `R/` — Data Pipeline

R scripts for fetching historical weather and dust/AQI data.

- `00_config.R` — shared city coordinates, grid constants, and API config
- `01_fetch_weather.R` — pull weather data for 12 cities
- `02_fetch_dust.R` — pull dust/AQI data for 12 cities
- `03_check_data.R` — data validation
- `04_plots.R` — visualization
- `05_fetch_grid_history.R` — batch-fetch 3yr grid history → `ui/public/grid-history.parquet`

## How this was built

The `ui/` SPA was built across a few sessions with Claude Code (Opus 4.6). Sam provided the vision, design direction, and domain decisions — map region, city selection, arrow aesthetics, color scales, layout. Claude handled scaffolding, API integration, interpolation math, animation performance, and iterative refinement. The historical mode, parquet pipeline, and animated transitions were added in a second session. Most debugging time went into getting smooth frame-to-frame animation — caching projected coordinates, snapshotting into typed arrays to avoid Svelte proxy issues, and mapping Observable Plot's clipped elements back to data indices via d3's `__data__` bindings.
