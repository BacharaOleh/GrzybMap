/// API Constants & Endpoints for GrzybMap Polska
library;

class ApiConstants {
  // Bank Danych o Lasach (Lasy Państwowe)
  static const String bdlWmsUrl =
      'https://mapserver.bdl.lasy.gov.pl/ArcGIS/services/WMS_BDL/MapServer/WMSServer';
  static const String bdlRestrictionsWmsUrl =
      'https://mapserver.bdl.lasy.gov.pl/ArcGIS/services/WMS_zakazy_wstepu_do_lasu/MapServer/WMSServer';

  // Base map tile servers
  static const String esriSatelliteUrl =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
  static const String esriDarkCanvasUrl =
      'https://services.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}';
  static const String openTopoMapUrl =
      'https://tile.opentopomap.org/{z}/{x}/{y}.png';
  static const String openStreetMapUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String geoportalOrtofotoUrl =
      'https://mapy.geoportal.gov.pl/wss/service/PZGIK/ORTO/WMS/StandardResolution';

  // Open-Meteo Weather API
  static String openMeteoRainUrl(double lat, double lng) {
    final roundedLat = lat.toStringAsFixed(3);
    final roundedLng = lng.toStringAsFixed(3);
    return 'https://api.open-meteo.com/v1/forecast?latitude=$roundedLat&longitude=$roundedLng&daily=precipitation_sum,temperature_2m_max&hourly=soil_temperature_6cm,soil_moisture_0_to_1cm&past_days=14&forecast_days=1&timezone=Europe%2FWarsaw';
  }
}
