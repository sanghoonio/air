import type { AqiBand } from "./types";

export const AQI_BANDS: AqiBand[] = [
  { min: 0, max: 50, color: "#22c55e", label: "Good" },
  { min: 51, max: 100, color: "#eab308", label: "Moderate" },
  { min: 101, max: 150, color: "#f97316", label: "USG" },
  { min: 151, max: 200, color: "#ef4444", label: "Unhealthy" },
  { min: 201, max: 300, color: "#a855f7", label: "Very Unhealthy" },
  { min: 301, max: 500, color: "#991b1b", label: "Hazardous" },
];

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

export function aqiColor(aqi: number | null): string {
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
