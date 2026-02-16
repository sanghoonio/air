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
  aqi: number | null;
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
  aqi: number | null;
}

export interface RawDatum {
  u: number; // wind x-component (m/s)
  v: number; // wind y-component (m/s)
  aqi: number | null;
}
