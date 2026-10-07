import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import './style.css';

import { MAP_CONFIG, BASE_LAYERS, BDL_WMS_CONFIG, TRANSPARENT_TILE } from './config/mapConfig.js';
import { FAMOUS_SPOTS } from './data/famousSpots.js';
import { queryForestParcel } from './services/bdlService.js';
import { fetchRainfallData } from './services/weatherService.js';
import { matchMushrooms } from './services/matcherService.js';
import { ParkingRadar } from './ui/parkingRadar.js';

// Application State
const state = {
  currentLayerKey: 'satellite',
  selectedMonth: 9, // September by default (peak season)
  currentParcel: null,
  currentWeather: null,
  activeTab: 'tab-radar',
  clickMarker: null,
  carMarker: null,
  bdlLayerVisible: true,
  mushFilter: 'all' // 'all', 'high', 'prime'
};

const parkingRadar = new ParkingRadar();

// Initialize Leaflet Map
const map = L.map('map', {
  center: MAP_CONFIG.initialCenter,
  zoom: MAP_CONFIG.initialZoom,
  minZoom: MAP_CONFIG.minZoom,
  maxZoom: MAP_CONFIG.maxZoom,
  zoomControl: false
});

// Custom zoom control in bottom-right
L.control.zoom({ position: 'bottomright' }).addTo(map);

// Common tile loading options: prevents black square flashes and retains surrounding tiles
const commonTileOptions = {
  keepBuffer: 8,           // Keeps surrounding tiles cached in RAM
  updateWhenZooming: false, // Smooth scaling during zoom instead of blanking out
  updateWhenIdle: true,    // Waits for pan momentum to settle before burst queries
  errorTileUrl: TRANSPARENT_TILE // Graceful transparent fallback on timeout
};

// Base tile layers dictionary
const baseLayerInstances = {
  satellite: L.tileLayer(BASE_LAYERS.satellite.url, {
    maxNativeZoom: BASE_LAYERS.satellite.maxNativeZoom,
    maxZoom: BASE_LAYERS.satellite.maxZoom,
    attribution: BASE_LAYERS.satellite.attribution,
    ...commonTileOptions
  }),
  geoportal: L.tileLayer.wms(BASE_LAYERS.geoportal.url, {
    ...BASE_LAYERS.geoportal.wmsParams,
    ...commonTileOptions
  }),
  topo: L.tileLayer(BASE_LAYERS.topo.url, {
    subdomains: BASE_LAYERS.topo.subdomains,
    maxNativeZoom: BASE_LAYERS.topo.maxNativeZoom, // 17 - prevents black tiles at zoom 18/19!
    maxZoom: BASE_LAYERS.topo.maxZoom,
    attribution: BASE_LAYERS.topo.attribution,
    ...commonTileOptions
  }),
  dark: L.tileLayer(BASE_LAYERS.dark.url, {
    maxNativeZoom: BASE_LAYERS.dark.maxNativeZoom,
    maxZoom: BASE_LAYERS.dark.maxZoom,
    attribution: BASE_LAYERS.dark.attribution,
    ...commonTileOptions
  }),
  osm: L.tileLayer(BASE_LAYERS.osm.url, {
    subdomains: BASE_LAYERS.osm.subdomains,
    maxNativeZoom: BASE_LAYERS.osm.maxNativeZoom,
    maxZoom: BASE_LAYERS.osm.maxZoom,
    attribution: BASE_LAYERS.osm.attribution,
    ...commonTileOptions
  })
};

// Add initial default satellite layer
baseLayerInstances.satellite.addTo(map);

// BDL WMS Layers: Layer 1 (Wydzielenia) & Layer 3 (Oddziały)
const bdlWydzielenia = L.tileLayer.wms(BDL_WMS_CONFIG.tilesUrl, {
  layers: '1',
  format: 'image/png',
  transparent: true,
  opacity: 0.82,
  minZoom: 12,
  maxZoom: 19,
  keepBuffer: 6,
  updateWhenZooming: false,
  errorTileUrl: TRANSPARENT_TILE,
  attribution: '&copy; Bank Danych o Lasach (Lasy Państwowe)'
});

const bdlOddzialy = L.tileLayer.wms(BDL_WMS_CONFIG.tilesUrl, {
  layers: '3',
  format: 'image/png',
  transparent: true,
  opacity: 0.6,
  minZoom: 11,
  maxZoom: 19,
  keepBuffer: 6,
  updateWhenZooming: false,
  errorTileUrl: TRANSPARENT_TILE
});

bdlOddzialy.addTo(map);
bdlWydzielenia.addTo(map);

// DOM Elements
const spotSelect = document.getElementById('spotSelect');
const seasonSelect = document.getElementById('seasonSelect');
const layerSelect = document.getElementById('layerSelect');
const zoomHintBanner = document.getElementById('zoomHintBanner');
const btnToggleBdl = document.getElementById('btnToggleBdl');
const btnLocateMe = document.getElementById('btnLocateMe');
const btnSaveCar = document.getElementById('btnSaveCar');
const carBtnText = document.getElementById('carBtnText');
const inspectorDrawer = document.getElementById('inspectorDrawer');
const drawerCloseBtn = document.getElementById('drawerCloseBtn');
const tabButtons = document.querySelectorAll('.tab-btn');
const tabPanes = document.querySelectorAll('.tab-pane');

// Parcel UI Elements
const parcelAddress = document.getElementById('parcelAddress');
const parcelSubtext = document.getElementById('parcelSubtext');
const statusBanner = document.getElementById('statusBanner');
const statusIcon = document.getElementById('statusIcon');
const statusText = document.getElementById('statusText');
const mushroomCardsList = document.getElementById('mushroomCardsList');
const radarCountBadge = document.getElementById('radarCountBadge');

// Stand UI Elements
const standSpeciesVal = document.getElementById('standSpeciesVal');
const standSpeciesLatin = document.getElementById('standSpeciesLatin');
const standAgeVal = document.getElementById('standAgeVal');
const standAgeCat = document.getElementById('standAgeCat');
const standHabitatVal = document.getElementById('standHabitatVal');
const standHabitatDesc = document.getElementById('standHabitatDesc');
const standAreaVal = document.getElementById('standAreaVal');
const standInspectorate = document.getElementById('standInspectorate');
const fullAddressText = document.getElementById('fullAddressText');

// Weather UI Elements
const weatherRainVal = document.getElementById('weatherRainVal');
const weatherRainStatus = document.getElementById('weatherRainStatus');
const weatherTempVal = document.getElementById('weatherTempVal');

// Car Radar UI Elements
const compassArrow = document.getElementById('compassArrow');
const carDistanceText = document.getElementById('carDistanceText');
const carBearingText = document.getElementById('carBearingText');
const btnSetCarHere = document.getElementById('btnSetCarHere');
const btnCenterCar = document.getElementById('btnCenterCar');

// Populate Famous Spots Dropdown
FAMOUS_SPOTS.forEach(spot => {
  const opt = document.createElement('option');
  opt.value = spot.id;
  opt.textContent = `${spot.name} — ${spot.tag}`;
  spotSelect.appendChild(opt);
});

// Setup Spot Jumper Listener
spotSelect.addEventListener('change', (e) => {
  const spot = FAMOUS_SPOTS.find(s => s.id === e.target.value);
  if (spot) {
    map.flyTo([spot.lat, spot.lng], spot.zoom, { duration: 1.5 });
    setTimeout(() => {
      inspectCoordinates(L.latLng(spot.lat, spot.lng));
    }, 1600);
  }
});

// Setup Season Switcher
seasonSelect.addEventListener('change', (e) => {
  state.selectedMonth = parseInt(e.target.value, 10);
  if (state.currentParcel) {
    renderMushroomRadar();
  }
});

// Setup Layer Selector (Direct 1-click switcher)
layerSelect.addEventListener('change', (e) => {
  const selectedKey = e.target.value;
  if (!baseLayerInstances[selectedKey]) return;

  // Remove old layer
  map.removeLayer(baseLayerInstances[state.currentLayerKey]);
  
  // Add new layer
  baseLayerInstances[selectedKey].addTo(map);
  
  // Keep BDL WMS on top
  if (state.bdlLayerVisible) {
    bdlOddzialy.bringToFront();
    bdlWydzielenia.bringToFront();
  }
  
  state.currentLayerKey = selectedKey;
});

// Explicitly ensure satellite layer is selected on initial page load
if (layerSelect) {
  layerSelect.value = 'satellite';
}

// Zoom change listener: show advisory if zoomed out
map.on('zoomend', () => {
  const currentZoom = map.getZoom();
  if (currentZoom < 13) {
    zoomHintBanner.style.display = 'flex';
  } else {
    zoomHintBanner.style.display = 'none';
  }
});

// Toggle BDL WMS Overlay
btnToggleBdl.addEventListener('click', () => {
  state.bdlLayerVisible = !state.bdlLayerVisible;
  if (state.bdlLayerVisible) {
    bdlOddzialy.addTo(map);
    bdlWydzielenia.addTo(map);
    btnToggleBdl.classList.add('active');
    btnToggleBdl.innerHTML = `<span>🌲</span><span>Warstwa BDL (Włączona)</span>`;
  } else {
    map.removeLayer(bdlOddzialy);
    map.removeLayer(bdlWydzielenia);
    btnToggleBdl.classList.remove('active');
    btnToggleBdl.innerHTML = `<span>🌲</span><span>Warstwa BDL (Wyłączona)</span>`;
  }
});

// Tabs switching
tabButtons.forEach(btn => {
  btn.addEventListener('click', () => {
    tabButtons.forEach(b => b.classList.remove('active'));
    tabPanes.forEach(p => p.style.display = 'none');
    
    btn.classList.add('active');
    const targetId = btn.getAttribute('data-tab');
    document.getElementById(targetId).style.display = 'block';
    state.activeTab = targetId;

    if (targetId === 'tab-car') {
      updateCarDistance();
    }
  });
});

// Filter pills listener for mushroom radar
const filterPills = document.querySelectorAll('.mush-filter-pill');
filterPills.forEach(pill => {
  pill.addEventListener('click', () => {
    filterPills.forEach(p => p.classList.remove('active'));
    pill.classList.add('active');
    state.mushFilter = pill.getAttribute('data-filter');
    renderMushroomRadar();
  });
});

// Close drawer button
drawerCloseBtn.addEventListener('click', () => {
  inspectorDrawer.classList.remove('open');
});

// Map Click Handler -> Inspect Forest Parcel
map.on('click', (e) => {
  inspectCoordinates(e.latlng);
});

async function inspectCoordinates(latlng) {
  // Show click marker with pulse
  if (state.clickMarker) {
    map.removeLayer(state.clickMarker);
  }
  
  const customIcon = L.divIcon({
    className: 'radar-marker-container',
    html: `
      <div class="radar-marker-pulse"></div>
      <div style="width: 14px; height: 14px; background: #34d399; border: 2px solid #fff; border-radius: 50%; box-shadow: 0 0 12px #34d399;"></div>
    `,
    iconSize: [14, 14],
    iconAnchor: [7, 7]
  });

  state.clickMarker = L.marker(latlng, { icon: customIcon }).addTo(map);

  // Open drawer with loading feedback
  inspectorDrawer.classList.add('open');
  parcelAddress.textContent = 'Analiza wydzielenia BDL...';
  parcelSubtext.textContent = `Współrzędne: ${latlng.lat.toFixed(4)}, ${latlng.lng.toFixed(4)}`;
  mushroomCardsList.innerHTML = `<div style="text-align: center; padding: 30px; color: var(--text-muted);">
    <div style="font-size: 2rem; margin-bottom: 8px;">🌲</div>
    <div>Pobieranie parametrów drzewostanu z serwera Lasów Państwowych...</div>
  </div>`;

  try {
    const [parcel, weather] = await Promise.all([
      queryForestParcel(map, latlng),
      fetchRainfallData(latlng.lat, latlng.lng)
    ]);

    state.currentParcel = parcel;
    state.currentWeather = weather;

    renderParcelInfo(parcel, weather);
    renderMushroomRadar();
    updateCarDistance();
  } catch (err) {
    console.error('Inspection error:', err);
    parcelAddress.textContent = 'Błąd odczytu danych BDL';
    parcelSubtext.textContent = 'Spróbuj kliknąć inny obszar lasu.';
  }
}

function renderParcelInfo(parcel, weather) {
  if (!parcel.found || parcel.isMacro) {
    parcelAddress.textContent = parcel.inspectorate || 'Obszar poza LP';
    parcelSubtext.textContent = parcel.message || 'Brak szczegółowych danych wydzielenia.';
    statusBanner.className = 'status-pill-banner allowed';
    statusIcon.textContent = 'ℹ️';
    statusText.textContent = parcel.message || 'Przybliż mapę, aby wybrać wydzielenie.';

    // Reset Stand tab metrics
    standSpeciesVal.textContent = 'Brak danych';
    standSpeciesLatin.textContent = 'Gatunek nieokreślony';
    standAgeVal.textContent = '--';
    standAgeCat.textContent = 'Brak danych BDL';
    standHabitatVal.textContent = '--';
    standHabitatDesc.textContent = 'Teren poza PGL Lasy Państwowe';
    standAreaVal.textContent = '--';
    standInspectorate.textContent = parcel.inspectorate || 'Brak';
    fullAddressText.textContent = 'Brak adresu leśnego';
    return;
  }

  // Address and title
  parcelAddress.textContent = `${parcel.species.icon} ${parcel.species.namePl} (${parcel.age} lat)`;
  parcelSubtext.textContent = `${parcel.address} • ${parcel.inspectorate}`;
  fullAddressText.textContent = parcel.address;

  // Status banner
  const isForbidden = parcel.status.status === 'forbidden';
  statusBanner.className = `status-pill-banner ${isForbidden ? 'forbidden' : 'allowed'}`;
  statusIcon.textContent = isForbidden ? '⛔' : '✅';
  statusText.textContent = parcel.status.labelPl;

  // Stand tab metrics
  standSpeciesVal.textContent = `${parcel.species.icon} ${parcel.species.namePl} (${parcel.species.sharePercent}%)`;
  standSpeciesLatin.textContent = parcel.species.latin || 'Gatunek panujący';
  standAgeVal.textContent = `${parcel.age} lat`;
  standAgeCat.textContent = parcel.ageCategory;
  standHabitatVal.textContent = parcel.habitat.code;
  standHabitatDesc.textContent = parcel.habitat.namePl;
  standAreaVal.textContent = parcel.areaHa ? `${parcel.areaHa} ha` : 'Brak danych';
  standInspectorate.textContent = parcel.inspectorate;

  // Weather metrics
  weatherRainVal.textContent = `🌧️ ${weather.totalRainMm} mm`;
  weatherRainStatus.textContent = weather.moistureLabel;
  weatherRainStatus.style.color = weather.moistureBadgeColor;
  weatherTempVal.textContent = `🌡️ ${weather.avgTempC} °C`;
}

function renderMushroomRadar() {
  if (!state.currentParcel || !state.currentParcel.found || state.currentParcel.isMacro) {
    mushroomCardsList.innerHTML = `<div style="padding: 20px; color: var(--text-muted); text-align: center;">
      Wybierz konkretny wydzielony las na mapie, aby uruchomić Radar Grzybów.
    </div>`;
    return;
  }

  let results = matchMushrooms(state.currentParcel, state.currentWeather, state.selectedMonth);

  // Apply UI Filter
  if (state.mushFilter === 'high') {
    results = results.filter(r => r.probability >= 70);
  } else if (state.mushFilter === 'prime') {
    results = results.filter(r => r.mushroom.edibility.includes('Wybitny') || r.mushroom.edibility.includes('Wyborny'));
  }

  radarCountBadge.textContent = `${results.length} gatunków spełnia kryteria`;
  mushroomCardsList.innerHTML = '';

  if (results.length === 0) {
    mushroomCardsList.innerHTML = `<div style="padding: 24px; color: var(--text-muted); text-align: center;">
      Brak grzybów spełniających ten filtr dla tego drzewostanu.
    </div>`;
    return;
  }

  results.forEach(res => {
    const m = res.mushroom;
    const card = document.createElement('div');
    card.className = 'mushroom-card';
    
    // Lookalike warning block
    const lookalikeHtml = m.lookalike ? `
      <div class="lookalike-box" style="margin-top: 6px;">
        <span style="font-size: 1.1rem;">⚠️</span>
        <div>
          <strong>Uwaga na sobowtóra:</strong> ${m.lookalike.namePl} (<em>${m.lookalike.nameLat}</em>)<br />
          <span>${m.lookalike.warningPl}</span>
        </div>
      </div>
    ` : '';

    card.innerHTML = `
      <div class="mushroom-card-top">
        <div class="mush-title-block">
          <span class="mush-name-pl">${m.namePl}</span>
          <span class="mush-name-lat">${m.nameLat} • <span style="color: ${m.edibilityColor};">${m.edibility}</span></span>
        </div>
        <div class="prob-badge">
          <span class="prob-number" style="color: ${res.chanceColor};">${res.probability}%</span>
          <span class="prob-text" style="color: ${res.chanceColor};">${res.chanceCategory}</span>
        </div>
      </div>

      <div class="prob-progress-bar">
        <div class="prob-progress-fill" style="width: ${res.probability}%; background: ${res.chanceColor};"></div>
      </div>

      <div class="mush-card-reasons">
        ${res.matchReasons.map(r => `<span class="reason-tag positive">✓ ${r}</span>`).join('')}
        ${res.mismatchReasons.map(r => `<span class="reason-tag">✗ ${r}</span>`).join('')}
      </div>

      <div class="mush-card-expand-toggle">
        <span>📖 Zobacz biologię i wskazówki</span>
        <span class="arrow-indicator">▾</span>
      </div>

      <div class="mush-expanded-details hidden">
        <p><strong>Charakterystyka:</strong> ${m.descriptionPl}</p>
        <p><strong>Gdzie szukać:</strong> ${m.tipsPl}</p>
        ${lookalikeHtml}
      </div>
    `;

    // Toggle accordion details
    const toggleBtn = card.querySelector('.mush-card-expand-toggle');
    const details = card.querySelector('.mush-expanded-details');
    const arrow = card.querySelector('.arrow-indicator');

    toggleBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      const isHidden = details.classList.contains('hidden');
      if (isHidden) {
        details.classList.remove('hidden');
        arrow.textContent = '▴';
        toggleBtn.querySelector('span:first-child').textContent = 'Zwiń szczegóły';
      } else {
        details.classList.add('hidden');
        arrow.textContent = '▾';
        toggleBtn.querySelector('span:first-child').textContent = '📖 Zobacz biologię i wskazówki';
      }
    });

    mushroomCardsList.appendChild(card);
  });
}

// Car Radar / Parking Spot Setup
btnSaveCar.addEventListener('click', () => {
  const center = map.getCenter();
  parkingRadar.saveCarLocation(center);
  updateCarMarker();
  updateCarDistance();
  carBtnText.textContent = 'Auto zapisane!';
  setTimeout(() => carBtnText.textContent = 'Zmień auto', 2000);
});

btnSetCarHere.addEventListener('click', () => {
  if (state.currentParcel && state.currentParcel.latlng) {
    parkingRadar.saveCarLocation(state.currentParcel.latlng);
    updateCarMarker();
    updateCarDistance();
    alert('📍 Pozycja zaparkowanego auta została zapisana w tym punkcie lasu!');
  } else {
    parkingRadar.saveCarLocation(map.getCenter());
    updateCarMarker();
    updateCarDistance();
    alert('📍 Pozycja auta zapisana w centrum mapy!');
  }
});

btnCenterCar.addEventListener('click', () => {
  const carLoc = parkingRadar.loadSavedCar();
  if (carLoc) {
    map.flyTo([carLoc.lat, carLoc.lng], 16, { duration: 1.2 });
  } else {
    alert('Najpierw zapisz pozycję auta przyciskiem "Zapisz auto"!');
  }
});

function updateCarMarker() {
  const carLoc = parkingRadar.loadSavedCar();
  if (!carLoc) return;

  if (state.carMarker) {
    map.removeLayer(state.carMarker);
  }

  const carIcon = L.divIcon({
    className: 'car-marker-container',
    html: `<div style="font-size: 1.8rem; filter: drop-shadow(0 0 10px #fbbf24); cursor: pointer;" title="Twoje zaparkowane auto">🚗</div>`,
    iconSize: [28, 28],
    iconAnchor: [14, 14]
  });

  state.carMarker = L.marker([carLoc.lat, carLoc.lng], { icon: carIcon }).addTo(map);
  state.carMarker.bindPopup('<b>🚗 Twoje zaparkowane auto</b><br>Nawigator wskazuje drogę powrotną.');
}

function updateCarDistance() {
  const carLoc = parkingRadar.loadSavedCar();
  const currentPos = state.currentParcel?.latlng || map.getCenter();

  if (!carLoc) {
    carDistanceText.textContent = '-- m';
    carBearingText.textContent = 'Brak zapisanego auta. Kliknij przycisk poniżej.';
    compassArrow.style.transform = 'rotate(0deg)';
    return;
  }

  const nav = parkingRadar.calculateDistanceAndBearing(currentPos, carLoc);
  if (nav) {
    carDistanceText.textContent = nav.humanDistance;
    carBearingText.textContent = `Azymut: ${nav.bearingDegrees}° • Marsz: ~${nav.walkTimeMinutes} min`;
    compassArrow.style.transform = `rotate(${nav.bearingDegrees}deg)`;
  }
}

// Locate Me Button
btnLocateMe.addEventListener('click', () => {
  if (navigator.geolocation) {
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        const latlng = L.latLng(pos.coords.latitude, pos.coords.longitude);
        map.flyTo(latlng, 15, { duration: 1.5 });
        setTimeout(() => inspectCoordinates(latlng), 1600);
      },
      () => {
        const fallback = L.latLng(52.050, 21.250);
        map.flyTo(fallback, 15, { duration: 1.2 });
        setTimeout(() => inspectCoordinates(fallback), 1300);
      }
    );
  }
});

// Check for previously saved car on load
updateCarMarker();

// Initial welcome load: automatically inspect a prime mushroom parcel in Celestynów
setTimeout(() => {
  inspectCoordinates(L.latLng(52.050, 21.250));
}, 1000);

console.log('🌲 GrzybMap Polska Proof of Concept initialized successfully with audited layers!');
