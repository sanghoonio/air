---
date: 2026-02-15
status: in-progress
description: Add historical grid data (3yr parquet) with day slider to wind/AQI map
---

# Historical Grid Data + Day Slider

## Context

The UI currently shows **live** wind + AQI data for a 2° grid over NE Asia. An R pipeline already fetches historical data for 12 cities. This plan adds a **historical mode**: an R script pre-computes 3 years of daily grid data as a parquet file, and the UI loads it with a date slider so users can scrub through time and see how wind patterns and air quality evolved day by day.

## Architecture

```
R script (offline, ~7 min)          Browser (runtime)
───────────────────────────          ──────────────────
798 grid pts × 2 APIs               [Live mode]  → existing fetchData()
  → batch 50 pts/call                    ↓
  → 32 API calls total              [Historical] → fetch parquet (~5 MB)
  → join weather + AQ                    ↓
  → write_parquet()                  parquetRead() → build Map<date, Map<"lat,lon", RawDatum>>
      ↓                                  ↓
ui/public/grid-history.parquet       slider picks date → look up Map → interpolateGrid() → render
```

The critical integration point: `interpolateGrid(raw: Map<string, RawDatum>, area, interp)` at `App.svelte:295` already does all spatial interpolation. Historical mode just feeds it a different `raw` Map per date. Zero changes to the interpolation or rendering code.

## Step 1: Add grid constants to `R/00_config.R`

Append after the existing output paths (line 50):

- Grid bounds matching the UI's FETCH region: lon 88–162, lat 18–58, step 2° = 798 points
- Date range: `2023-02-15` to `2026-02-15`
- Two new request-builder functions for multi-location (comma-separated lat/lon) calls to the archive weather API and the CAMS air quality API

## Step 2: Create `R/05_fetch_grid_history.R`

New script that:

1. Builds the 798-point grid with `expand.grid()`
2. Splits into batches of 50 points (16 batches)
3. For each batch, makes 2 API calls:
   - **Weather**: `archive-api.open-meteo.com/v1/archive` with `daily=wind_speed_10m_mean,wind_direction_10m_dominant`
   - **AQI**: `air-quality-api.open-meteo.com/v1/air-quality` with `daily=us_aqi,pm2_5` (fall back to hourly aggregation if daily param not supported)
4. Parses array responses, binds into single tibble
5. Writes parquet with columns: `date` (character YYYY-MM-DD), `lat`, `lon`, `wind_speed`, `wind_direction`, `us_aqi`, `pm2_5`

**~32 API calls total at 5 req/min = ~7 min runtime.** Dates stored as character strings to avoid timezone/epoch issues in the browser.

Estimated output: **~875K rows, ~5 MB** parquet (snappy compressed).

## Step 3: Install `hyparquet` in `ui/`

```
npm install hyparquet
```

Pure JS parquet reader, ~30KB, reads snappy-compressed parquet natively. Lighter than Arquero for this use case (we only need column extraction, not data wrangling). The key function is `parquetRead()` which returns row data from an ArrayBuffer.

## Step 4: Add historical mode to `App.svelte`

### New state (after line 404)

```typescript
let mode = $state<"live" | "historical">("historical");
let histLoading = $state(false);
let histError = $state<string | null>(null);
let histIndex = $state<Map<string, Map<string, RawDatum>> | null>(null);
let histDates = $state<string[]>([]);
let selectedDateIdx = $state(0);
let selectedDate = $derived(histDates[selectedDateIdx] ?? "");
let isPlaying = $state(false);
```

### `loadHistory()` function

- Fetches `grid-history.parquet` from `import.meta.env.BASE_URL`
- Reads with `parquetRead()` → array of row objects
- Builds `Map<dateString, Map<"lat,lon", RawDatum>>` — converts wind speed+direction to u/v components (same as live mode at line 490–494)
- Sets `histDates` (sorted) and defaults slider to most recent date
- One-time load; cached in memory (~80–100 MB heap, fine for desktop)

### `renderHistoricalDate()` function

```typescript
function renderHistoricalDate() {
  if (!histIndex || !selectedDate) return;
  const dayRaw = histIndex.get(selectedDate);
  if (!dayRaw) return;
  rawCache = dayRaw;
  vectors = interpolateGrid(dayRaw, FETCH, interp);
  cityData = computeCityData(VISIBLE_CITIES, vectors, STEP / interp);
}
```

This is essentially `reinterpolate()` (line 517) but sourcing from the date-indexed historical data instead of live cache.

### Reactive effects

- **Init**: since historical is default, the init `$effect` (line 626) calls `loadHistory()` instead of `fetchData()`. `fetchData()` is only called when user explicitly switches to live mode.
- `$effect`: when `mode` switches to `"historical"`, call `loadHistory()` (no-ops if already loaded)
- `$effect`: when `selectedDate` changes in historical mode, call `renderHistoricalDate()`
- `$effect`: when `mode` switches to `"live"`, call `fetchData()` (fetches current conditions)

### Play/animate

- `togglePlay()`: starts/stops a `setInterval` at 200ms (5 fps) that increments `selectedDateIdx`
- Loops back to start when reaching the end

## Step 5: UI markup changes — bottom-right overlay only

**No new overlay.** Everything stays in the existing bottom-right control bar (line 672). Historical is the **default mode**.

### Replace the demo link with a "Live" toggle

The `?demo` link (line 695–698) is replaced with a mode toggle. Since historical is default, the button reads "Live" when in historical mode, and "Historical" when in live mode — clicking always switches.

### In historical mode (default), the overlay expands to fit the slider

Layout of the bottom-right overlay when `mode === "historical"`:

```
[ ▶ ] [ ═══════════ slider ═══════════ ] 2024-03-15 · ×5 · Live
```

- **Play/pause** button (left)
- **Range slider** (`range range-xs`) — takes `flex-1` to fill available space
- **Date label** (formatted date string)
- **·** separator
- **Interpolation selector** (existing ×1–×5)
- **·** separator
- **"Live"** button — switches to live mode

### In live mode, overlay contracts back to current layout

```
[DEMO badge if demo] [timestamp] · ×5 · ↻ · Historical
```

- Existing timestamp, interpolation selector, refresh button
- **"Historical"** button — switches back to historical mode
- Refresh button only shown in live mode

## Files to modify

| File | Change |
|------|--------|
| `R/00_config.R` | Add grid constants, date range, output path, multi-location request builders |
| `R/05_fetch_grid_history.R` | **New** — batch-fetch 3yr grid data → parquet |
| `ui/package.json` | Add `hyparquet` dependency |
| `ui/src/App.svelte` | Import hyparquet, add state/functions/markup for historical mode |

## Edge cases

- **Missing parquet**: `loadHistory()` catches fetch errors, shows inline error message
- **CAMS data gaps**: Some ocean/remote grid points may have null AQI. Existing `val()` function (line 284) treats null as 0 — vectors still render, just gray
- **Date column type**: Stored as character in R → hyparquet returns strings → no date parsing needed
- **Coordinate rounding**: R uses `round(lat, 1)`, JS uses `Math.round(lat * 10) / 10` — both produce identical results for 2° grid multiples
- **Interpolation selector**: When changed in historical mode, call `renderHistoricalDate()` instead of `reinterpolate()` — or just have both read from `rawCache` since we set it in `renderHistoricalDate()`

## Verification

1. Run `Rscript R/05_fetch_grid_history.R` — check output size (~5 MB), row count (~875K), sample dates
2. `cd ui && npm run dev` — verify live mode works unchanged (regression)
3. On load — app starts in historical mode, parquet loads, slider visible in bottom-right overlay
4. Drag slider — map updates with historical data, interpolation looks correct
5. Change interpolation factor (x1–x5) — works in historical mode
6. Click play — animation loops through dates smoothly
7. Click "Live" — fetches current data, slider hides, refresh button appears
8. Click "Historical" — returns to slider mode
8. `npm run build` — verify `grid-history.parquet` included in `dist/`
