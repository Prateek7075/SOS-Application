import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/sos_event.dart';
import '../models/sos_history_item.dart';

class SosApiService {
  static const String baseUrl = AppConfig.apiBaseUrl;

  Future<Map<String, String>> getAuthHeaders() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser == null) {
      throw Exception('User is not logged in');
    }

    final idToken = await firebaseUser.getIdToken();

    if (idToken == null || idToken.isEmpty) {
      throw Exception('Firebase ID token is unavailable');
    }

    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $idToken',
    };
  }

  Map<String, String> getPublicHeaders() {
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
  }

  Future<SosEvent> startSos({
    required double latitude,
    required double longitude,
    required String networkMode,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/sos/start'),
      headers: await getAuthHeaders(),
      body: jsonEncode({
        'latitude': latitude,
        'longitude': longitude,
        'network_mode': networkMode,
      }),
    );

    if (response.statusCode != 201) {
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
      headers: {
        ...getPublicHeaders(),
        'X-SOS-Tracking-Token': trackingToken,
      },
      body: jsonEncode({
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'battery_percentage': batteryPercentage,
      }),
    );

    if (response.statusCode != 201) {
      throw Exception(
        'Failed to send location update: ${response.statusCode} ${response.body}',
      );
    }
  }

  Future<void> cancelSos({
    required int sosEventId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/sos/$sosEventId/cancel'),
      headers: await getAuthHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to cancel SOS: ${response.statusCode} ${response.body}',
      );
    }
  }

  Future<List<SosHistoryItem>> getSosHistory() async {
    final response = await http.get(
      Uri.parse('$baseUrl/sos/history'),
      headers: await getAuthHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load SOS history: ${response.statusCode} ${response.body}',
      );
    }

    final decodedBody = jsonDecode(response.body);
    final sosEventsJson = decodedBody['data']['sos_events'] as List;

    return sosEventsJson.map((itemJson) {
      return SosHistoryItem.fromJson(itemJson);
    }).toList();
  }

  Future<String?> getTrackingStatus({
    required String trackingToken,
  }) async {
    final encodedToken = Uri.encodeComponent(trackingToken);

    final response = await http.get(
      Uri.parse('$baseUrl/public/track/$encodedToken'),
      headers: {
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final decodedBody = jsonDecode(response.body);

      return decodedBody['data']['status'] as String?;
    }

    if (response.statusCode == 404 || response.statusCode == 410) {
      return null;
    }

    throw Exception(
      'Could not verify SOS status: ${response.statusCode}',
    );
  }
}