---
date: 2026-02-15
status: draft
description: Split monolithic App.svelte into lib modules and Svelte components
---

# Split App.svelte into components

## Context

App.svelte is ~1150 lines containing everything: constants, types, pure functions, state, data loading, rendering, and all template sections. Splitting into logical modules and components for maintainability.

## Extraction plan

### Lib modules (pure TS, no Svelte)

| File | What moves there | ~Lines |
|------|-----------------|--------|
| `src/lib/types.ts` | `VectorDatum`, `RawDatum`, `GridPoint`, `Bounds`, `CityDatum`, `AqiBand` | 30 |
| `src/lib/config.ts` | Grid constants, `VIEW`/`FETCH` bounds, `buildGrid`, `CITY_COORDS`, `VISIBLE_CITIES` | 170 |
| `src/lib/aqi.ts` | `AQI_BANDS`, `AQI_STOPS`, `aqiColor()` | 50 |
| `src/lib/interpolation.ts` | `INTERP_DEFAULT`, `interpolateGrid()`, `computeCityData()` and helpers | 120 |
| `src/lib/utils.ts` | `paint()`, `timeAgo()` | 15 |

### Svelte components

| Component | What it contains | Props |
|-----------|-----------------|-------|
| `AqiLegend.svelte` | Wide + narrow legend variants | None (imports `AQI_BANDS` directly) |
| `InfoModal.svelte` | The `<dialog>` modal | None |
| `LoadingOverlay.svelte` | Loading bar, error, live empty-state | `loading`, `hasVectors`, `error`, `mode`, + 2 callbacks |
| `ControlPanel.svelte` | Both historical and live control bars | ~13 read props + ~7 callback props (see below) |

### ControlPanel interface

Read props: `mode`, `isPlaying`, `histDates`, `selectedDateIdx`, `selectedDate`, `sliderPct`, `speedIdx`, `interp`, `animEnabled`, `loading`, `lastUpdated`, `isDemo`, `speedLabels`

Callback props: `onTogglePlay`, `onSliderChange(idx)`, `onCycleSpeed`, `onInterpChange(val)`, `onToggleAnim`, `onSwitchMode(mode)`, `onFetchData`, `onShowInfo`

The slider styles (`.hist-slider`, `.panel-controls` rules) move into ControlPanel.

### What stays in App.svelte (~700 lines)

- All `$state`/`$derived` declarations
- Data loading: `loadHistory`, `fetchData`, `renderHistoricalDate`, `switchMode`, playback control, `handleKeydown`
- Entire rendering pipeline: `buildPlot`, vector DOM optimization, resize observer, main `$effect`
- Initialization logic
- Outer layout shell composing the child components

### What is intentionally NOT extracted

- **Map rendering as a component**: The render pipeline does imperative DOM manipulation (querySelectorAll, typed-array caches, requestAnimationFrame). Wrapping it in a component adds indirection without reducing complexity.
- **State store/context**: Only one level of prop passing (App -> ControlPanel). A store is premature.

## Execution order

1. Create `lib/types.ts`, `lib/utils.ts`, `lib/aqi.ts` (no interdependencies)
2. Create `lib/config.ts` (imports types), `lib/interpolation.ts` (imports types + config)
3. Create `AqiLegend.svelte`, `InfoModal.svelte` (simple, few deps)
4. Create `LoadingOverlay.svelte`, `ControlPanel.svelte`
5. Refactor `App.svelte` — replace inline code with imports, replace template sections with components

## Verification

- `npm run build` in `ui/` must succeed with no errors
- `npm run dev` — visual check that map, legend, controls, modal, overlays all work as before
