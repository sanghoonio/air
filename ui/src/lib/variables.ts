import type { MetricKey, AqiBand } from "./types";
import { aqiColor } from "./aqi";

export interface VariableConfig {
  key: MetricKey;
  label: string;
  unit: string;
  domain: [number, number];
  colorType: "aqi" | "sequential";
}

const SEQ_STOPS: [number, number, number][] = [
  [0x22, 0xc5, 0x5e], // green
  [0xea, 0xb3, 0x08], // yellow
  [0xf9, 0x73, 0x16], // orange
  [0xef, 0x44, 0x44], // red
];

function seqColor(t: number): string {
  const clamped = Math.max(0, Math.min(1, t));
  const scaled = clamped * (SEQ_STOPS.length - 1);
  const i = Math.min(Math.floor(scaled), SEQ_STOPS.length - 2);
  const f = scaled - i;
  const a = SEQ_STOPS[i], b = SEQ_STOPS[i + 1];
  const r = Math.round(a[0] + (b[0] - a[0]) * f);
  const g = Math.round(a[1] + (b[1] - a[1]) * f);
  const bl = Math.round(a[2] + (b[2] - a[2]) * f);
  return `rgb(${r},${g},${bl})`;
}

export const VARIABLE_CONFIGS: VariableConfig[] = [
  { key: "us_aqi",                label: "US AQI",       unit: "",       domain: [0, 500],  colorType: "aqi" },
  { key: "european_aqi",          label: "EU AQI",       unit: "",       domain: [0, 100],  colorType: "aqi" },
  { key: "pm2_5",                 label: "PM2.5",        unit: "μg/m³",  domain: [0, 150],  colorType: "sequential" },
  { key: "pm10",                  label: "PM10",         unit: "μg/m³",  domain: [0, 300],  colorType: "sequential" },
  { key: "dust",                  label: "Dust",         unit: "μg/m³",  domain: [0, 200],  colorType: "sequential" },
  { key: "aerosol_optical_depth", label: "AOD",          unit: "",       domain: [0, 2],    colorType: "sequential" },
  { key: "carbon_monoxide",       label: "CO",           unit: "μg/m³",  domain: [0, 5000], colorType: "sequential" },
  { key: "nitrogen_dioxide",      label: "NO₂",         unit: "μg/m³",  domain: [0, 100],  colorType: "sequential" },
  { key: "sulphur_dioxide",       label: "SO₂",         unit: "μg/m³",  domain: [0, 100],  colorType: "sequential" },
  { key: "ozone",                 label: "O₃",          unit: "μg/m³",  domain: [0, 200],  colorType: "sequential" },
];

export const VARIABLE_MAP = new Map(VARIABLE_CONFIGS.map((c) => [c.key, c]));

export function getVariableConfig(key: MetricKey): VariableConfig {
  return VARIABLE_MAP.get(key) ?? VARIABLE_CONFIGS[0];
}

export function metricColor(value: number | null, config: VariableConfig): string {
  if (value == null) return "#6b7280";
  if (config.colorType === "aqi") return aqiColor(value);
  const [lo, hi] = config.domain;
  return seqColor((value - lo) / (hi - lo));
}

export function generateBands(config: VariableConfig): AqiBand[] {
  const [lo, hi] = config.domain;
  const n = 5;
  const step = (hi - lo) / n;
  const labels = ["Low", "Moderate", "Elevated", "High", "Very High"];
  return Array.from({ length: n }, (_, i) => {
    const min = lo + i * step;
    const max = lo + (i + 1) * step;
    return {
      min,
      max,
      color: seqColor((i + 0.5) / n),
      label: labels[i],
    };
  });
}
