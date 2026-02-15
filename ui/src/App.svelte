<script lang="ts">
  import * as Plot from "@observablehq/plot";
  import * as topojson from "topojson-client";
  import world from "world-atlas/countries-110m.json";
  import { RefreshCw } from "lucide-svelte";

  // ── Grid config ─────────────────────────────────────────────────────────────

  const CENTER_LON = 125;
  const CENTER_LAT = 38;
  const MIN_LON_SPAN = 42;
  const MIN_LAT_SPAN = 22;
  const STEP = 2;

  interface GridPoint {
    lat: number;
    lon: number;
  }

  interface Bounds {
    lonMin: number;
    lonMax: number;
    latMin: number;
    latMax: number;
  }

  const snapDown = (v: number) => Math.floor(v / STEP) * STEP;
  const snapUp = (v: number) => Math.ceil(v / STEP) * STEP;

  // Fixed projection domain
  const VIEW: Bounds = {
    lonMin: snapDown(CENTER_LON - MIN_LON_SPAN / 2),
    lonMax: snapUp(CENTER_LON + MIN_LON_SPAN / 2),
    latMin: snapDown(CENTER_LAT - MIN_LAT_SPAN / 2),
    latMax: snapUp(CENTER_LAT + MIN_LAT_SPAN / 2),
  };

  // Fetch grid: generously wider so vectors fill the map edge-to-edge
  // (Plot may show slightly beyond VIEW due to aspect ratio fitting)
  const FETCH: Bounds = {
    lonMin: VIEW.lonMin - 8 * STEP,
    lonMax: VIEW.lonMax + 8 * STEP,
    latMin: VIEW.latMin - 4 * STEP,
    latMax: VIEW.latMax + 4 * STEP,
  };

  function buildGrid(b: Bounds): GridPoint[] {
    const pts: GridPoint[] = [];
    for (let lat = b.latMin; lat <= b.latMax + 0.01; lat += STEP) {
      for (let lon = b.lonMin; lon <= b.lonMax + 0.01; lon += STEP) {
        pts.push({ lat: Math.round(lat * 10) / 10, lon: Math.round(lon * 10) / 10 });
      }
    }
    return pts;
  }

  // ── City labels (reference only) ───────────────────────────────────────────

  interface CityDatum {
    name: string;
    lat: number;
    lon: number;
    aqi: number | null;
    windSpeed: number;
    windDir: number;
  }

  const CITY_COORDS = [
    // China — NE & North
    { name: "Harbin", lat: 45.75, lon: 126.65 },
    { name: "Changchun", lat: 43.88, lon: 125.32 },
    { name: "Shenyang", lat: 41.80, lon: 123.40 },
    { name: "Dalian", lat: 38.91, lon: 121.60 },
    { name: "Beijing", lat: 39.91, lon: 116.40 },
    { name: "Tianjin", lat: 39.09, lon: 117.20 },
    { name: "Hohhot", lat: 40.85, lon: 111.73 },
    { name: "Ordos", lat: 39.63, lon: 109.97 },
    { name: "Baotou", lat: 40.66, lon: 109.84 },
    { name: "Qiqihar", lat: 47.35, lon: 123.92 },
    { name: "Daqing", lat: 46.60, lon: 125.02 },
    { name: "Mudanjiang", lat: 44.58, lon: 129.60 },
    { name: "Jilin", lat: 43.84, lon: 126.56 },
    { name: "Yanji", lat: 42.89, lon: 129.51 },
    { name: "Dandong", lat: 40.00, lon: 124.35 },
    { name: "Fushun", lat: 41.87, lon: 123.96 },
    { name: "Anshan", lat: 41.12, lon: 122.99 },
    // China — Central & East
    { name: "Shijiazhuang", lat: 38.04, lon: 114.50 },
    { name: "Taiyuan", lat: 37.87, lon: 112.55 },
    { name: "Jinan", lat: 36.67, lon: 116.98 },
    { name: "Qingdao", lat: 36.06, lon: 120.38 },
    { name: "Zhengzhou", lat: 34.75, lon: 113.65 },
    { name: "Xi'an", lat: 34.26, lon: 108.94 },
    { name: "Zhangjiakou", lat: 40.82, lon: 114.88 },
    { name: "Erenhot", lat: 43.65, lon: 111.98 },
    { name: "Yinchuan", lat: 38.47, lon: 106.27 },
    { name: "Lanzhou", lat: 36.06, lon: 103.83 },
    { name: "Xining", lat: 36.62, lon: 101.77 },
    { name: "Kashgar", lat: 39.47, lon: 75.99 },
    { name: "Korla", lat: 41.76, lon: 86.15 },
    { name: "Hami", lat: 42.83, lon: 93.51 },
    { name: "Jiayuguan", lat: 39.77, lon: 98.29 },
    { name: "Dunhuang", lat: 40.14, lon: 94.66 },
    { name: "Zhongwei", lat: 37.51, lon: 105.19 },
    { name: "Golmud", lat: 36.42, lon: 94.90 },
    { name: "Karamay", lat: 45.58, lon: 84.87 },
    { name: "Nanjing", lat: 32.06, lon: 118.80 },
    { name: "Shanghai", lat: 31.23, lon: 121.47 },
    { name: "Wuhan", lat: 30.59, lon: 114.31 },
    { name: "Hangzhou", lat: 30.27, lon: 120.15 },
    { name: "Xuzhou", lat: 34.26, lon: 117.18 },
    { name: "Yantai", lat: 37.46, lon: 121.45 },
    { name: "Tangshan", lat: 39.63, lon: 118.18 },
    { name: "Chengdu", lat: 30.57, lon: 104.07 },
    { name: "Chongqing", lat: 29.56, lon: 106.55 },
    { name: "Changsha", lat: 28.23, lon: 112.94 },
    { name: "Nanchang", lat: 28.68, lon: 115.86 },
    { name: "Hefei", lat: 31.82, lon: 117.23 },
    { name: "Fuzhou", lat: 26.07, lon: 119.30 },
    { name: "Xiamen", lat: 24.48, lon: 118.09 },
    { name: "Guiyang", lat: 26.65, lon: 106.63 },
    { name: "Kunming", lat: 25.04, lon: 102.68 },
    { name: "Nanning", lat: 22.82, lon: 108.32 },
    { name: "Guangzhou", lat: 23.13, lon: 113.26 },
    { name: "Shenzhen", lat: 22.54, lon: 114.06 },
    { name: "Dongguan", lat: 23.04, lon: 113.75 },
    { name: "Wenzhou", lat: 28.00, lon: 120.67 },
    { name: "Luoyang", lat: 34.62, lon: 112.45 },
    { name: "Kaifeng", lat: 34.80, lon: 114.31 },
    { name: "Handan", lat: 36.60, lon: 114.49 },
    { name: "Linyi", lat: 35.10, lon: 118.35 },
    { name: "Suzhou", lat: 31.30, lon: 120.62 },
    { name: "Wuxi", lat: 31.57, lon: 120.30 },
    { name: "Ningbo", lat: 29.87, lon: 121.55 },
    { name: "Urumqi", lat: 43.80, lon: 87.60 },
    // Korea
    { name: "Pyongyang", lat: 39.02, lon: 125.75 },
    { name: "Seoul", lat: 37.57, lon: 126.98 },
    { name: "Incheon", lat: 37.46, lon: 126.70 },
    { name: "Busan", lat: 35.18, lon: 129.08 },
    { name: "Daegu", lat: 35.87, lon: 128.60 },
    { name: "Daejeon", lat: 36.35, lon: 127.38 },
    { name: "Gwangju", lat: 35.16, lon: 126.85 },
    { name: "Chuncheon", lat: 37.90, lon: 127.73 },
    { name: "Jeju", lat: 33.35, lon: 126.53 },
    { name: "Ulsan", lat: 35.54, lon: 129.31 },
    { name: "Suwon", lat: 37.26, lon: 127.03 },
    { name: "Hamhung", lat: 39.92, lon: 127.54 },
    { name: "Wonsan", lat: 39.15, lon: 127.44 },
    // Japan
    { name: "Fukuoka", lat: 33.59, lon: 130.40 },
    { name: "Osaka", lat: 34.69, lon: 135.50 },
    { name: "Nagoya", lat: 35.18, lon: 136.91 },
    { name: "Tokyo", lat: 35.68, lon: 139.69 },
    { name: "Sendai", lat: 38.27, lon: 140.87 },
    { name: "Sapporo", lat: 43.06, lon: 141.35 },
    { name: "Hiroshima", lat: 34.39, lon: 132.46 },
    { name: "Kyoto", lat: 35.01, lon: 135.77 },
    { name: "Toyama", lat: 36.70, lon: 137.21 },
    { name: "Niigata", lat: 37.90, lon: 139.02 },
    { name: "Akita", lat: 39.72, lon: 140.10 },
    { name: "Hakodate", lat: 41.77, lon: 140.73 },
    { name: "Asahikawa", lat: 43.77, lon: 142.37 },
    { name: "Nagasaki", lat: 32.75, lon: 129.87 },
    { name: "Kagoshima", lat: 31.60, lon: 130.56 },
    { name: "Kobe", lat: 34.69, lon: 135.18 },
    { name: "Yokohama", lat: 35.44, lon: 139.64 },
    { name: "Kanazawa", lat: 36.56, lon: 136.65 },
    { name: "Aomori", lat: 40.82, lon: 140.74 },
    { name: "Kushiro", lat: 42.98, lon: 144.38 },
    { name: "Kitakyushu", lat: 33.88, lon: 130.88 },
    { name: "Kumamoto", lat: 32.79, lon: 130.74 },
    { name: "Matsuyama", lat: 33.84, lon: 132.77 },
    { name: "Okayama", lat: 34.66, lon: 133.92 },
    { name: "Shizuoka", lat: 34.98, lon: 138.38 },
    // Russia / Mongolia
    { name: "Vladivostok", lat: 43.12, lon: 131.87 },
    { name: "Ulaanbaatar", lat: 47.91, lon: 106.91 },
    { name: "Khabarovsk", lat: 48.48, lon: 135.07 },
    { name: "Ussuriysk", lat: 43.80, lon: 131.95 },
    { name: "Yuzhno-Sakhalinsk", lat: 46.96, lon: 142.74 },
    { name: "Blagoveshchensk", lat: 50.27, lon: 127.54 },
    { name: "Darkhan", lat: 49.46, lon: 106.01 },
    { name: "Choibalsan", lat: 48.07, lon: 114.54 },
    // Taiwan
    { name: "Taipei", lat: 25.03, lon: 121.57 },
  ];

  // Only keep cities within the visible map area (± 1° margin)
  const VISIBLE_CITIES = CITY_COORDS.filter(
    (c) =>
      c.lat >= VIEW.latMin - 1 &&
      c.lat <= VIEW.latMax + 1 &&
      c.lon >= VIEW.lonMin - 1 &&
      c.lon <= VIEW.lonMax + 1
  );

  // ── AQI color scale ─────────────────────────────────────────────────────────

  interface AqiBand {
    min: number;
    max: number;
    color: string;
    label: string;
  }

  const AQI_BANDS: AqiBand[] = [
    { min: 0, max: 50, color: "#22c55e", label: "Good" },
    { min: 51, max: 100, color: "#eab308", label: "Moderate" },
    { min: 101, max: 150, color: "#f97316", label: "USG" },
    { min: 151, max: 200, color: "#ef4444", label: "Unhealthy" },
    { min: 201, max: 300, color: "#a855f7", label: "Very Unhealthy" },
    { min: 301, max: 500, color: "#991b1b", label: "Hazardous" },
  ];

  // Continuous AQI color scale — linear interpolation between band colors
  const AQI_STOPS = [
    { val: 0, r: 0x22, g: 0xc5, b: 0x5e },   // green
    { val: 50, r: 0x22, g: 0xc5, b: 0x5e },
    { val: 75, r: 0xea, g: 0xb3, b: 0x08 },   // yellow
    { val: 100, r: 0xea, g: 0xb3, b: 0x08 },
    { val: 125, r: 0xf9, g: 0x73, b: 0x16 },  // orange
    { val: 150, r: 0xf9, g: 0x73, b: 0x16 },
    { val: 175, r: 0xef, g: 0x44, b: 0x44 },  // red
    { val: 200, r: 0xef, g: 0x44, b: 0x44 },
    { val: 250, r: 0xa8, g: 0x55, b: 0xf7 },  // purple
    { val: 300, r: 0xa8, g: 0x55, b: 0xf7 },
    { val: 400, r: 0x99, g: 0x1b, b: 0x1b },  // maroon
    { val: 500, r: 0x99, g: 0x1b, b: 0x1b },
  ];

  function aqiColor(aqi: number | null): string {
    if (aqi == null) return "#6b7280";
    const v = Math.max(0, Math.min(500, aqi));
    let i = 0;
    while (i < AQI_STOPS.length - 1 && AQI_STOPS[i + 1].val < v) i++;
    if (i >= AQI_STOPS.length - 1) {
      const s = AQI_STOPS[AQI_STOPS.length - 1];
      return `rgb(${s.r},${s.g},${s.b})`;
    }
    const a = AQI_STOPS[i], b = AQI_STOPS[i + 1];
    const t = b.val === a.val ? 0 : (v - a.val) / (b.val - a.val);
    const r = Math.round(a.r + (b.r - a.r) * t);
    const g = Math.round(a.g + (b.g - a.g) * t);
    const bl = Math.round(a.b + (b.b - a.b) * t);
    return `rgb(${r},${g},${bl})`;
  }

  // ── Data types ──────────────────────────────────────────────────────────────

  interface VectorDatum {
    lat: number;
    lon: number;
    windSpeed: number;
    windDirection: number;
    aqi: number | null;
  }

  // Raw fetched data keyed by "lat,lon"
  interface RawDatum {
    u: number; // wind x-component (m/s)
    v: number; // wind y-component (m/s)
    aqi: number | null;
  }

  // ── Bicubic (Catmull-Rom) interpolation ─────────────────────────────────────

  const INTERP_DEFAULT = 5;
  const DEG = Math.PI / 180;

  const r1 = (v: number) => Math.round(v * 10) / 10;

  /** Catmull-Rom cubic: interpolate between p1 and p2, t ∈ [0,1] */
  function cubic(p0: number, p1: number, p2: number, p3: number, t: number) {
    return 0.5 * (
      2 * p1 +
      (-p0 + p2) * t +
      (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t +
      (-p0 + 3 * p1 - 3 * p2 + p3) * t * t * t
    );
  }

  /** Look up a field value from the raw grid, returning 0 if missing */
  function val(
    raw: Map<string, RawDatum>,
    lat: number,
    lon: number,
    field: "u" | "v" | "aqi"
  ): number {
    const d = raw.get(`${r1(lat)},${r1(lon)}`);
    if (!d) return 0;
    return (d[field] as number) ?? 0;
  }

  function interpolateGrid(
    raw: Map<string, RawDatum>,
    area: Bounds,
    interp: number
  ): VectorDatum[] {
    const fineStep = STEP / interp;
    const out: VectorDatum[] = [];

    // Only emit points within FETCH minus 1 STEP margin (need neighbors on all sides)
    const minLat = area.latMin + STEP;
    const maxLat = area.latMax - STEP;
    const minLon = area.lonMin + STEP;
    const maxLon = area.lonMax - STEP;

    for (let lat = minLat; lat <= maxLat + 0.01; lat += fineStep) {
      for (let lon = minLon; lon <= maxLon + 0.01; lon += fineStep) {
        // The 4 lat rows and 4 lon cols surrounding this point
        const latBase = snapDown(lat);
        const lonBase = snapDown(lon);
        const fy = (lat - latBase) / STEP;
        const fx = (lon - lonBase) / STEP;

        const latRows = [latBase - STEP, latBase, latBase + STEP, latBase + 2 * STEP];
        const lonCols = [lonBase - STEP, lonBase, lonBase + STEP, lonBase + 2 * STEP];

        // Bicubic: interpolate 4 rows along lon, then interpolate those results along lat
        let u = 0, v = 0, aqi = 0;
        const rowU: number[] = [];
        const rowV: number[] = [];
        const rowA: number[] = [];

        for (const rLat of latRows) {
          rowU.push(cubic(
            val(raw, rLat, lonCols[0], "u"), val(raw, rLat, lonCols[1], "u"),
            val(raw, rLat, lonCols[2], "u"), val(raw, rLat, lonCols[3], "u"), fx
          ));
          rowV.push(cubic(
            val(raw, rLat, lonCols[0], "v"), val(raw, rLat, lonCols[1], "v"),
            val(raw, rLat, lonCols[2], "v"), val(raw, rLat, lonCols[3], "v"), fx
          ));
          rowA.push(cubic(
            val(raw, rLat, lonCols[0], "aqi"), val(raw, rLat, lonCols[1], "aqi"),
            val(raw, rLat, lonCols[2], "aqi"), val(raw, rLat, lonCols[3], "aqi"), fx
          ));
        }

        u = cubic(rowU[0], rowU[1], rowU[2], rowU[3], fy);
        v = cubic(rowV[0], rowV[1], rowV[2], rowV[3], fy);
        aqi = cubic(rowA[0], rowA[1], rowA[2], rowA[3], fy);

        const speed = Math.sqrt(u * u + v * v);
        const dir = ((Math.atan2(-u, -v) / DEG) + 360) % 360;

        out.push({
          lat: r1(lat),
          lon: r1(lon),
          windSpeed: speed,
          windDirection: dir,
          aqi: Math.max(0, aqi),
        });
      }
    }
    return out;
  }

  /** Find the nearest interpolated vector via grid lookup (O(1) per city) */
  function computeCityData(
    cities: typeof CITY_COORDS,
    vecs: VectorDatum[],
    fineStep: number
  ): CityDatum[] {
    const lookup = new Map<string, VectorDatum>();
    for (const v of vecs) lookup.set(`${v.lat},${v.lon}`, v);

    const gridLatStart = FETCH.latMin + STEP;
    const gridLonStart = FETCH.lonMin + STEP;

    return cities.map((c) => {
      const nearLat = r1(gridLatStart + Math.round((c.lat - gridLatStart) / fineStep) * fineStep);
      const nearLon = r1(gridLonStart + Math.round((c.lon - gridLonStart) / fineStep) * fineStep);
      const best = lookup.get(`${nearLat},${nearLon}`);
      return {
        name: c.name,
        lat: c.lat,
        lon: c.lon,
        aqi: best?.aqi ?? null,
        windSpeed: best ? Math.round(best.windSpeed * 10) / 10 : 0,
        windDir: best ? Math.round(best.windDirection) : 0,
      };
    });
  }

  // ── Demo mode ──────────────────────────────────────────────────────────────

  const DEMO = new URLSearchParams(window.location.search).has("demo");

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
  let mapContainer = $state<HTMLDivElement>(undefined!);

  // ── Fetch data ──────────────────────────────────────────────────────────────

  /** Yield to browser so progress bar actually paints */
  const paint = () =>
    new Promise<void>((r) => requestAnimationFrame(() => setTimeout(r, 0)));

  function timeAgo(date: Date): string {
    const mins = Math.floor((Date.now() - date.getTime()) / 60000);
    if (mins < 1) return "just now";
    if (mins < 60) return `${mins}m ago`;
    const hrs = Math.floor(mins / 60);
    if (hrs < 24) return `${hrs}h ago`;
    const days = Math.floor(hrs / 24);
    return `${days}d ago`;
  }

  async function fetchData() {
    if (!mapContainer) return;
    grid = buildGrid(FETCH);

    loading = true;
    error = null;
    loadPct = 0;
    loadStatus = `Fetching wind for ${grid.length} points`;

    try {
      let allWeather: any[];
      let allAq: any[];

      if (DEMO) {
        loadStatus = "Loading demo data";
        await paint();
        const res = await fetch(import.meta.env.BASE_URL + "demo-data.json");
        const contentType = res.headers.get("content-type") || "";
        if (!res.ok || !contentType.includes("json")) {
          throw new Error("No demo data found. Run: npm run fetch-demo");
        }
        const demo = await res.json();
        allWeather = demo.weather;
        allAq = demo.airQuality;
        grid = demo.grid;
        lastUpdated = new Date(demo.fetchedAt);
        loadPct = 55;
        loadStatus = "Parsing responses";
        await paint();
      } else {
        const lats = grid.map((p) => p.lat).join(",");
        const lons = grid.map((p) => p.lon).join(",");

        const wFetch = fetch(
          `https://api.open-meteo.com/v1/forecast?latitude=${lats}&longitude=${lons}&current=wind_speed_10m,wind_direction_10m&wind_speed_unit=ms`
        );
        const aFetch = fetch(
          `https://air-quality-api.open-meteo.com/v1/air-quality?latitude=${lats}&longitude=${lons}&current=us_aqi,pm2_5&domains=cams_global`
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
        allWeather = Array.isArray(wJson) ? wJson : [wJson];
        allAq = Array.isArray(aJson) ? aJson : [aJson];
      }
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
        raw.set(`${pt.lat},${pt.lon}`, {
          u: -speed * Math.sin(rad),
          v: -speed * Math.cos(rad),
          aqi: a?.us_aqi ?? null,
        });
      }

      rawCache = raw;
      vectors = interpolateGrid(raw, FETCH, interp);
      const fineStep = STEP / interp;
      cityData = computeCityData(VISIBLE_CITIES, vectors, fineStep);
      loadPct = 100;
      loadStatus = "Rendering";

      if (!DEMO) lastUpdated = new Date();
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
    vectors = interpolateGrid(rawCache, FETCH, interp);
    const fineStep = STEP / interp;
    cityData = computeCityData(VISIBLE_CITIES, vectors, fineStep);
  }

  // ── Render map ──────────────────────────────────────────────────────────────

  const countries = topojson.feature(world, world.objects.countries);

  let containerWidth = $state(0);
  let containerHeight = $state(0);

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

  $effect(() => {
    if (!mapContainer || vectors.length === 0) return;

    const width = containerWidth;
    const height = containerHeight;
    if (height < 10) return;

    const b = VIEW;
    const plot = Plot.plot({
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

        // City dots (below vectors, subtle)
        Plot.dot(cityData, {
          x: "lon",
          y: "lat",
          r: 2,
          fill: "#e5e7eb",
          fillOpacity: 0.33,
        }),

        // Wind vector field — arrows colored by AQI
        Plot.vector(vectors, {
          x: "lon",
          y: "lat",
          rotate: (d: VectorDatum) => (d.windDirection + 180) % 360,
          length: (d: VectorDatum) => 5 + (d.windSpeed / 15) * 15,
          stroke: (d: VectorDatum) => aqiColor(d.aqi),
          strokeOpacity: 0.33,
          strokeWidth: 2,
          anchor: "middle",
        }),

        // Tooltip on hover
        Plot.tip(cityData, Plot.pointer({
          x: "lon",
          y: "lat",
          fill: "#2a323c",
          stroke: "#3d4451",
          channels: {
            "": { value: (d: CityDatum) => d.name, label: null },
            "AQI:": { value: (d: CityDatum) => d.aqi != null ? Math.round(d.aqi) : "N/A" },
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

    mapContainer.replaceChildren(plot);
  });

  // ── Init: fetch once container is available ─────────────────────────────────

  let fetched = false;
  $effect(() => {
    if (mapContainer && !fetched) {
      fetched = true;
      fetchData();
    }
  });
</script>

<div class="h-screen overflow-hidden bg-base-200 p-2">
  <div class="card bg-base-100 shadow-sm border border-base-300 overflow-hidden h-full relative">
    <div bind:this={mapContainer} class="w-full h-full"></div>

    {#if loading && vectors.length === 0}
      <div
        class="absolute inset-0 flex flex-col items-center justify-center gap-2 bg-base-100"
      >
        <progress
          class="progress progress-primary w-48"
          value={loadPct}
          max="100"
        ></progress>
        <span class="text-xs opacity-50">{loadStatus}</span>
      </div>
    {:else if error}
      <div
        class="absolute inset-0 flex items-center justify-center bg-base-100"
      >
        <div class="text-center flex flex-col items-center gap-2">
          <p class="font-semibold text-error">Failed to load data</p>
          <p class="text-sm text-error opacity-70">{error}</p>
          {#if isRateLimited}
            <a href="?demo" class="btn btn-sm bg-base-content text-base-100 border-base-content mt-1">Load demo?</a>
          {/if}
        </div>
      </div>
    {/if}

    <!-- Legend — bottom left -->
    <div class="absolute bottom-2 left-2 flex items-center gap-1.5 bg-base-100/80 backdrop-blur-sm rounded px-2.5 py-1.5">
      {#each AQI_BANDS as band}
        <span class="w-2 h-2 rounded-full shrink-0" style="background-color: {band.color};" title={band.label}></span>
        <span class="text-[10px] opacity-60">{band.label}</span>
      {/each}
    </div>

    <!-- Controls — bottom right -->
    <div class="absolute bottom-2 right-2 flex items-center gap-1.5 bg-base-100/80 backdrop-blur-sm rounded px-2.5 py-1.5">
      {#if DEMO}
        <span class="text-[10px] font-medium text-warning">DEMO</span>
        <span class="opacity-20">·</span>
      {/if}
      {#if lastUpdated}
        <span class="text-[10px] opacity-60">{lastUpdated.toLocaleTimeString("en-GB", { timeZone: "Asia/Seoul", hour: "2-digit", minute: "2-digit" })} KST {#if DEMO} ({timeAgo(lastUpdated)}){/if}</span>
        <span class="opacity-20">·</span>
      {/if}
      <select
        class="text-[10px] opacity-50 bg-transparent outline-none cursor-pointer"
        title="Interpolation factor"
        value={interp}
        onchange={(e) => { interp = Number(e.currentTarget.value); reinterpolate(); }}
      >
        {#each [1, 2, 3, 4, 5] as v}
          <option value={v}>×{v}</option>
        {/each}
      </select>
      <span class="opacity-20">·</span>
      <button class="opacity-50 hover:opacity-100 transition-opacity disabled:opacity-20" onclick={fetchData} disabled={loading} title="Refresh">
        <RefreshCw size={12} class={loading ? "animate-spin" : ""} />
      </button>
      {#if !DEMO}
        <span class="opacity-20">·</span>
        <a href="?demo" class="text-[10px] opacity-40 hover:opacity-80 transition-opacity" title="Load demo data">demo</a>
      {/if}
    </div>
  </div>
</div>
