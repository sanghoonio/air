<script lang="ts">
  import * as Plot from "@observablehq/plot";
  import * as topojson from "topojson-client";
  import world from "world-atlas/countries-110m.json";
  import { parquetReadObjects } from "hyparquet";
  import { untrack } from "svelte";

  import type { GridPoint, VectorDatum, RawDatum, CityDatum, MetricKey } from "./lib/types";
  import { STEP, VIEW, FETCH, buildGrid, padBounds, interpBounds, CITY_COORDS, VISIBLE_CITIES } from "./lib/config";
  import { AQI_BANDS } from "./lib/aqi";
  import { INTERP_DEFAULT, DEG, interpolateGrid, computeCityData } from "./lib/interpolation";
  import { paint } from "./lib/utils";
  import { VARIABLE_CONFIGS, getVariableConfig, metricColor, generateBands } from "./lib/variables";

  import AqiLegend from "./AqiLegend.svelte";
  import InfoModal from "./InfoModal.svelte";
  import LoadingOverlay from "./LoadingOverlay.svelte";
  import ControlPanel from "./ControlPanel.svelte";

  // ── All metric keys we parse from parquet / live API ──────────────────────
  const ALL_METRIC_KEYS: MetricKey[] = [
    "us_aqi", "european_aqi", "pm2_5", "pm10", "dust",
    "aerosol_optical_depth", "carbon_monoxide", "nitrogen_dioxide",
    "sulphur_dioxide", "ozone",
  ];

  // ── State ───────────────────────────────────────────────────────────────────

  let grid = $state<GridPoint[]>([]);
  let vectors = $state<VectorDatum[]>([]);
  let cityData = $state<CityDatum[]>([]);
  let loading = $state(true);
  let loadStatus = $state("");
  let loadPct = $state(0);
  let error = $state<string | null>(null);
  let isRateLimited = $state(false);
  let lastUpdated = $state<Date | null>(null);
  let interp = $state(INTERP_DEFAULT);
  let rawCache = $state<Map<string, RawDatum> | null>(null);
  let liveCache: { raw: Map<string, RawDatum>; vectors: VectorDatum[]; cityData: CityDatum[]; lastUpdated: Date } | null = null;
  let mapContainer = $state<HTMLDivElement>(undefined!);

  // ── Variable selection ──────────────────────────────────────────────────────

  let selectedMetric = $state<MetricKey>("us_aqi");
  let selectedVarConfig = $derived(getVariableConfig(selectedMetric));
  let legendBands = $derived(
    selectedVarConfig.colorType === "aqi" ? AQI_BANDS : generateBands(selectedVarConfig)
  );

  function handleSelectMetric(key: MetricKey) {
    selectedMetric = key;
    // Re-interpolate with the new metric from cached raw data
    if (mode === "historical") {
      renderHistoricalDate();
    } else {
      reinterpolate();
    }
  }

  // ── Historical mode ───────────────────────────────────────────────────────

  let mode = $state<"live" | "historical">("historical");
  let histIndex = $state<Map<string, Map<string, RawDatum>> | null>(null);
  let histDates = $state<string[]>([]);
  let selectedDateIdx = $state(0);
  let selectedDate = $derived(histDates[selectedDateIdx] ?? "");
  let sliderPct = $derived(histDates.length > 1 ? (selectedDateIdx / (histDates.length - 1)) * 100 : 0);
  let isPlaying = $state(false);
  let playInterval = $state<ReturnType<typeof setInterval> | null>(null);
  const SPEEDS = [1600, 800, 400, 200] as const;
  const SPEED_LABELS = ["▶", "▶▶", "▶▶▶", "▶▶▶▶"] as const;
  let speedIdx = $state(1);
  let playSpeed = $derived(SPEEDS[speedIdx]);
  let animEnabled = $state(true);
  let animFrameId = 0;

  async function loadHistory() {
    if (histIndex) {
      renderHistoricalDate();
      return;
    }

    loading = true;
    error = null;
    loadPct = 0;
    loadStatus = "Loading historical data";

    try {
      await paint();
      const res = await fetch(import.meta.env.BASE_URL + "grid-history.parquet");
      if (!res.ok) throw new Error(`Failed to fetch parquet: ${res.status}`);

      loadPct = 30;
      loadStatus = "Reading parquet";
      await paint();

      const buffer = await res.arrayBuffer();

      loadPct = 50;
      loadStatus = "Parsing data";
      await paint();

      const rows = await parquetReadObjects({ file: buffer });

      loadPct = 70;
      loadStatus = "Building index";
      await paint();

      const index = new Map<string, Map<string, RawDatum>>();
      for (const row of rows) {
        const dateStr = String(row.date);
        const lat = Number(row.lat);
        const lon = Number(row.lon);
        const key = `${Math.round(lat * 10) / 10},${Math.round(lon * 10) / 10}`;

        if (!index.has(dateStr)) index.set(dateStr, new Map());

        const speed = Number(row.wind_speed) || 0;
        const dir = Number(row.wind_direction) || 0;
        const rad = dir * DEG;

        const metrics: Partial<Record<MetricKey, number | null>> = {};
        for (const mk of ALL_METRIC_KEYS) {
          metrics[mk] = row[mk] != null ? Number(row[mk]) : null;
        }

        index.get(dateStr)!.set(key, {
          u: -speed * Math.sin(rad),
          v: -speed * Math.cos(rad),
          metrics,
        });
      }

      histIndex = index;
      histDates = [...index.keys()].sort();
      selectedDateIdx = 0;

      loadPct = 90;
      loadStatus = "Interpolating";
      await paint();

      renderHistoricalDate();
      loadPct = 100;
    } catch (e) {
      const msg = e instanceof Error ? e.message : "Unknown error";
      error = msg;
    } finally {
      loading = false;
    }
  }

  function renderHistoricalDate() {
    if (!histIndex) return;
    const date = histDates[selectedDateIdx];
    if (!date) return;
    const dayRaw = histIndex.get(date);
    if (!dayRaw) return;
    rawCache = dayRaw;
    vectors = interpolateGrid(dayRaw, interpArea, interp, selectedMetric);
    cityData = computeCityData(VISIBLE_CITIES, vectors, interpArea, STEP / interp);
  }

  function switchMode(newMode: "live" | "historical") {
    if (newMode === mode) return;
    if (isPlaying) togglePlay();

    // Save live state before leaving
    if (mode === "live" && rawCache && lastUpdated) {
      liveCache = { raw: rawCache, vectors, cityData, lastUpdated };
    }

    error = null;
    mode = newMode;
    if (mode === "live") {
      if (liveCache) {
        rawCache = liveCache.raw;
        vectors = liveCache.vectors;
        cityData = liveCache.cityData;
        lastUpdated = liveCache.lastUpdated;
      } else {
        vectors = [];
        rawCache = null;
        lastUpdated = null;
      }
    } else {
      if (histIndex) {
        renderHistoricalDate();
      } else {
        loadHistory();
      }
    }
  }

  function startPlayback() {
    if (playInterval) clearInterval(playInterval);
    playInterval = setInterval(() => {
      selectedDateIdx = (selectedDateIdx + 1) % histDates.length;
      renderHistoricalDate();
    }, playSpeed);
  }

  function togglePlay() {
    if (isPlaying) {
      if (playInterval) clearInterval(playInterval);
      playInterval = null;
      isPlaying = false;
    } else {
      isPlaying = true;
      startPlayback();
    }
  }

  function handleKeydown(e: KeyboardEvent) {
    const tag = (e.target as HTMLElement)?.tagName;
    if (tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT") return;

    if (mode !== "historical") return;
    if (e.code === "Space") {
      e.preventDefault();
      togglePlay();
    } else if (e.code === "ArrowLeft") {
      e.preventDefault();
      selectedDateIdx = Math.max(0, selectedDateIdx - 1);
      renderHistoricalDate();
    } else if (e.code === "ArrowRight") {
      e.preventDefault();
      selectedDateIdx = Math.min(histDates.length - 1, selectedDateIdx + 1);
      renderHistoricalDate();
    } else if (e.code === "ArrowUp") {
      e.preventDefault();
      speedIdx = Math.min(SPEEDS.length - 1, speedIdx + 1);
      if (isPlaying) startPlayback();
    } else if (e.code === "ArrowDown") {
      e.preventDefault();
      speedIdx = Math.max(0, speedIdx - 1);
      if (isPlaying) startPlayback();
    } else if (e.key === "a") {
      e.preventDefault();
      animEnabled = !animEnabled;
    }
  }

  function cycleSpeed() {
    speedIdx = (speedIdx + 1) % SPEEDS.length;
    if (isPlaying) startPlayback();
  }

  // ── Fetch data ──────────────────────────────────────────────────────────────

  async function fetchData() {
    if (!mapContainer) return;
    grid = buildGrid(padBounds(interpArea));

    loading = true;
    error = null;
    loadPct = 0;
    loadStatus = `Fetching wind for ${grid.length} points`;

    try {
      const lats = grid.map((p) => p.lat).join(",");
      const lons = grid.map((p) => p.lon).join(",");

      const wFetch = fetch(
        `https://api.open-meteo.com/v1/forecast?latitude=${lats}&longitude=${lons}&current=wind_speed_10m,wind_direction_10m&wind_speed_unit=ms`
      );
      const aqVars = ALL_METRIC_KEYS.join(",");
      const aFetch = fetch(
        `https://air-quality-api.open-meteo.com/v1/air-quality?latitude=${lats}&longitude=${lons}&current=${aqVars}&domains=cams_global`
      );

      const wRes = await wFetch;
      if (!wRes.ok) throw new Error(`Weather API: ${wRes.status}`);
      loadPct = 30;
      loadStatus = "Fetching AQI data";
      await paint();

      const aRes = await aFetch;
      if (!aRes.ok) throw new Error(`AQ API: ${aRes.status}`);
      loadPct = 55;
      loadStatus = "Parsing responses";
      await paint();

      const wJson = await wRes.json();
      const aJson = await aRes.json();
      const allWeather: any[] = Array.isArray(wJson) ? wJson : [wJson];
      const allAq: any[] = Array.isArray(aJson) ? aJson : [aJson];

      loadPct = 75;
      const interpCount = grid.length * interp * interp;
      loadStatus = `Interpolating ×${interp} → ${interpCount.toLocaleString()} vectors`;
      await paint();

      const raw = new Map<string, RawDatum>();
      for (let i = 0; i < grid.length; i++) {
        const pt = grid[i];
        const w = allWeather[i]?.current;
        const a = allAq[i]?.current;
        const speed: number = w?.wind_speed_10m ?? 0;
        const dir: number = w?.wind_direction_10m ?? 0;
        const rad = dir * DEG;

        const metrics: Partial<Record<MetricKey, number | null>> = {};
        for (const mk of ALL_METRIC_KEYS) {
          metrics[mk] = a?.[mk] ?? null;
        }

        raw.set(`${pt.lat},${pt.lon}`, {
          u: -speed * Math.sin(rad),
          v: -speed * Math.cos(rad),
          metrics,
        });
      }

      rawCache = raw;
      vectors = interpolateGrid(raw, interpArea, interp, selectedMetric);
      const fineStep = STEP / interp;
      cityData = computeCityData(VISIBLE_CITIES, vectors, interpArea, fineStep);
      loadPct = 100;
      loadStatus = "Rendering";

      lastUpdated = new Date();
    } catch (e) {
      const msg = e instanceof Error ? e.message : "Unknown error";
      error = msg;
      isRateLimited = msg.includes("429");
    } finally {
      loading = false;
    }
  }

  /** Re-interpolate from cached raw data (no API call) */
  function reinterpolate() {
    if (!rawCache) return;
    vectors = interpolateGrid(rawCache, interpArea, interp, selectedMetric);
    const fineStep = STEP / interp;
    cityData = computeCityData(VISIBLE_CITIES, vectors, interpArea, fineStep);
  }

  // ── Render map ──────────────────────────────────────────────────────────────

  const countries = topojson.feature(world, world.objects.countries);

  let containerWidth = $state(0);
  let containerHeight = $state(0);
  let interpArea = $derived(interpBounds(containerWidth || 800, containerHeight || 600));

  $effect(() => {
    if (!mapContainer) return;
    const ro = new ResizeObserver((entries) => {
      const { width, height } = entries[0].contentRect;
      containerWidth = Math.round(width);
      containerHeight = Math.round(height);
    });
    ro.observe(mapContainer);
    return () => ro.disconnect();
  });

  let lastPlotWidth = 0;
  let lastPlotHeight = 0;
  let lastPlotInterp = 0;
  let lastPlotMetric: MetricKey | null = null;

  function buildPlot(width: number, height: number) {
    const b = VIEW;
    const cfg = selectedVarConfig;
    return Plot.plot({
      width,
      height,
      length: { type: "identity" },
      projection: {
        type: "mercator",
        domain: {
          type: "MultiPoint",
          coordinates: [
            [b.lonMin, b.latMin],
            [b.lonMax, b.latMax],
          ],
        },
        inset: 0,
      },
      style: {
        background: "#1d232a",
        color: "#a6adbb",
      },
      marks: [
        Plot.frame({ fill: "#20262d" }),

        Plot.geo(countries, {
          fill: "#2a323c",
          stroke: "#3d4451",
          strokeWidth: 0.5,
        }),

        Plot.dot(cityData, {
          x: "lon",
          y: "lat",
          r: 2,
          fill: "#e5e7eb",
          fillOpacity: 0.37,
        }),

        Plot.vector(vectors, {
          x: "lon",
          y: "lat",
          rotate: (d: VectorDatum) => (d.windDirection + 180) % 360,
          length: (d: VectorDatum) => 2 * d.windSpeed,
          stroke: (d: VectorDatum) => metricColor(d.metric, cfg),
          strokeOpacity: 0.37,
          strokeWidth: window.innerWidth < 640 ? 1.5 : 2,
          anchor: "middle",
        }),

        Plot.tip(cityData, Plot.pointer({
          x: "lon",
          y: "lat",
          fill: "#2a323c",
          stroke: "#3d4451",
          channels: {
            "": { value: (d: CityDatum) => d.name, label: null },
            [`${selectedVarConfig.label}:`]: { value: (d: CityDatum) => d.metric != null ? Math.round(d.metric) : "N/A" },
            "Wind:": {
              value: (d: CityDatum) => {
                const compass = ["N","NNE","NE","ENE","E","ESE","SE","SSE","S","SSW","SW","WSW","W","WNW","NW","NNW"][Math.round(d.windDir / 22.5) % 16];
                return `${d.windSpeed} m/s ${compass}`;
              },
            },
          },
          format: { x: false, y: false },
        })),
      ],
    });
  }

  // ── Direct vector update (skips Plot.plot() rebuild per frame) ──────────

  function parseRGB(s: string | null): [number, number, number] {
    if (!s) return [107, 114, 128];
    const m = s.match(/(\d+),\s*(\d+),\s*(\d+)/);
    return m ? [+m[1], +m[2], +m[3]] : [107, 114, 128];
  }

  function lerpAngle(a: number, b: number, t: number): number {
    const d = ((b - a + 540) % 360) - 180;
    return a + d * t;
  }

  let cachedPx: Float64Array | null = null;
  let cachedPy: Float64Array | null = null;
  let vecEls: Element[] | null = null;
  let cachedIdx: Uint16Array | null = null;

  let prevA: Float64Array | null = null;
  let prevL: Float64Array | null = null;
  let prevR: Uint8Array | null = null;
  let prevG: Uint8Array | null = null;
  let prevB: Uint8Array | null = null;

  const R3 = (v: number) => Math.round(v * 1000) / 1000;

  function setVecEl(el: Element, d: VectorDatum, px: number, py: number) {
    const angle = (d.windDirection + 180) % 360;
    const len = d.windSpeed < 0.1 ? 0 : 2 * d.windSpeed;
    const hl = len / 2, w = len / 5;
    el.setAttribute("transform",
      `translate(${R3(px)},${R3(py)}) rotate(${R3(angle)}) translate(0,${R3(hl)})`);
    el.setAttribute("d",
      `M0,0L0,${R3(-len)}M${R3(-w)},${R3(w - len)}L0,${R3(-len)}L${R3(w)},${R3(w - len)}`);
    el.setAttribute("stroke", metricColor(d.metric, selectedVarConfig));
  }

  function applyVecFrame(vecs: VectorDatum[]) {
    if (!vecEls || !cachedPx || !cachedPy || !cachedIdx) return;
    for (let i = 0; i < vecEls.length; i++) {
      setVecEl(vecEls[i], vecs[cachedIdx[i]], cachedPx[i], cachedPy[i]);
    }
  }

  function snapshotVecs(vecs: VectorDatum[]) {
    const cfg = selectedVarConfig;
    const idx = cachedIdx!;
    const n = idx.length;
    const a = new Float64Array(n), l = new Float64Array(n);
    const r = new Uint8Array(n), g = new Uint8Array(n), b = new Uint8Array(n);
    for (let i = 0; i < n; i++) {
      const d = vecs[idx[i]];
      a[i] = (d.windDirection + 180) % 360;
      l[i] = d.windSpeed < 0.1 ? 0 : 2 * d.windSpeed;
      const c = parseRGB(metricColor(d.metric, cfg));
      r[i] = c[0]; g[i] = c[1]; b[i] = c[2];
    }
    return { a, l, r, g, b };
  }

  function animateVecTransition(
    fA: Float64Array, fL: Float64Array, fR: Uint8Array, fG: Uint8Array, fB: Uint8Array,
    tA: Float64Array, tL: Float64Array, tR: Uint8Array, tG: Uint8Array, tB: Uint8Array,
    duration: number,
  ) {
    if (animFrameId) cancelAnimationFrame(animFrameId);
    if (!vecEls || !cachedPx || !cachedPy) return;
    const n = vecEls.length;
    const els = vecEls, px = cachedPx, py = cachedPy;
    const start = performance.now();

    function tick(now: number) {
      const raw = Math.min(1, (now - start) / duration);
      const t = raw < 0.5 ? 2 * raw * raw : 1 - Math.pow(-2 * raw + 2, 2) / 2;

      for (let i = 0; i < n; i++) {
        const angle = lerpAngle(fA[i], tA[i], t);
        const len = fL[i] + (tL[i] - fL[i]) * t;
        const hl = len / 2, w = len / 5;
        const r = Math.round(fR[i] + (tR[i] - fR[i]) * t);
        const g = Math.round(fG[i] + (tG[i] - fG[i]) * t);
        const b = Math.round(fB[i] + (tB[i] - fB[i]) * t);

        els[i].setAttribute("transform",
          `translate(${R3(px[i])},${R3(py[i])}) rotate(${R3(angle)}) translate(0,${R3(hl)})`);
        els[i].setAttribute("d",
          `M0,0L0,${R3(-len)}M${R3(-w)},${R3(w - len)}L0,${R3(-len)}L${R3(w)},${R3(w - len)}`);
        els[i].setAttribute("stroke", `rgb(${r},${g},${b})`);
      }

      if (raw < 1) {
        animFrameId = requestAnimationFrame(tick);
      } else {
        animFrameId = 0;
      }
    }

    animFrameId = requestAnimationFrame(tick);
  }

  function cacheVecElements() {
    const els = [...mapContainer.querySelectorAll('g[aria-label="vector"] path')];
    vecEls = els;
    const n = els.length;
    cachedPx = new Float64Array(n);
    cachedPy = new Float64Array(n);
    cachedIdx = new Uint16Array(n);
    for (let i = 0; i < n; i++) {
      const tr = els[i].getAttribute("transform") || "";
      const m = tr.match(/translate\(([^,]+),([^)]+)\)/);
      if (m) { cachedPx[i] = +m[1]; cachedPy[i] = +m[2]; }
      cachedIdx[i] = (els[i] as any).__data__ ?? i;
    }
  }

  $effect(() => {
    if (!mapContainer || vectors.length === 0) return;

    const width = containerWidth;
    const height = containerHeight;
    if (height < 10) return;

    const interpNow = interp;
    const metricNow = selectedMetric;
    const needsRebuild = width !== lastPlotWidth || height !== lastPlotHeight
      || interpNow !== lastPlotInterp || metricNow !== lastPlotMetric;

    if (!needsRebuild && vecEls && vecEls.length > 0 && cachedPx && cachedIdx) {
      if (animFrameId) { cancelAnimationFrame(animFrameId); animFrameId = 0; }

      const snap = snapshotVecs(vectors);

      if (mode === "historical" && animEnabled && prevA && prevA.length === snap.a.length) {
        const dur = untrack(() => isPlaying ? playSpeed : 400);
        animateVecTransition(prevA, prevL!, prevR!, prevG!, prevB!,
                             snap.a, snap.l, snap.r, snap.g, snap.b, dur);
      } else {
        applyVecFrame(vectors);
      }
      prevA = snap.a; prevL = snap.l; prevR = snap.r; prevG = snap.g; prevB = snap.b;
      return;
    }

    if (animFrameId) { cancelAnimationFrame(animFrameId); animFrameId = 0; }
    // Re-interpolate for the new viewport size
    if (rawCache && (width !== lastPlotWidth || height !== lastPlotHeight)) {
      const bounds = interpArea;
      vectors = interpolateGrid(rawCache, bounds, interpNow, metricNow);
      cityData = computeCityData(VISIBLE_CITIES, vectors, bounds, STEP / interpNow);
    }
    const plot = buildPlot(width, height);
    lastPlotWidth = width;
    lastPlotHeight = height;
    lastPlotInterp = interpNow;
    lastPlotMetric = metricNow;
    mapContainer.replaceChildren(plot);
    cacheVecElements();
    const snap = snapshotVecs(vectors);
    prevA = snap.a; prevL = snap.l; prevR = snap.r; prevG = snap.g; prevB = snap.b;
  });

  // ── Init ──────────────────────────────────────────────────────────────────

  let fetched = false;
  $effect(() => {
    if (mapContainer && !fetched) {
      fetched = true;
      if (mode === "historical") loadHistory();
      else fetchData();
    }
  });

  // ── Component callbacks ────────────────────────────────────────────────────

  function handleSliderChange(idx: number) {
    selectedDateIdx = idx;
    renderHistoricalDate();
  }

  function handleInterpChange(val: number) {
    interp = val;
    if (mode === "historical") renderHistoricalDate();
    else reinterpolate();
  }

  function handleSwitchToHistorical() {
    error = null;
    switchMode("historical");
  }

  function showInfo() {
    (document.getElementById('info-modal') as HTMLDialogElement)?.showModal();
  }
</script>

<svelte:window onkeydown={handleKeydown} />
<div class="h-screen overflow-hidden bg-base-200 p-2">
  <div class="card bg-base-100 shadow-sm border border-base-300 overflow-hidden h-full relative">
    <div bind:this={mapContainer} class="w-full h-full"></div>

    <LoadingOverlay
      {loading}
      hasVectors={vectors.length > 0}
      {error}
      {mode}
      {loadPct}
      {loadStatus}
      onFetchData={fetchData}
      onSwitchToHistorical={handleSwitchToHistorical}
    />

    <AqiLegend bands={legendBands} {selectedMetric} onSelectMetric={handleSelectMetric} />

    <ControlPanel
      {mode}
      {isPlaying}
      {histDates}
      {selectedDateIdx}
      {selectedDate}
      {sliderPct}
      {speedIdx}
      {interp}
      {animEnabled}
      {loading}
      {lastUpdated}
      speedLabels={SPEED_LABELS}
      onTogglePlay={togglePlay}
      onSliderChange={handleSliderChange}
      onCycleSpeed={cycleSpeed}
      onInterpChange={handleInterpChange}
      onToggleAnim={() => animEnabled = !animEnabled}
      onSwitchMode={switchMode}
      onFetchData={fetchData}
      onShowInfo={showInfo}
    />
  </div>
</div>

<InfoModal />
