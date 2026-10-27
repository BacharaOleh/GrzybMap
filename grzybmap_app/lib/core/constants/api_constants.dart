/// API Constants & Endpoints for GrzybMap Polska
library;

class ApiConstants {
  // Bank Danych o Lasach (Lasy Państwowe)
  static const String bdlWmsUrl =
      'https://mapserver.bdl.lasy.gov.pl/ArcGIS/services/WMS_BDL/MapServer/WMSServer';
  static const String bdlCleanExportUrl =
      'https://mapserver.bdl.lasy.gov.pl/ArcGIS/rest/services/WMS_BDL/MapServer/export?f=image&format=png32&transparent=true&bboxSR=3857&imageSR=3857&size=256,256&dynamicLayers=%5B%7B%22id%22%3A5%2C%22source%22%3A%7B%22type%22%3A%22mapLayer%22%2C%22mapLayerId%22%3A5%7D%2C%22drawingInfo%22%3A%7B%22showLabels%22%3Afalse%7D%7D%5D&';
  static const String bdlQueryUrl =
      'https://mapserver.bdl.lasy.gov.pl/ArcGIS/rest/services/WMS_BDL/MapServer/5/query';
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
