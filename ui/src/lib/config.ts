import type { GridPoint, Bounds } from "./types";

const CENTER_LON = 125;
const CENTER_LAT = 38;
const MIN_LON_SPAN = 42;
const MIN_LAT_SPAN = 22;
export const STEP = 2;

const snapDown = (v: number) => Math.floor(v / STEP) * STEP;
const snapUp = (v: number) => Math.ceil(v / STEP) * STEP;

export const VIEW: Bounds = {
  lonMin: snapDown(CENTER_LON - MIN_LON_SPAN / 2),
  lonMax: snapUp(CENTER_LON + MIN_LON_SPAN / 2),
  latMin: snapDown(CENTER_LAT - MIN_LAT_SPAN / 2),
  latMax: snapUp(CENTER_LAT + MIN_LAT_SPAN / 2),
};

export const FETCH: Bounds = {
  lonMin: VIEW.lonMin - 8 * STEP,
  lonMax: VIEW.lonMax + 8 * STEP,
  latMin: VIEW.latMin - 8 * STEP,
  latMax: VIEW.latMax + 8 * STEP,
};

export function buildGrid(b: Bounds): GridPoint[] {
  const pts: GridPoint[] = [];
  for (let lat = b.latMin; lat <= b.latMax + 0.01; lat += STEP) {
    for (let lon = b.lonMin; lon <= b.lonMax + 0.01; lon += STEP) {
      pts.push({ lat: Math.round(lat * 10) / 10, lon: Math.round(lon * 10) / 10 });
    }
  }
  return pts;
}

export const CITY_COORDS = [
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
] as const;

export const VISIBLE_CITIES = CITY_COORDS.filter(
  (c) =>
    c.lat >= VIEW.latMin - 1 &&
    c.lat <= VIEW.latMax + 1 &&
    c.lon >= VIEW.lonMin - 1 &&
    c.lon <= VIEW.lonMax + 1
);
