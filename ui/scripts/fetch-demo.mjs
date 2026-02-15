#!/usr/bin/env node
/**
 * Fetches current wind + AQI data from Open-Meteo and saves as demo dataset.
 * Run:  node scripts/fetch-demo.mjs
 *       npm run fetch-demo
 *
 * Load in app:  http://localhost:5173/?demo
 *
 * Grid params duplicated from App.svelte — keep in sync if you change STEP/bounds.
 */

import { writeFileSync } from "fs";
import { dirname, join } from "path";
import { fileURLToPath } from "url";

const STEP = 2;
const CENTER_LON = 125;
const CENTER_LAT = 38;
const MIN_LON_SPAN = 42;
const MIN_LAT_SPAN = 22;

const snapDown = (v) => Math.floor(v / STEP) * STEP;
const snapUp = (v) => Math.ceil(v / STEP) * STEP;

const VIEW = {
  lonMin: snapDown(CENTER_LON - MIN_LON_SPAN / 2),
  lonMax: snapUp(CENTER_LON + MIN_LON_SPAN / 2),
  latMin: snapDown(CENTER_LAT - MIN_LAT_SPAN / 2),
  latMax: snapUp(CENTER_LAT + MIN_LAT_SPAN / 2),
};

const FETCH = {
  lonMin: VIEW.lonMin - 8 * STEP,
  lonMax: VIEW.lonMax + 8 * STEP,
  latMin: VIEW.latMin - 4 * STEP,
  latMax: VIEW.latMax + 4 * STEP,
};

// Build grid
const grid = [];
for (let lat = FETCH.latMin; lat <= FETCH.latMax + 0.01; lat += STEP) {
  for (let lon = FETCH.lonMin; lon <= FETCH.lonMax + 0.01; lon += STEP) {
    grid.push({
      lat: Math.round(lat * 10) / 10,
      lon: Math.round(lon * 10) / 10,
    });
  }
}

const lats = grid.map((p) => p.lat).join(",");
const lons = grid.map((p) => p.lon).join(",");

console.log(`Fetching ${grid.length} grid points...`);

const [wRes, aRes] = await Promise.all([
  fetch(
    `https://api.open-meteo.com/v1/forecast?latitude=${lats}&longitude=${lons}&current=wind_speed_10m,wind_direction_10m&wind_speed_unit=ms`
  ),
  fetch(
    `https://air-quality-api.open-meteo.com/v1/air-quality?latitude=${lats}&longitude=${lons}&current=us_aqi,pm2_5&domains=cams_global`
  ),
]);

if (!wRes.ok) {
  console.error(`Weather API error: ${wRes.status} ${await wRes.text()}`);
  process.exit(1);
}
if (!aRes.ok) {
  console.error(`AQ API error: ${aRes.status} ${await aRes.text()}`);
  process.exit(1);
}

const weather = await wRes.json();
const airQuality = await aRes.json();

const data = {
  fetchedAt: new Date().toISOString(),
  grid,
  weather: Array.isArray(weather) ? weather : [weather],
  airQuality: Array.isArray(airQuality) ? airQuality : [airQuality],
};

const __dirname = dirname(fileURLToPath(import.meta.url));
const outPath = join(__dirname, "..", "public", "demo-data.json");
writeFileSync(outPath, JSON.stringify(data));

const sizeMB = (Buffer.byteLength(JSON.stringify(data)) / 1024 / 1024).toFixed(
  1
);
console.log(`Saved ${grid.length} points (${sizeMB} MB) → ${outPath}`);
console.log(`Load in app: http://localhost:5173/?demo`);
