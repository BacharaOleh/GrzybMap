import 'dart:convert';

/// Immutable model representing a private, user-saved secret foraging spot.
///
/// Stores find details, location coordinates, quantity, and notes.
/// 100% offline and stored locally on the user's device for complete privacy.
class ForagingSpot {
  final String id;
  final String title;
  final String mushroomId;
  final String mushroomName;
  final String mushroomEmoji;
  final double quantityAmount;
  final String quantityUnit; // 'kg' or 'szt.'
  final double latitude;
  final double longitude;
  final DateTime foundAt;
  final String notes;
  final String? forestParcelId;
  final String? photoPath;

  const ForagingSpot({
    required this.id,
    required this.title,
    required this.mushroomId,
    required this.mushroomName,
    required this.mushroomEmoji,
    required this.quantityAmount,
    required this.quantityUnit,
    required this.latitude,
    required this.longitude,
    required this.foundAt,
    this.notes = '',
    this.forestParcelId,
    this.photoPath,
  });

  String get humanQuantity {
    final formatted = quantityAmount == quantityAmount.roundToDouble()
        ? quantityAmount.toInt().toString()
        : quantityAmount.toStringAsFixed(1);
    return '$formatted $quantityUnit';
  }

  String get formattedDate {
    final day = foundAt.day.toString().padLeft(2, '0');
    final month = foundAt.month.toString().padLeft(2, '0');
    final year = foundAt.year.toString();
    final hour = foundAt.hour.toString().padLeft(2, '0');
    final minute = foundAt.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute';
  }

  ForagingSpot copyWith({
    String? id,
    String? title,
    String? mushroomId,
    String? mushroomName,
    String? mushroomEmoji,
    double? quantityAmount,
    String? quantityUnit,
    double? latitude,
    double? longitude,
    DateTime? foundAt,
    String? notes,
    String? forestParcelId,
    String? photoPath,
  }) {
    return ForagingSpot(
      id: id ?? this.id,
      title: title ?? this.title,
      mushroomId: mushroomId ?? this.mushroomId,
      mushroomName: mushroomName ?? this.mushroomName,
      mushroomEmoji: mushroomEmoji ?? this.mushroomEmoji,
      quantityAmount: quantityAmount ?? this.quantityAmount,
      quantityUnit: quantityUnit ?? this.quantityUnit,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      foundAt: foundAt ?? this.foundAt,
      notes: notes ?? this.notes,
      forestParcelId: forestParcelId ?? this.forestParcelId,
      photoPath: photoPath ?? this.photoPath,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'mushroomId': mushroomId,
      'mushroomName': mushroomName,
      'mushroomEmoji': mushroomEmoji,
      'quantityAmount': quantityAmount,
      'quantityUnit': quantityUnit,
      'latitude': latitude,
      'longitude': longitude,
      'foundAt': foundAt.toIso8601String(),
      'notes': notes,
      'forestParcelId': forestParcelId,
      'photoPath': photoPath,
    };
  }

  factory ForagingSpot.fromMap(Map<String, dynamic> map) {
    return ForagingSpot(
      id: map['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: map['title'] as String? ?? 'Moja miejscówka',
      mushroomId: map['mushroomId'] as String? ?? 'borowik_szlachetny',
      mushroomName: map['mushroomName'] as String? ?? 'Borowik szlachetny',
      mushroomEmoji: map['mushroomEmoji'] as String? ?? '🍄',
      quantityAmount: (map['quantityAmount'] as num?)?.toDouble() ?? 1.0,
      quantityUnit: map['quantityUnit'] as String? ?? 'kg',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      foundAt: map['foundAt'] != null
          ? DateTime.tryParse(map['foundAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      notes: map['notes'] as String? ?? '',
      forestParcelId: map['forestParcelId'] as String?,
      photoPath: map['photoPath'] as String?,
    );
  }

  String toJson() => json.encode(toMap());

  factory ForagingSpot.fromJson(String source) =>
      ForagingSpot.fromMap(json.decode(source) as Map<String, dynamic>);
}
