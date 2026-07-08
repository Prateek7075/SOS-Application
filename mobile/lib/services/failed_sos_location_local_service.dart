import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PendingSosLocationUpdate {
  const PendingSosLocationUpdate({
    required this.localId,
    required this.sosEventId,
    required this.trackingToken,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.batteryPercentage,
    required this.createdAt,
  });

  final String localId;
  final int sosEventId;
  final String trackingToken;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final int? batteryPercentage;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return {
      'local_id': localId,
      'sos_event_id': sosEventId,
      'tracking_token': trackingToken,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'battery_percentage': batteryPercentage,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory PendingSosLocationUpdate.fromJson(Map<String, dynamic> json) {
    return PendingSosLocationUpdate(
      localId: json['local_id'].toString(),
      sosEventId: int.parse(json['sos_event_id'].toString()),
      trackingToken: json['tracking_token'].toString(),
      latitude: double.parse(json['latitude'].toString()),
      longitude: double.parse(json['longitude'].toString()),
      accuracy: json['accuracy'] == null
          ? null
          : double.tryParse(json['accuracy'].toString()),
      batteryPercentage: json['battery_percentage'] == null
          ? null
          : int.tryParse(json['battery_percentage'].toString()),
      createdAt: DateTime.tryParse(json['created_at'].toString()) ??
          DateTime.now(),
    );
  }
}

class FailedSosLocationLocalService {
  static const int _maxSavedUpdates = 200;

  String get _storageKey {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'guest';

    return 'failed_sos_location_updates_$userId';
  }

  Future<List<PendingSosLocationUpdate>> getPendingUpdates() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    final rawJson = prefs.getString(_storageKey);

    if (rawJson == null || rawJson.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(rawJson) as List;

      return decoded
          .map((item) {
        return PendingSosLocationUpdate.fromJson(
          item as Map<String, dynamic>,
        );
      })
          .where((item) {
        return item.sosEventId > 0 && item.trackingToken.isNotEmpty;
      })
          .toList();
    } catch (_) {
      await clearAll();
      return [];
    }
  }

  Future<void> save(PendingSosLocationUpdate update) async {
    final prefs = await SharedPreferences.getInstance();

    final pendingUpdates = await getPendingUpdates();

    pendingUpdates.add(update);

    final trimmedUpdates = pendingUpdates.length > _maxSavedUpdates
        ? pendingUpdates.sublist(pendingUpdates.length - _maxSavedUpdates)
        : pendingUpdates;

    await prefs.setString(
      _storageKey,
      jsonEncode(
        trimmedUpdates.map((item) => item.toJson()).toList(),
      ),
    );
  }

  Future<void> remove(String localId) async {
    final prefs = await SharedPreferences.getInstance();

    final pendingUpdates = await getPendingUpdates();

    final updatedList = pendingUpdates.where((item) {
      return item.localId != localId;
    }).toList();

    await prefs.setString(
      _storageKey,
      jsonEncode(
        updatedList.map((item) => item.toJson()).toList(),
      ),
    );
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_storageKey);
  }
}