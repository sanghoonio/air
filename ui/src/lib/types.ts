export type MetricKey =
  | "us_aqi"
  | "european_aqi"
  | "pm2_5"
  | "pm10"
  | "dust"
  | "aerosol_optical_depth"
  | "carbon_monoxide"
  | "nitrogen_dioxide"
  | "sulphur_dioxide"
  | "ozone";

export interface GridPoint {
  lat: number;
  lon: number;
}

export interface Bounds {
  lonMin: number;
  lonMax: number;
  latMin: number;
  latMax: number;
}

export interface CityDatum {
  name: string;
  lat: number;
  lon: number;
  metric: number | null;
  windSpeed: number;
  windDir: number;
}

export interface AqiBand {
  min: number;
  max: number;
  color: string;
  label: string;
}

export interface VectorDatum {
  lat: number;
  lon: number;
  windSpeed: number;
  windDirection: number;
  metric: number | null;
}

export interface RawDatum {
  u: number; // wind x-component (m/s)
  v: number; // wind y-component (m/s)
  metrics: Partial<Record<MetricKey, number | null>>;
}
