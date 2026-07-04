import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineSosEvent {
  const OfflineSosEvent({
    required this.localId,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    this.batteryPercentage,
    this.networkMode = 'offline_sms',
    this.smsSentCount = 0,
    this.smsMessage,
  });

  final String localId;
  final double latitude;
  final double longitude;
  final DateTime createdAt;
  final int? batteryPercentage;
  final String networkMode;
  final int smsSentCount;
  final String? smsMessage;

  Map<String, dynamic> toJson() {
    return {
      'local_id': localId,
      'latitude': latitude,
      'longitude': longitude,
      'battery_percentage': batteryPercentage,
      'network_mode': networkMode,
      'sms_sent_count': smsSentCount,
      'sms_message': smsMessage,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory OfflineSosEvent.fromJson(Map<String, dynamic> json) {
    return OfflineSosEvent(
      localId: json['local_id']?.toString() ?? '',
      latitude: _parseDouble(json['latitude']) ?? 0,
      longitude: _parseDouble(json['longitude']) ?? 0,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      batteryPercentage: _parseInt(json['battery_percentage']),
      networkMode: json['network_mode']?.toString() ?? 'offline_sms',
      smsSentCount: _parseInt(json['sms_sent_count']) ?? 0,
      smsMessage: json['sms_message']?.toString(),
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}

class OfflineSosLocalService {
  static const String _legacyKey = 'offline_sos_events';

  String? get _currentUserId {
    return FirebaseAuth.instance.currentUser?.uid;
  }

  String? get _currentUserOfflineSosKey {
    final userId = _currentUserId;

    if (userId == null || userId.isEmpty) {
      return null;
    }

    return 'offline_sos_events_$userId';
  }

  Future<void> saveOfflineSos(OfflineSosEvent event) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _currentUserOfflineSosKey;

    if (key == null) {
      throw Exception('Cannot save offline SOS because user is not logged in');
    }

    final events = await getOfflineSosEvents();

    final alreadyExists = events.any((item) => item.localId == event.localId);

    if (!alreadyExists) {
      events.add(event);
    }

    final encodedEvents = events.map((item) {
      return jsonEncode(item.toJson());
    }).toList();

    await prefs.setStringList(key, encodedEvents);
    await prefs.remove(_legacyKey);
  }

  Future<List<OfflineSosEvent>> getOfflineSosEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _currentUserOfflineSosKey;

    if (key == null) {
      return [];
    }

    final encodedEvents = prefs.getStringList(key) ?? [];

    await prefs.remove(_legacyKey);

    final events = <OfflineSosEvent>[];

    for (final encodedEvent in encodedEvents) {
      try {
        final decoded = jsonDecode(encodedEvent) as Map<String, dynamic>;
        final event = OfflineSosEvent.fromJson(decoded);

        if (event.localId.isNotEmpty &&
            event.latitude != 0 &&
            event.longitude != 0) {
          events.add(event);
        }
      } catch (_) {
        // Ignore broken local records.
      }
    }

    return events;
  }

  Future<void> removeOfflineSos(String localId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _currentUserOfflineSosKey;

    if (key == null) {
      return;
    }

    final events = await getOfflineSosEvents();

    final remainingEvents = events.where((event) {
      return event.localId != localId;
    }).toList();

    final encodedEvents = remainingEvents.map((item) {
      return jsonEncode(item.toJson());
    }).toList();

    await prefs.setStringList(key, encodedEvents);
  }

  Future<void> clearOfflineSosEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _currentUserOfflineSosKey;

    if (key != null) {
      await prefs.remove(key);
    }

    await prefs.remove(_legacyKey);
  }
}