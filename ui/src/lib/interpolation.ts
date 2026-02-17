import type { Bounds, MetricKey, RawDatum, VectorDatum } from "./types";
import { STEP } from "./config";

export const INTERP_DEFAULT = typeof window !== "undefined" && window.innerWidth < 640 ? 3 : 5;

const DEG = Math.PI / 180;
export { DEG };

const r1 = (v: number) => Math.round(v * 10) / 10;

const snapDown = (v: number) => Math.floor(v / STEP) * STEP;

/** Catmull-Rom cubic: interpolate between p1 and p2, t in [0,1] */
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
  field: "u" | "v",
): number {
  const d = raw.get(`${r1(lat)},${r1(lon)}`);
  if (!d) return 0;
  return d[field] ?? 0;
}

/** Look up a metric value from the raw grid, returning 0 if missing */
function metricVal(
  raw: Map<string, RawDatum>,
  lat: number,
  lon: number,
  metricKey: MetricKey,
): number {
  const d = raw.get(`${r1(lat)},${r1(lon)}`);
  if (!d) return 0;
  return d.metrics[metricKey] ?? 0;
}

/**
 * Interpolate a fine grid of vectors over `area` using Catmull-Rom cubic splines.
 * The raw data Map must extend at least 2×STEP beyond `area` on every side
 * to provide the 4×4 stencil the cubic kernel requires.
 */
export function interpolateGrid(
  raw: Map<string, RawDatum>,
  area: Bounds,
  interp: number,
  metricKey: MetricKey = "us_aqi",
): VectorDatum[] {
  const fineStep = STEP / interp;
  const out: VectorDatum[] = [];

  for (let lat = area.latMin; lat <= area.latMax + 0.01; lat += fineStep) {
    for (let lon = area.lonMin; lon <= area.lonMax + 0.01; lon += fineStep) {
      const latBase = snapDown(lat);
      const lonBase = snapDown(lon);
      const fy = (lat - latBase) / STEP;
      const fx = (lon - lonBase) / STEP;

      const latRows = [latBase - STEP, latBase, latBase + STEP, latBase + 2 * STEP];
      const lonCols = [lonBase - STEP, lonBase, lonBase + STEP, lonBase + 2 * STEP];

      const rowU: number[] = [];
      const rowV: number[] = [];
      const rowM: number[] = [];

      for (const rLat of latRows) {
        rowU.push(cubic(
          val(raw, rLat, lonCols[0], "u"), val(raw, rLat, lonCols[1], "u"),
          val(raw, rLat, lonCols[2], "u"), val(raw, rLat, lonCols[3], "u"), fx
        ));
        rowV.push(cubic(
          val(raw, rLat, lonCols[0], "v"), val(raw, rLat, lonCols[1], "v"),
          val(raw, rLat, lonCols[2], "v"), val(raw, rLat, lonCols[3], "v"), fx
        ));
        rowM.push(cubic(
          metricVal(raw, rLat, lonCols[0], metricKey), metricVal(raw, rLat, lonCols[1], metricKey),
          metricVal(raw, rLat, lonCols[2], metricKey), metricVal(raw, rLat, lonCols[3], metricKey), fx
        ));
      }

      const u = cubic(rowU[0], rowU[1], rowU[2], rowU[3], fy);
      const v = cubic(rowV[0], rowV[1], rowV[2], rowV[3], fy);
      const m = cubic(rowM[0], rowM[1], rowM[2], rowM[3], fy);

      const speed = Math.sqrt(u * u + v * v);
      const dir = ((Math.atan2(-u, -v) / DEG) + 360) % 360;

      out.push({
        lat: r1(lat),
        lon: r1(lon),
        windSpeed: speed,
        windDirection: dir,
        metric: Math.max(0, m),
      });
    }
  }
  return out;
}

/** Find the nearest interpolated vector via grid lookup (O(1) per city) */
export function computeCityData(
  cities: readonly { name: string; lat: number; lon: number }[],
  vecs: VectorDatum[],
  area: Bounds,
  fineStep: number
) {
  const lookup = new Map<string, VectorDatum>();
  for (const v of vecs) lookup.set(`${v.lat},${v.lon}`, v);

  return cities.map((c) => {
    const nearLat = r1(area.latMin + Math.round((c.lat - area.latMin) / fineStep) * fineStep);
    const nearLon = r1(area.lonMin + Math.round((c.lon - area.lonMin) / fineStep) * fineStep);
    const best = lookup.get(`${nearLat},${nearLon}`);
    return {
      name: c.name,
      lat: c.lat,
      lon: c.lon,
      metric: best?.metric ?? null,
      windSpeed: best ? Math.round(best.windSpeed * 10) / 10 : 0,
      windDir: best ? Math.round(best.windDirection) : 0,
    };
  });
}
