class SosEvent {
  const SosEvent({
    required this.id,
    required this.status,
    required this.initialLatitude,
    required this.initialLongitude,
    required this.trackingToken,
    required this.trackingUrl,
    required this.wasExistingActiveSos,
  });

  final int id;
  final String status;
  final double initialLatitude;
  final double initialLongitude;
  final String trackingToken;
  final String trackingUrl;
  final bool wasExistingActiveSos;

  factory SosEvent.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    final event = data['sos_event'] as Map<String, dynamic>;

    return SosEvent(
      id: int.parse(event['id'].toString()),
      status: event['status'].toString(),
      initialLatitude: double.parse(event['initial_latitude'].toString()),
      initialLongitude: double.parse(event['initial_longitude'].toString()),
      trackingToken: event['tracking_token'].toString(),
      trackingUrl: data['tracking_url'].toString(),
      wasExistingActiveSos: data['was_existing_active_sos'] == true,
    );
  }
}