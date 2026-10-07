/**
 * Open-Meteo Weather Service
 * Retrieves historical precipitation for past 14 days and soil metrics (soil_temperature_6cm, soil_moisture_0_to_1cm).
 * Features in-memory spatial caching with 1-hour expiration.
 */

const weatherCache = new Map();
const CACHE_TTL_MS = 60 * 60 * 1000; // 1 hour

function calculateSmoothRainBonus(rainMm) {
  if (rainMm <= 0.0) return -15;
  if (rainMm < 10.0) {
    return Math.round(-15.0 + (rainMm / 10.0) * 13.0);
  } else if (rainMm < 25.0) {
    const t = (rainMm - 10.0) / 15.0;
    return Math.round(-2.0 + t * 16.0);
  } else if (rainMm < 50.0) {
    const t = (rainMm - 25.0) / 25.0;
    return Math.round(14.0 + t * 11.0);
  } else {
    return 25;
  }
}

export async function fetchRainfallData(lat, lng) {
  // Spatial cache key (approx. 3-5 km grid)
  const cacheKey = `${lat.toFixed(2)}_${lng.toFixed(2)}`;
  const cached = weatherCache.get(cacheKey);
  if (cached && (Date.now() - cached.timestamp < CACHE_TTL_MS)) {
    return cached.data;
  }

  const roundedLat = lat.toFixed(3);
  const roundedLng = lng.toFixed(3);
  // W1 (past_days=14) and W2 (soil_temperature_6cm, soil_moisture_0_to_1cm)
  const url = `https://api.open-meteo.com/v1/forecast?latitude=${roundedLat}&longitude=${roundedLng}&daily=precipitation_sum,temperature_2m_max&hourly=soil_temperature_6cm,soil_moisture_0_to_1cm&past_days=14&forecast_days=1&timezone=Europe%2FWarsaw`;

  try {
    const res = await fetch(url, { signal: AbortSignal.timeout(6000) });
    if (!res.ok) throw new Error(`Weather API returned ${res.status}`);
    const data = await res.json();

    const rainDays = (data.daily?.precipitation_sum || []).filter(v => v !== null && v !== undefined);
    const temps = (data.daily?.temperature_2m_max || []).filter(v => v !== null && v !== undefined);
    const totalRain = rainDays.reduce((sum, val) => sum + (val || 0), 0);
    const avgTemp = temps.length ? (temps.reduce((a, b) => a + b, 0) / temps.length) : 17.5;

    // Soil metrics
    const soilTemps = (data.hourly?.soil_temperature_6cm || []).filter(v => v !== null && v !== undefined);
    const soilMoists = (data.hourly?.soil_moisture_0_to_1cm || []).filter(v => v !== null && v !== undefined);

    let avgSoilTemp = null;
    if (soilTemps.length > 0) {
      const recent = soilTemps.length > 24 ? soilTemps.slice(-24) : soilTemps;
      avgSoilTemp = recent.reduce((a, b) => a + b, 0) / recent.length;
    }

    let avgSoilMoist = null;
    if (soilMoists.length > 0) {
      const recent = soilMoists.length > 24 ? soilMoists.slice(-24) : soilMoists;
      avgSoilMoist = recent.reduce((a, b) => a + b, 0) / recent.length;
    }

    let moistureLabel = 'Umiarkowane nawilżenie';
    let moistureBadgeColor = '#f59e0b'; // amber
    const rainBonusScore = calculateSmoothRainBonus(totalRain);

    if (totalRain < 8) {
      moistureLabel = 'Przesuszona ściółka (brak wysypu)';
      moistureBadgeColor = '#ef4444'; // red
    } else if (totalRain < 20) {
      moistureLabel = 'Umiarkowane nawilżenie';
      moistureBadgeColor = '#f59e0b'; // amber
    } else if (totalRain < 45) {
      moistureLabel = 'Dobre nawilżenie ściółki (optimum)';
      moistureBadgeColor = '#10b981'; // green
    } else {
      moistureLabel = 'Bardzo obfite opady deszczu!';
      moistureBadgeColor = '#3b82f6'; // blue
    }

    const result = {
      success: true,
      isAvailable: true,
      totalRainMm: totalRain.toFixed(1),
      avgTempC: avgTemp.toFixed(1),
      periodDays: 14,
      soilTempC: avgSoilTemp !== null ? avgSoilTemp.toFixed(1) : null,
      soilMoisturePercent: avgSoilMoist !== null ? `${(avgSoilMoist * 100).toFixed(1)}%` : null,
      moistureLabel,
      moistureBadgeColor,
      rainBonusScore
    };

    weatherCache.set(cacheKey, { data: result, timestamp: Date.now() });
    return result;
  } catch (err) {
    // W3 fix: Never return fabricated 16.8mm numbers. Return null/unavailable so user knows truth.
    console.warn('Weather fetch failed:', err.message);
    return null;
  }
}

