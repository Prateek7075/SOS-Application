class SosHistoryItem {
  const SosHistoryItem({
    required this.id,
    required this.status,
    required this.networkMode,
    required this.initialLatitude,
    required this.initialLongitude,
    required this.createdAt,
    this.cancelledAt,
    this.startingLatitude,
    this.startingLongitude,
    this.lastUpdatedLatitude,
    this.lastUpdatedLongitude,
    this.lastUpdatedGoogleMapsUrl,
    this.lastUpdatedAt,
  });

  final int id;
  final String status;
  final String networkMode;

  final double? initialLatitude;
  final double? initialLongitude;

  final double? startingLatitude;
  final double? startingLongitude;

  final double? lastUpdatedLatitude;
  final double? lastUpdatedLongitude;
  final String? lastUpdatedGoogleMapsUrl;
  final DateTime? lastUpdatedAt;

  final DateTime createdAt;
  final DateTime? cancelledAt;

  static double? parseDoubleValue(dynamic value) {
    if (value == null) {
      return null;
    }

    return double.tryParse(value.toString());
  }

  static DateTime? parseDateTimeValue(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return null;
    }

    return DateTime.tryParse(value.toString());
  }

  factory SosHistoryItem.fromJson(Map<String, dynamic> json) {
    final startingLocation = json['starting_location'] as Map<String, dynamic>?;
    final lastUpdatedLocation =
    json['last_updated_location'] as Map<String, dynamic>?;

    final initialLatitude = parseDoubleValue(json['initial_latitude']);
    final initialLongitude = parseDoubleValue(json['initial_longitude']);

    return SosHistoryItem(
      id: int.parse(json['id'].toString()),
      status: json['status']?.toString() ?? 'unknown',
      networkMode: json['network_mode']?.toString() ?? 'Unknown',

      initialLatitude: initialLatitude,
      initialLongitude: initialLongitude,

      startingLatitude: parseDoubleValue(
        startingLocation?['latitude'],
      ) ??
          initialLatitude,
      startingLongitude: parseDoubleValue(
        startingLocation?['longitude'],
      ) ??
          initialLongitude,

      lastUpdatedLatitude: parseDoubleValue(
        lastUpdatedLocation?['latitude'],
      ),
      lastUpdatedLongitude: parseDoubleValue(
        lastUpdatedLocation?['longitude'],
      ),
      lastUpdatedGoogleMapsUrl:
      lastUpdatedLocation?['google_maps_url']?.toString(),
      lastUpdatedAt: parseDateTimeValue(
        lastUpdatedLocation?['updated_at'],
      ),

      createdAt: parseDateTimeValue(json['created_at']) ?? DateTime.now(),
      cancelledAt: parseDateTimeValue(json['cancelled_at']),
    );
  }
}