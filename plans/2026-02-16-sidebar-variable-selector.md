---
date: 2026-02-16
status: complete
description: Add collapsible right sidebar with variable selector and animated bar chart
---

# Collapsible Sidebar with Variable Selector & Bar Chart

## Context

The map currently colors wind vectors by US AQI only, but the parquet contains 16 AQ variables (PM2.5, PM10, dust, ozone, NO2, SO2, CO, AOD, European AQI, plus US AQI sub-indices). On desktop, we want a collapsible right sidebar that lets the user pick which variable to color on, see an updated legend, and view a horizontal bar chart of that variable across all interpolated cities — with animated bar width transitions between date frames.

## Architecture

### Data pipeline changes

**RawDatum expansion** — Currently `{u, v, aqi}`. Store all 16 AQ columns in a `metrics` record at parse time so variable switching is instant (no re-parsing).

**Interpolation parameterization** — `interpolateGrid()` gets a `metricKey` param. Only the selected metric is interpolated alongside u/v. When the user switches variables, we re-interpolate from the cached raw data (~instant on the interpolated grid).

**Naming** — Rename `aqi` field to `metric` on `VectorDatum` and `CityDatum` since the field now holds whichever variable is selected.

### Variable configuration

New file `lib/variables.ts` — registry of selectable variables with:
- `key`, `label`, `unit`, `domain: [min, max]`
- `colorType: "aqi" | "sequential"` — AQI-type vars reuse existing `aqiColor()`, concentration vars get a green→yellow→orange→red sequential gradient
- Auto-generated legend bands per variable

**Exposed variables** (10 in dropdown, excluding us_aqi sub-indices to keep it clean):
`us_aqi`, `european_aqi`, `pm2_5`, `pm10`, `dust`, `aerosol_optical_depth`, `carbon_monoxide`, `nitrogen_dioxide`, `sulphur_dioxide`, `ozone`

### Color mapping

- `metricColor(value, config)` function dispatches to `aqiColor()` for AQI-type or does linear gradient interpolation for concentration-type
- Both map vectors and bar chart use the same function → always consistent

### Bar chart

- Observable Plot `barX` — city names on Y, metric value on X
- Cities sorted descending by value, filtered for non-null
- Consistent bar height (18px per bar), scrollable container
- Each bar colored with `metricColor()`
- Value label at bar end

**Animation approach: CSS transitions on rect elements**
1. After Plot.plot() builds new SVG, query the `<rect>` elements
2. Set their widths to previous cached values
3. Insert into DOM with `transition: width 400ms ease-in-out`
4. Next rAF: set widths to target values → smooth CSS transition
5. Duration syncs with playback speed when auto-playing

### Sidebar UI & Layout

The sidebar **pushes the map** rather than overlaying it, so all map overlays (legend, control panel) stay within the map bounds.

**Layout change:** The outer card becomes a flex row. The map container is `flex-1 relative` (overlays position relative to it). The sidebar is a fixed-width `w-72` sibling on the right. `hidden lg:flex` for desktop only.

```
+-- card (flex row) -----------------------------------------------+
|  +-- map container (flex-1, relative) --+  +-- sidebar (w-72) --+|
|  |  [map SVG]                           |  |  [dropdown]        ||
|  |  [legend: abs bottom-left]           |  |  [bar chart]       ||
|  |  [controls: abs bottom-right]        |  |                    ||
|  +--------------------------------------+  +--------------------+|
+------------------------------------------------------------------+
```

When collapsed, sidebar shrinks to a thin toggle strip (~8px wide with a chevron). Map expands to fill. The ResizeObserver on `mapContainer` naturally triggers a plot rebuild at the new width.

- `bg-base-100/80 backdrop-blur-sm` matching existing overlay style
- `v` keyboard shortcut toggles sidebar

### Legend

`AqiLegend.svelte` becomes dynamic — accepts `bands` and `title` props from parent instead of importing `AQI_BANDS` directly. Parent derives these from `selectedVarConfig`.

### Live mode

Update the live AQ fetch to request all available variables (not just `us_aqi,pm2_5`). The Open-Meteo Air Quality API `current` endpoint supports all the same variables. Change the fetch URL to include: `us_aqi,european_aqi,pm2_5,pm10,dust,aerosol_optical_depth,carbon_monoxide,nitrogen_dioxide,sulphur_dioxide,ozone`. Parse all returned fields into the `metrics` record on `RawDatum`, same as historical mode. Sidebar works identically in both modes.

### Demo mode removal

Remove all demo mode code: the `DEMO` constant, `?demo` URL param check, `demo-data.json` fetch branch, `isDemo` prop on ControlPanel, demo badge UI, and the demo-data.json file from public/.

## File changes

| File | Action |
|------|--------|
| `lib/types.ts` | Add `MetricKey` union type. `RawDatum`: replace `aqi` with `metrics: Record<MetricKey, number\|null>`. Rename `VectorDatum.aqi` → `.metric`, `CityDatum.aqi` → `.metric` |
| `lib/variables.ts` | **NEW** — `VariableConfig`, `VARIABLE_CONFIGS` registry, `SELECTABLE_VARIABLES`, `metricColor()`, `generateBands()` |
| `lib/interpolation.ts` | `val()` reads from `d.metrics[metricKey]`. `interpolateGrid()` accepts `metricKey` param. `computeCityData()` outputs `.metric` |
| `lib/aqi.ts` | No changes — `aqiColor()` and `AQI_BANDS` stay as-is, reused by `metricColor()` |
| `AqiLegend.svelte` | Accept `bands` and `title` props instead of static `AQI_BANDS` import |
| `Sidebar.svelte` | **NEW** — variable dropdown, bar chart container, collapse toggle, bar width animation |
| `App.svelte` | Expand parquet parsing for all metrics. Expand live AQ fetch URL to request all variables. Add `selectedMetric` state. Pass `metricKey` to interpolation. Replace `aqiColor(d.aqi)` → `metricColor(d.metric, ...)` everywhere (buildPlot, setVecEl, snapshotVecs, tooltip). Add Sidebar to template |
| `ControlPanel.svelte` | No changes |

## Implementation order

1. Types + variable config (`types.ts`, `variables.ts`)
2. Interpolation update (`interpolation.ts`)
3. Parquet parsing expansion (`App.svelte`)
4. Wire `selectedMetric` through render pipeline (`App.svelte`)
5. Dynamic legend (`AqiLegend.svelte`)
6. Sidebar component + bar chart (`Sidebar.svelte`)
7. Bar animation (CSS transition hybrid)
8. Polish (keyboard shortcut, null handling)

## Verification

- `npm run dev` in `ui/` — map should render with US AQI as default (unchanged behavior)
- Open sidebar → switch to PM2.5 → vectors recolor, legend updates, bar chart shows PM2.5 values
- Play historical animation → bar widths transition smoothly between dates
- Collapse sidebar → only toggle button visible
- Resize to mobile → sidebar hidden entirely
- Switch to live mode → sidebar works, all variables available via live API fetch
