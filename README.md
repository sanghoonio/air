# air

Wind and air quality monitoring for NE China, Korea, and Japan.

## Why

In Korea, it's common knowledge that bad air days come from China. After visiting family in Korea for the first time in 15 years, I kept hearing this — but when you actually look at the wind patterns, the story is more complicated. Sometimes the wind is blowing offshore and the air is still bad. This project puts wind direction and AQI on the same map so you can see for yourself where it's coming from on any given day.

## `ui/` — Wind & AQI Map

Svelte SPA that shows current wind vectors and AQI across NE Asia. Fetches from Open-Meteo (free, no auth), interpolates a coarse grid into a dense vector field with bicubic upsampling, and renders with Observable Plot on a Mercator projection.

### Setup

```sh
cd ui
npm install
npm run dev
```

### Demo mode

Avoid API rate limits by fetching data once and loading from a local file:

```sh
npm run fetch-demo   # saves to public/demo-data.json
```

Then visit `http://localhost:5173/?demo`.

### Stack

Vite 6, Svelte 5, TypeScript, Tailwind CSS v4, DaisyUI v5, Observable Plot, world-atlas + topojson-client.

## `R/` — Analysis Pipeline

R scripts for fetching and analyzing historical weather and dust/AQI data.

- `00_config.R` — shared city coordinates and API config
- `01_fetch_weather.R` — pull weather data
- `02_fetch_dust.R` — pull dust/AQI data
- `03_check_data.R` — data validation
- `04_plots.R` — visualization

## How this was built

The `ui/` SPA was built in a single session with Claude Code (Opus 4.6). Sam provided the vision, design direction, and domain decisions — map region, city selection, arrow aesthetics, color scales, layout. Claude handled scaffolding, API integration, interpolation math, and iterative refinement. Most of the session was spent wrestling with Open-Meteo's rate limits and tuning arrow length/opacity/density until it looked right. The bicubic interpolation, demo data pipeline, and caching architecture came out of that back-and-forth.
