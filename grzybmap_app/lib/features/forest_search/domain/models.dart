import 'package:latlong2/latlong.dart';

/// Represents a search result for a Polish forest, place, or preset.
class ForestSearchResult {
  final String id;
  final String displayName;
  final String shortName;
  final String category; // 'forest', 'preset', 'city', 'administrative'
  final double lat;
  final double lon;
  final String? subtitle;
  final String iconEmoji;

  const ForestSearchResult({
    required this.id,
    required this.displayName,
    required this.shortName,
    required this.category,
    required this.lat,
    required this.lon,
    this.subtitle,
    this.iconEmoji = '🌲',
  });

  LatLng get latLng => LatLng(lat, lon);

  bool get isForest => category == 'forest' || category == 'preset';
}

/// Curated legendary Polish mushroom forests for instant navigation.
class ForestPreset {
  final String id;
  final String name;
  final String subtitle;
  final double lat;
  final double lon;
  final String emoji;
  final List<String> famousMushrooms;

  const ForestPreset({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.lat,
    required this.lon,
    required this.emoji,
    required this.famousMushrooms,
  });

  ForestSearchResult toSearchResult() {
    return ForestSearchResult(
      id: id,
      displayName: '$name ($subtitle)',
      shortName: name,
      category: 'preset',
      lat: lat,
      lon: lon,
      subtitle: subtitle,
      iconEmoji: emoji,
    );
  }

  static const List<ForestPreset> all = [
    ForestPreset(
      id: 'bory_tucholskie',
      name: 'Bory Tucholskie',
      subtitle: 'Bory sosnowe • Borowiki, Maślaki',
      lat: 53.600,
      lon: 18.000,
      emoji: '🌲',
      famousMushrooms: ['Borowik szlachetny', 'Maślak zwyczajny', 'Podgrzybek brunatny'],
    ),
    ForestPreset(
      id: 'puszcza_kampinoska',
      name: 'Puszcza Kampinoska',
      subtitle: 'Piaszczyste wydmy • Podgrzybki',
      lat: 52.320,
      lon: 20.650,
      emoji: '🦌',
      famousMushrooms: ['Podgrzybek brunatny', 'Koźlarz babka', 'Czubajka kania'],
    ),
    ForestPreset(
      id: 'puszcza_notecka',
      name: 'Puszcza Notecka',
      subtitle: 'Wielkie wydmowe bory sosnowe',
      lat: 52.750,
      lon: 15.900,
      emoji: '🪵',
      famousMushrooms: ['Podgrzybek brunatny', 'Gąska zielona', 'Borowik sosnowy'],
    ),
    ForestPreset(
      id: 'puszcza_bialowieska',
      name: 'Puszcza Białowieska',
      subtitle: 'Pradawny las liściasty i mieszany',
      lat: 52.720,
      lon: 23.650,
      emoji: '👑',
      famousMushrooms: ['Borowik szlachetny', 'Pieprznik jadalny', 'Opieńka miodowa'],
    ),
    ForestPreset(
      id: 'lasy_janowskie',
      name: 'Lasy Janowskie',
      subtitle: 'Bory iglaste i torfowiska • Rydze',
      lat: 50.620,
      lon: 22.380,
      emoji: '🌿',
      famousMushrooms: ['Mleczaj rydz', 'Borowik szlachetny', 'Kurka'],
    ),
    ForestPreset(
      id: 'puszcza_piska',
      name: 'Puszcza Piska',
      subtitle: 'Kraina Wielkich Jezior • Kurki',
      lat: 53.600,
      lon: 21.600,
      emoji: '💧',
      famousMushrooms: ['Pieprznik jadalny', 'Borowik szlachetny', 'Koźlarz czerwony'],
    ),
    ForestPreset(
      id: 'bory_dolnoslaskie',
      name: 'Bory Dolnośląskie',
      subtitle: 'Największy zwarty bór w Polsce',
      lat: 51.350,
      lon: 15.400,
      emoji: '⛰️',
      famousMushrooms: ['Borowik sosnowy', 'Podgrzybek brunatny', 'Rydz'],
    ),
    ForestPreset(
      id: 'puszcza_knyszynska',
      name: 'Puszcza Knyszyńska',
      subtitle: 'Dolina Supraśli • Sosny supraskie',
      lat: 53.220,
      lon: 23.350,
      emoji: '🍄',
      famousMushrooms: ['Podgrzybek brunatny', 'Borowik szlachetny', 'Rydz'],
    ),
  ];
}
