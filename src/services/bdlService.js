/**
 * BDL (Bank Danych o Lasach) Service
 * Interacts with Polish state forest WMS and parses forestry parcel attributes.
 */

import { BDL_WMS_CONFIG } from '../config/mapConfig.js';
import { getSpeciesInfo, getHabitatInfo, getFunctionInfo } from '../data/forestCodes.js';

const parcelCache = new Map();

export async function queryForestParcel(map, latlng) {
  const cacheKey = `${latlng.lat.toFixed(4)}_${latlng.lng.toFixed(4)}`;
  if (parcelCache.has(cacheKey)) {
    return parcelCache.get(cacheKey);
  }
  const size = map.getSize();
  const point = map.latLngToContainerPoint(latlng);
  const bounds = map.getBounds();
  
  // Project bounds to EPSG:3857 (Web Mercator)
  const sw = map.options.crs.project(bounds.getSouthWest());
  const ne = map.options.crs.project(bounds.getNorthEast());
  const bbox = `${sw.x},${sw.y},${ne.x},${ne.y}`;

  const x = Math.round(point.x);
  const y = Math.round(point.y);

  // Check zoom level: Wydzielenia leśne (layer 1) are active at zoom >= 13
  const currentZoom = map.getZoom();
  const layersToQuery = currentZoom >= 13 ? '1,3,4' : '4,5';

  const params = new URLSearchParams({
    SERVICE: 'WMS',
    VERSION: '1.1.1',
    REQUEST: 'GetFeatureInfo',
    BBOX: bbox,
    SRS: 'EPSG:3857',
    WIDTH: Math.round(size.x),
    HEIGHT: Math.round(size.y),
    LAYERS: layersToQuery,
    QUERY_LAYERS: layersToQuery,
    INFO_FORMAT: 'text/html',
    X: x,
    Y: y
  });

  const queryUrl = `${BDL_WMS_CONFIG.featureInfoUrl}?${params.toString()}`;

  try {
    const res = await fetch(queryUrl, { signal: AbortSignal.timeout(6000) });
    if (!res.ok) {
      throw new Error(`BDL WMS returned status ${res.status}`);
    }
    const html = await res.text();
    const parsed = parseBdlHtmlResponse(html, latlng);
    parcelCache.set(cacheKey, parsed);
    return parsed;
  } catch (err) {
    console.warn('BDL GetFeatureInfo fetch failed or timed out:', err.message);
    // Fallback: return simulated parcel for demonstration if server times out
    return getFallbackParcel(latlng, currentZoom);
  }
}

/**
 * Parses the HTML tables returned by ArcGIS WMS GetFeatureInfo
 */
function parseBdlHtmlResponse(html, latlng) {
  // Check if any table is returned
  if (!html.includes('<table') || !html.includes('<tr>')) {
    return {
      found: false,
      message: 'Kliknięty punkt znajduje się poza terenem Lasów Państwowych lub przybliż mapę (min. zoom 13), aby zobaczyć wydzielenia.',
      latlng
    };
  }

  // Parse HTML using DOMParser
  const parser = new DOMParser();
  const doc = parser.parseFromString(html, 'text/html');
  const tables = doc.querySelectorAll('table');
  const h5List = doc.querySelectorAll('h5');

  let wydzielenieData = null;
  let lesnictwoData = null;
  let nadlesnictwoData = null;

  tables.forEach((table, idx) => {
    const title = h5List[idx] ? h5List[idx].textContent : '';
    const headers = Array.from(table.querySelectorAll('tr:first-child th')).map(th => th.textContent.trim().toLowerCase());
    const row = table.querySelector('tr:nth-child(2)');
    if (!row) return;

    const values = Array.from(row.querySelectorAll('td')).map(td => td.textContent.trim());
    const obj = {};
    headers.forEach((h, i) => {
      obj[h] = values[i] || '';
    });

    if (title.includes('Wydzielenia PGL LP') || obj['subarea_id'] || obj['species_cd_d']) {
      wydzielenieData = obj;
    } else if (title.includes('Leśnictwa') || obj['forest_range_name']) {
      lesnictwoData = obj;
    } else if (title.includes('Nadleśnictwa') || obj['inspectorate_name']) {
      nadlesnictwoData = obj;
    }
  });

  if (!wydzielenieData) {
    // If only district/inspectorate found (e.g. zoomed out)
    return {
      found: true,
      isMacro: true,
      latlng,
      inspectorate: nadlesnictwoData ? nadlesnictwoData.inspectorate_name : 'Lasy Państwowe',
      forestRange: lesnictwoData ? lesnictwoData.forest_range_name : 'Nadleśnictwo',
      message: 'Przybliż mapę do poziomu lasu (zoom 14+), aby zobaczyć szczegóły gatunków drzew i wieku.'
    };
  }

  // Extract core forestry parameters
  const rawSpecies = (wydzielenieData.species_cd_d || '').trim();
  const rawAge = parseInt(wydzielenieData.species_age, 10) || 0;
  const rawHabitat = (wydzielenieData.site_type_cd || '').trim();
  const rawFunc = (wydzielenieData.forest_func_cd || 'GOSP').trim();
  const rawShare = parseInt(wydzielenieData.part_cd, 10) || 10;
  const rawArea = wydzielenieData.sub_area || '';
  const forestAddress = wydzielenieData.adress_forest || 'Brak adresu leśnego';

  const speciesInfo = getSpeciesInfo(rawSpecies);
  const habitatInfo = getHabitatInfo(rawHabitat);
  const functionInfo = getFunctionInfo(rawFunc);

  // Age category
  let ageCategory = 'Średniowiek';
  if (rawAge < 25) ageCategory = 'Młodnik / Uprawa (10-25 lat)';
  else if (rawAge >= 25 && rawAge < 50) ageCategory = 'Drzewostan dojrzewający (25-50 lat)';
  else if (rawAge >= 50 && rawAge < 90) ageCategory = 'Dojrzały bór / las (50-90 lat)';
  else if (rawAge >= 90) ageCategory = 'Starodrzew (>90 lat)';

  return {
    found: true,
    isMacro: false,
    latlng,
    address: forestAddress,
    subareaId: wydzielenieData.subarea_id,
    species: {
      code: rawSpecies,
      namePl: speciesInfo.namePl,
      nameRu: speciesInfo.nameRu,
      icon: speciesInfo.icon,
      type: speciesInfo.type,
      sharePercent: rawShare > 10 ? rawShare : rawShare * 10
    },
    age: rawAge,
    ageCategory,
    rotationAge: parseInt(wydzielenieData.rotation_age, 10) || 100,
    habitat: {
      code: rawHabitat,
      namePl: habitatInfo.namePl,
      descPl: habitatInfo.descPl,
      moisture: habitatInfo.moisture
    },
    status: {
      code: rawFunc,
      status: functionInfo.status,
      labelPl: functionInfo.labelPl,
      color: functionInfo.color
    },
    areaHa: rawArea,
    inspectorate: nadlesnictwoData ? nadlesnictwoData.inspectorate_name : 'Nadleśnictwo LP'
  };
}

/**
 * Fallback generator for realistic data when offline/testing
 */
function getFallbackParcel(latlng, zoom) {
  return {
    found: true,
    isMacro: false,
    isSimulated: true,
    latlng,
    address: '17-01-1-03-360-a-00 (Tryb Demonstracyjny BDL)',
    subareaId: '2568826',
    species: {
      code: 'SO',
      namePl: 'Sosna zwyczajna',
      nameRu: 'Сосна обыкновенная',
      icon: '🌲',
      type: 'conifer',
      sharePercent: 80
    },
    age: 58,
    ageCategory: 'Dojrzały bór (50-90 lat)',
    rotationAge: 120,
    habitat: {
      code: 'BŚW',
      namePl: 'Bór świeży',
      descPl: 'Klasyczny las sosnowy z mchem i borówką czernicą. Optymalny biotop dla borowika i podgrzybka.',
      moisture: 'optimal'
    },
    status: {
      code: 'GOSP',
      status: 'allowed',
      labelPl: 'Las gospodarczy (Zbiór dozwolony)',
      color: '#10b981'
    },
    areaHa: '3.4 ha',
    inspectorate: 'Nadleśnictwo Celestynów'
  };
}
