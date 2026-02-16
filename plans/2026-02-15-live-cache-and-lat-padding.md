---
date: 2026-02-15
status: complete
description: Persist live data across mode switches and expand FETCH lat padding
---

# Fix 1: Persist live data across mode switches

**Problem**: `switchMode("live")` cleared `vectors`, `rawCache`, `lastUpdated`. Switching live→historical→live discarded fetched data and showed the "Query Live Data" button again.

**Fix**: Added a `liveCache` variable that saves live state (raw, vectors, cityData, lastUpdated) before switching away from live mode, and restores it when returning.

### Files modified
- `ui/src/App.svelte` — added `liveCache`, updated `switchMode` to save/restore

# Fix 2: Expand FETCH lat padding to match lon padding

**Problem**: On portrait phones, vectors stopped short vertically because lat padding was only ±4×STEP (±8°) vs lon padding ±8×STEP (±16°).

**Fix**: Changed `FETCH` lat padding from `4 * STEP` to `8 * STEP` in config.ts. FETCH lat now covers 10–66 instead of 18–58. VIEW and projection domain unchanged.

Note: historical parquet data will need re-collection for the wider grid.

### Files modified
- `ui/src/lib/config.ts` — FETCH latMin/latMax padding

## Implementation log

- Both changes applied, `npm run build` passes cleanly.
