/**
 * Map Configuration & Layers for GrzybMap Polska
 */

export const MAP_CONFIG = {
  initialCenter: [52.050, 21.250], // Lasy Celestynowskie
  initialZoom: 15,
  minZoom: 6,
  maxZoom: 19,
  maxBounds: [
    [48.5, 13.5], // South-West of Poland
    [55.5, 24.5]  // North-East of Poland
  ]
};

// 1x1 transparent GIF to prevent broken tile icons or black boxes
export const TRANSPARENT_TILE = 'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7';

export const BASE_LAYERS = {
  satellite: {
    id: 'satellite',
    name: 'Satelita (Esri Global)',
    icon: '🛰️',
    url: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    maxNativeZoom: 18, // Polish rural forest imagery has native tiles up to 18; Leaflet cleanly upscales to 19 without missing tiles
    maxZoom: 19,
    attribution: 'Tiles &copy; Esri &mdash; Earthstar Geographics'
  },
  geoportal: {
    id: 'geoportal',
    name: 'Ortofoto RP (Geoportal.gov.pl)',
    icon: '🇵🇱',
    type: 'wms',
    url: 'https://mapy.geoportal.gov.pl/wss/service/PZGIK/ORTO/WMS/StandardResolution',
    wmsParams: {
      layers: 'Raster',
      format: 'image/jpeg',
      transparent: false,
      version: '1.3.0',
      maxNativeZoom: 19,
      maxZoom: 19,
      attribution: '&copy; Główny Urząd Geodezji i Kartografii (GUGiK)'
    }
  },
  topo: {
    id: 'topo',
    name: 'Topo & Szlaki (OpenTopoMap)',
    icon: '⛰️',
    url: 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
    subdomains: ['a', 'b', 'c'],
    maxNativeZoom: 17, // OpenTopoMap server max zoom is 17; Leaflet automatically upscales to 19 without black tiles!
    maxZoom: 19,
    attribution: 'Map data: &copy; OpenStreetMap contributors, SRTM | Map style: &copy; OpenTopoMap (CC-BY-SA)'
  },
  dark: {
    id: 'dark',
    name: 'Ciemna (Esri Dark Canvas)',
    icon: '🌙',
    // Authentic Esri World Dark Gray Base: 100% public, NO API KEY required, NO watermarks!
    url: 'https://services.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}',
    maxNativeZoom: 18,
    maxZoom: 19,
    attribution: 'Tiles &copy; Esri &mdash; DeLorme, NAVTEQ'
  },
  osm: {
    id: 'osm',
    name: 'Standardowa (OpenStreetMap)',
    icon: '🗺️',
    url: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
    subdomains: ['a', 'b', 'c'],
    maxNativeZoom: 19,
    maxZoom: 19,
    attribution: '&copy; OpenStreetMap contributors'
  }
};

export const BDL_WMS_CONFIG = {
  tilesUrl: 'https://mapserver.bdl.lasy.gov.pl/ArcGIS/services/WMS_BDL/MapServer/WMSServer',
  featureInfoUrl: '/api/bdl/ArcGIS/services/WMS_BDL/MapServer/WMSServer',
  restrictionsTilesUrl: 'https://mapserver.bdl.lasy.gov.pl/ArcGIS/services/WMS_zakazy_wstepu_do_lasu/MapServer/WMSServer',
  
  layers: {
    wydzielenia: {
      id: '1',
      title: 'Wydzielenia PGL LP (Wydzielenia leśne)',
      opacity: 0.85,
      minZoom: 12,
      maxZoom: 19
    },
    oddzialy: {
      id: '3',
      title: 'Oddziały leśne (Kwadraty)',
      opacity: 0.65,
      minZoom: 11,
      maxZoom: 19
    }
  }
};
