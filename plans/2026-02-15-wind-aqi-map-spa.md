---
date: 2026-02-15
status: complete
description: Svelte SPA wind vector + AQI map for NE China / Korea / Japan using Observable Plot
---

# Wind & AQI Map — Svelte SPA

## Context

Standalone frontend (separate from the R analysis pipeline) that shows **current** wind vectors and AQI at major cities across NE China, Korea, and Japan. Lives in `ui/` (already exists, empty). No backend — fetches directly from free, no-auth Open-Meteo APIs in the browser.

## APIs

Two Open-Meteo endpoints, both free and keyless:

| Data | Endpoint | Params |
|------|----------|--------|
| Wind + temp | `https://api.open-meteo.com/v1/forecast` | `current=wind_speed_10m,wind_direction_10m,wind_gusts_10m,temperature_2m` `&wind_speed_unit=ms` |
| AQI + PM | `https://air-quality-api.open-meteo.com/v1/air-quality` | `current=us_aqi,us_aqi_pm2_5,us_aqi_pm10,pm2_5,pm10` `&domains=cams_global` |

Both accept comma-separated `latitude`/`longitude` for multi-location queries (returns array). Two total HTTP requests to populate the whole map.

## Cities (~18 stations)

**NE China:** Harbin, Changchun, Shenyang, Dalian, Beijing, Hohhot
**Korea:** Pyongyang, Seoul, Incheon, Busan
**Japan:** Fukuoka, Osaka, Nagoya, Tokyo, Sendai, Sapporo
**Reference:** Vladivostok (RU), Ulaanbaatar (MN)

Coordinates reused from `R/00_config.R` where available, supplemented for new cities.

## Stack

```
ui/
  package.json
  vite.config.ts
  tsconfig.json
  svelte.config.js
  index.html
  src/
    main.ts
    App.svelte
    app.css
    vite-env.d.ts
```

- **Vite 6 + Svelte 5 + TypeScript** — SPA, no SvelteKit
- **Tailwind CSS v4** + **DaisyUI v5** + **@tailwindcss/typography** — all UI styling
- **lucide-svelte** — icons (refresh button, etc.)
- **@observablehq/plot** — cartographic rendering (map SVG)
- **world-atlas** + **topojson-client** — 110m country outlines for basemap

### CSS setup (`src/app.css`)

```css
@import 'tailwindcss';

@plugin "@tailwindcss/typography";
@plugin "daisyui" {
  themes: dark --default;
}
```

Dark theme by default (map visualization looks best on dark). DaisyUI's `dark` theme provides semantic tokens (`base-100`, `base-200`, `base-300`, `base-content`, `primary`, etc.) used throughout the page chrome.

### Styling boundary

- **Page chrome** (title bar, legend, cards, buttons, layout): Tailwind utilities + DaisyUI component classes. No inline styles, no raw hex colors.
- **Observable Plot SVG** (the map itself): Plot's `style` option with hardcoded colors — necessary because Plot renders its own SVG outside Tailwind's scope. AQI data colors (green/yellow/orange/red/purple/maroon) are a domain-specific visualization scale, not UI theme colors.

## Visualization Design

**Observable Plot** with a Mercator projection clipped to ~108–145°E, 28–48°N:

1. **Basemap** — `Plot.geo()` with 110m country polygons. Dark fill, muted borders. Ocean via `Plot.frame()`.

2. **AQI halos** — `Plot.dot()` at each city. Semi-transparent fill + brighter stroke. Standard US AQI color scale:
   - 0–50 green, 51–100 yellow, 101–150 orange, 151–200 red, 201–300 purple, 301+ maroon

3. **Wind vectors** — `Plot.vector()` at each city. Arrow points in direction wind blows **to** (`rotate = (meteo_direction + 180) % 360`). Length scaled by wind speed (~8–50px for 0–15 m/s). Anchor "middle".

4. **Labels** — `Plot.text()` with city name above each point, AQI numeric value at center.

### Page layout (Tailwind + DaisyUI)

```
┌─────────────────────────────────────────────────┐
│  navbar: title + timestamp badge + refresh btn  │  ← DaisyUI navbar
├─────────────────────────────────────────────────┤
│                                                 │
│         card containing Plot SVG                │  ← DaisyUI card, overflow-hidden
│                                                 │
├─────────────────────────────────────────────────┤
│  AQI legend (badge chips)  │  Wind scale ref    │  ← flex row, gap-4
└─────────────────────────────────────────────────┘
```

- Outer container: `flex flex-col min-h-screen bg-base-200`
- Navbar: `navbar bg-base-100 border-b border-base-300`
- Map card: `card bg-base-100 shadow-sm border border-base-300 mx-4 my-4`
- Legend section: `flex items-center gap-4 px-4 pb-4`
- AQI chips: `badge` with inline background color (domain-specific, not themeable)
- Refresh button: `btn btn-ghost btn-sm` with `lucide-svelte` RefreshCw icon
- Timestamp: `badge badge-ghost` with formatted time
- Loading state: DaisyUI `loading loading-spinner` centered in the card

## Key Design Decisions

- **Open-Meteo forecast API (not archive)** for current conditions — archive only has historical data
- **`domains=cams_global`** required for AQ API — default `auto` tries Europe-only model
- **Wind arrow rotation** — meteorological convention is "from" direction; arrows rotated +180° to show "towards" direction
- **No aqicn.org** — needs a token; Open-Meteo AQ gives US AQI from CAMS model data
- **Auto-refresh toggle** — 10-minute interval, off by default
- **DaisyUI dark theme as default** — map visualizations read best on dark backgrounds; semantic tokens keep the rest of the UI consistent

## Build Steps

1. Scaffold `ui/` with package.json, Vite + Svelte + Tailwind configs, index.html
2. `npm install` in `ui/`
3. Write `src/app.css` — Tailwind + DaisyUI imports (dark theme default)
4. Write `src/App.svelte` — single component: fetch on mount, render Plot in `$effect`, DaisyUI chrome around it
5. Write `src/main.ts` + `src/vite-env.d.ts` — Svelte 5 mount boilerplate
6. Test with `npm run dev`

## Verification

1. `cd ui && npm run dev` — opens on localhost
2. Page should show dark-themed UI with navbar, card, and legend
3. Map renders with country outlines for China, Korea, Japan
4. Wind arrows at all ~18 city positions with varying directions/lengths
5. AQI halos with color-coded circles
6. Refresh button re-fetches and updates
7. Network tab shows exactly 2 API calls (forecast + air-quality)
