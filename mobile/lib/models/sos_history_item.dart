class SosHistoryItem {
  const SosHistoryItem({
    required this.id,
    required this.status,
    required this.initialLatitude,
    required this.initialLongitude,
    required this.networkMode,
    required this.expiresAt,
    required this.cancelledAt,
    required this.createdAt,
  });

  final int id;
  final String status;
  final double initialLatitude;
  final double initialLongitude;
  final String networkMode;
  final DateTime? expiresAt;
  final DateTime? cancelledAt;
  final DateTime createdAt;

  factory SosHistoryItem.fromJson(Map<String, dynamic> json) {
    return SosHistoryItem(
      id: json['id'],
      status: json['status'],
      initialLatitude: double.parse(json['initial_latitude'].toString()),
      initialLongitude: double.parse(json['initial_longitude'].toString()),
      networkMode: json['network_mode'],
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.parse(json['expires_at']).toLocal(),
      cancelledAt: json['cancelled_at'] == null
          ? null
          : DateTime.parse(json['cancelled_at']).toLocal(),
      createdAt: DateTime.parse(json['created_at']).toLocal(),
    );
  }
}