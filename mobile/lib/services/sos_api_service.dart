import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/sos_event.dart';
import '../models/sos_history_item.dart';
import 'authenticated_api_service.dart';
import 'offline_sos_local_service.dart';
import 'sos_history_local_service.dart';

class SosApiService {
  static const String baseUrl = AppConfig.apiBaseUrl;

  final AuthenticatedApiService _authenticatedApiService =
      AuthenticatedApiService();

  final SosHistoryLocalService _sosHistoryLocalService =
      SosHistoryLocalService();

  Map<String, String> getPublicHeaders() {
    return {'Accept': 'application/json', 'Content-Type': 'application/json'};
  }

  Future<SosEvent> startSos({
    required double latitude,
    required double longitude,
    required String networkMode,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/sos/start'),
      headers: await _authenticatedApiService.getAuthHeaders(),
      body: jsonEncode({
        'latitude': latitude,
        'longitude': longitude,
        'network_mode': networkMode,
      }),
    );

    await _authenticatedApiService.handleUnauthorized(response.statusCode);

    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception(
        'Failed to start SOS: ${response.statusCode} ${response.body}',
      );
    }

    final decodedBody = jsonDecode(response.body) as Map<String, dynamic>;

    final sosEventJson =
        decodedBody['data']['sos_event'] as Map<String, dynamic>;

    final trackingToken = sosEventJson['tracking_token'].toString();

    decodedBody['data']['tracking_url'] =
        '${AppConfig.backendBaseUrl}/track/${Uri.encodeComponent(trackingToken)}';

    return SosEvent.fromJson(decodedBody);
  }

  Future<void> sendLocationUpdate({
    required int sosEventId,
    required String trackingToken,
    required double latitude,
    required double longitude,
    double? accuracy,
    int? batteryPercentage,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/sos/$sosEventId/location'),
      headers: {...getPublicHeaders(), 'X-SOS-Tracking-Token': trackingToken},
      body: jsonEncode({
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'battery_percentage': batteryPercentage,
      }),
    );

    if (response.statusCode != 201) {
      throw Exception(
        'Failed to send location update: '
        '${response.statusCode} ${response.body}',
      );
    }
  }

  Future<SosEvent?> getActiveSos() async {
    final response = await http.get(
      Uri.parse('$baseUrl/sos/active'),
      headers: await _authenticatedApiService.getAuthHeaders(),
    );

    await _authenticatedApiService.handleUnauthorized(response.statusCode);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to get active SOS: ${response.statusCode} ${response.body}',
      );
    }

    final decodedBody = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decodedBody['data'] as Map<String, dynamic>;

    final hasActiveSos = data['has_active_sos'] == true;

    if (!hasActiveSos || data['sos_event'] == null) {
      return null;
    }

    final sosEventJson = data['sos_event'] as Map<String, dynamic>;
    final trackingToken = sosEventJson['tracking_token'].toString();

    final normalizedBody = {
      'success': true,
      'message': decodedBody['message'] ?? 'Active SOS found.',
      'data': {
        'was_existing_active_sos': true,
        'sos_event': sosEventJson,
        'tracking_url':
            '${AppConfig.backendBaseUrl}/track/${Uri.encodeComponent(trackingToken)}',
      },
    };

    return SosEvent.fromJson(normalizedBody);
  }

  Future<void> cancelSos({required int sosEventId}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/sos/$sosEventId/cancel'),
      headers: await _authenticatedApiService.getAuthHeaders(),
    );

    await _authenticatedApiService.handleUnauthorized(response.statusCode);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to cancel SOS: ${response.statusCode} ${response.body}',
      );
    }
  }

  Future<void> syncOfflineSos({required OfflineSosEvent event}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/sos/offline-sync'),
      headers: await _authenticatedApiService.getAuthHeaders(),
      body: jsonEncode(event.toJson()),
    );

    await _authenticatedApiService.handleUnauthorized(response.statusCode);

    if (response.statusCode != 201) {
      throw Exception(
        'Failed to sync offline SOS: ${response.statusCode} ${response.body}',
      );
    }
  }

  Future<List<SosHistoryItem>> getSosHistory() async {
    final response = await http.get(
      Uri.parse('$baseUrl/sos/history'),
      headers: await _authenticatedApiService.getAuthHeaders(),
    );

    await _authenticatedApiService.handleUnauthorized(response.statusCode);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load SOS history: ${response.statusCode} ${response.body}',
      );
    }

    final decodedBody = jsonDecode(response.body);
    final sosEventsJson = decodedBody['data']['sos_events'] as List;

    await _sosHistoryLocalService.saveRawHistory(sosEventsJson);

    return sosEventsJson.map((itemJson) {
      return SosHistoryItem.fromJson(
        Map<String, dynamic>.from(itemJson as Map),
      );
    }).toList();
  }

  Future<String?> getTrackingStatus({required String trackingToken}) async {
    final encodedToken = Uri.encodeComponent(trackingToken);

    final response = await http.get(
      Uri.parse('$baseUrl/public/track/$encodedToken'),
      headers: {'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      final decodedBody = jsonDecode(response.body);

      return decodedBody['data']['status'] as String?;
    }

    if (response.statusCode == 404 || response.statusCode == 410) {
      return null;
    }

    throw Exception('Could not verify SOS status: ${response.statusCode}');
  }
}
