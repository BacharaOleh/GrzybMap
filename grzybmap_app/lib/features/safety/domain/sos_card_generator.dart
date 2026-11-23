import 'package:latlong2/latlong.dart';
import '../../parcel_inspector/domain/models.dart';
import '../../navigation/service/parking_service.dart';

/// Formats and structures emergency rescue information in Polish forest environments.
/// Tailored specifically for reporting to emergency dispatchers (112, GOPR) and
/// Polish State Forest services (Straż Leśna, Nadleśnictwo).
class SosCardGenerator {
  const SosCardGenerator._();

  /// Generates human-readable rescue dispatch text designed to be sent via SMS,
  /// WhatsApp, or read over the phone to emergency dispatchers.
  static String generateRescueText({
    required LatLng? location,
    required ForestParcel? parcel,
    required ParkingNavigation? carNavigation,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('🆘 POMOC / MOJA POZYCJA W LESIE');
    buffer.writeln('--------------------------------');

    if (parcel != null && parcel.address.isNotEmpty) {
      buffer.writeln('📍 Adres leśny (BDL): ${parcel.address}');
      if (parcel.subareaId.isNotEmpty) {
        buffer.writeln('🏷️ Wydzielenie / Oddział: ${parcel.subareaId}');
      }
    } else {
      buffer.writeln('📍 Teren leśny (brak numeru wydzielenia)');
    }

    if (location != null) {
      buffer.writeln(
        '🧭 Współrzędne GPS: ${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}',
      );
      buffer.writeln(
        '🗺️ Link do mapy: https://maps.google.com/?q=${location.latitude.toStringAsFixed(5)},${location.longitude.toStringAsFixed(5)}',
      );
    } else {
      buffer.writeln('🧭 Współrzędne GPS: Oczekiwanie na sygnał satelity...');
    }

    if (carNavigation != null) {
      buffer.writeln(
        '🚗 Auto: ${carNavigation.humanDistance} (${carNavigation.cardinalDirection}, azymut ${carNavigation.bearingDegrees.round()}°)',
      );
    }

    buffer.writeln('--------------------------------');
    buffer.write('Wiadomość z GrzybMap Polska');

    return buffer.toString();
  }

  /// Generates short SMS suitable for 112 / rescue dispatch (under 160 characters).
  static String generateSmsMessage({
    required LatLng? location,
    required ForestParcel? parcel,
  }) {
    final buffer = StringBuffer('POTRZEBUJE POMOCY W LESIE! ');
    if (parcel != null && parcel.inspectorate.isNotEmpty) {
      buffer.write('Nadl: ${parcel.inspectorate}, ');
    }
    if (parcel != null && parcel.subareaId.isNotEmpty) {
      buffer.write('Oddz: ${parcel.subareaId}, ');
    }
    if (location != null) {
      buffer.write(
        'Wspolrzedne: ${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}',
      );
    }
    return buffer.toString();
  }

  /// Formats GPS coordinates as Decimal Degrees and DMS for dispatcher communication.
  static String formatCoordinates(LatLng point) {
    return '${point.latitude.toStringAsFixed(5)}° N, ${point.longitude.toStringAsFixed(5)}° E';
  }
}
