class SosEvent {
  const SosEvent({
    required this.id,
    required this.status,
    required this.initialLatitude,
    required this.initialLongitude,
    required this.trackingToken,
    required this.trackingUrl,
  });

  final int id;
  final String status;
  final double initialLatitude;
  final double initialLongitude;
  final String trackingToken;
  final String trackingUrl;

  factory SosEvent.fromJson(Map<String, dynamic> json) {
    final event = json['data']['sos_event'];

    return SosEvent(
      id: event['id'],
      status: event['status'],
      initialLatitude: double.parse(event['initial_latitude'].toString()),
      initialLongitude: double.parse(event['initial_longitude'].toString()),
      trackingToken: event['tracking_token'],
      trackingUrl: json['data']['tracking_url'],
    );
  }
}