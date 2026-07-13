import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ActiveSosSession {
  const ActiveSosSession({
    required this.sosEventId,
    required this.trackingToken,
    required this.trackingUrl,
    this.batteryPercentage,
    this.lastLocationUpdateAtMilliseconds,
    this.nextLocationUpdateAtMilliseconds,
  });

  final int sosEventId;
  final String trackingToken;
  final String trackingUrl;
  final int? batteryPercentage;
  final int? lastLocationUpdateAtMilliseconds;
  final int? nextLocationUpdateAtMilliseconds;

  DateTime? get lastLocationUpdateAt {
    final value = lastLocationUpdateAtMilliseconds;

    if (value == null || value <= 0) {
      return null;
    }

    return DateTime.fromMillisecondsSinceEpoch(value);
  }

  DateTime? get nextLocationUpdateAt {
    final value = nextLocationUpdateAtMilliseconds;

    if (value == null || value <= 0) {
      return null;
    }

    return DateTime.fromMillisecondsSinceEpoch(value);
  }

  ActiveSosSession copyWith({
    int? sosEventId,
    String? trackingToken,
    String? trackingUrl,
    int? batteryPercentage,
    int? lastLocationUpdateAtMilliseconds,
    int? nextLocationUpdateAtMilliseconds,
  }) {
    return ActiveSosSession(
      sosEventId: sosEventId ?? this.sosEventId,
      trackingToken: trackingToken ?? this.trackingToken,
      trackingUrl: trackingUrl ?? this.trackingUrl,
      batteryPercentage: batteryPercentage ?? this.batteryPercentage,
      lastLocationUpdateAtMilliseconds:
      lastLocationUpdateAtMilliseconds ??
          this.lastLocationUpdateAtMilliseconds,
      nextLocationUpdateAtMilliseconds:
      nextLocationUpdateAtMilliseconds ??
          this.nextLocationUpdateAtMilliseconds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sos_event_id': sosEventId,
      'tracking_token': trackingToken,
      'tracking_url': trackingUrl,
      'battery_percentage': batteryPercentage,
      'last_location_update_at_milliseconds':
      lastLocationUpdateAtMilliseconds,
      'next_location_update_at_milliseconds':
      nextLocationUpdateAtMilliseconds,
    };
  }

  factory ActiveSosSession.fromJson(Map<String, dynamic> json) {
    return ActiveSosSession(
      sosEventId: _parseInt(json['sos_event_id']) ?? 0,
      trackingToken: json['tracking_token']?.toString() ?? '',
      trackingUrl: json['tracking_url']?.toString() ?? '',
      batteryPercentage: _parseInt(json['battery_percentage']),
      lastLocationUpdateAtMilliseconds: _parseInt(
        json['last_location_update_at_milliseconds'],
      ),
      nextLocationUpdateAtMilliseconds: _parseInt(
        json['next_location_update_at_milliseconds'],
      ),
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString());
  }
}

class ActiveSosLocalService {
  static const String _legacyActiveSosKey = 'active_sos_session';

  String? get _currentUserId {
    return FirebaseAuth.instance.currentUser?.uid;
  }

  String? get _currentUserActiveSosKey {
    final userId = _currentUserId;

    if (userId == null || userId.isEmpty) {
      return null;
    }

    return 'active_sos_session_$userId';
  }

  Future<void> save({
    required int sosEventId,
    required String trackingToken,
    required String trackingUrl,
    int? batteryPercentage,
    DateTime? lastLocationUpdateAt,
    DateTime? nextLocationUpdateAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final activeSosKey = _currentUserActiveSosKey;

    if (activeSosKey == null) {
      throw Exception('Cannot save active SOS because user is not logged in');
    }

    final existingSession = await getActiveSos();

    final session = ActiveSosSession(
      sosEventId: sosEventId,
      trackingToken: trackingToken,
      trackingUrl: trackingUrl,
      batteryPercentage: batteryPercentage,
      lastLocationUpdateAtMilliseconds:
      lastLocationUpdateAt?.millisecondsSinceEpoch ??
          existingSession?.lastLocationUpdateAtMilliseconds,
      nextLocationUpdateAtMilliseconds:
      nextLocationUpdateAt?.millisecondsSinceEpoch ??
          existingSession?.nextLocationUpdateAtMilliseconds,
    );

    await prefs.setString(
      activeSosKey,
      jsonEncode(session.toJson()),
    );

    await prefs.remove(_legacyActiveSosKey);
  }

  Future<ActiveSosSession?> getActiveSos() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    final activeSosKey = _currentUserActiveSosKey;

    if (activeSosKey == null) {
      return null;
    }

    final sessionJson = prefs.getString(activeSosKey);

    if (sessionJson != null && sessionJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(sessionJson) as Map<String, dynamic>;
        final session = ActiveSosSession.fromJson(decoded);

        if (session.sosEventId <= 0 ||
            session.trackingToken.isEmpty ||
            session.trackingUrl.isEmpty) {
          await clear();
          return null;
        }

        return session;
      } catch (_) {
        await clear();
        return null;
      }
    }

    final legacySessionJson = prefs.getString(_legacyActiveSosKey);

    if (legacySessionJson == null || legacySessionJson.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(legacySessionJson) as Map<String, dynamic>;
      final session = ActiveSosSession.fromJson(decoded);

      if (session.sosEventId <= 0 ||
          session.trackingToken.isEmpty ||
          session.trackingUrl.isEmpty) {
        await prefs.remove(_legacyActiveSosKey);
        return null;
      }

      await prefs.setString(activeSosKey, legacySessionJson);
      await prefs.remove(_legacyActiveSosKey);

      return session;
    } catch (_) {
      await prefs.remove(_legacyActiveSosKey);
      return null;
    }
  }

  Future<void> saveLocationUpdateTiming({
    required DateTime lastLocationUpdateAt,
    required DateTime nextLocationUpdateAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final activeSosKey = _currentUserActiveSosKey;

    if (activeSosKey == null) {
      return;
    }

    final session = await getActiveSos();

    if (session == null) {
      return;
    }

    final updatedSession = session.copyWith(
      lastLocationUpdateAtMilliseconds:
      lastLocationUpdateAt.millisecondsSinceEpoch,
      nextLocationUpdateAtMilliseconds:
      nextLocationUpdateAt.millisecondsSinceEpoch,
    );

    await prefs.setString(
      activeSosKey,
      jsonEncode(updatedSession.toJson()),
    );
  }

  Future<void> saveNextLocationUpdateTime({
    required DateTime nextLocationUpdateAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final activeSosKey = _currentUserActiveSosKey;

    if (activeSosKey == null) {
      return;
    }

    final session = await getActiveSos();

    if (session == null) {
      return;
    }

    final updatedSession = session.copyWith(
      nextLocationUpdateAtMilliseconds:
      nextLocationUpdateAt.millisecondsSinceEpoch,
    );

    await prefs.setString(
      activeSosKey,
      jsonEncode(updatedSession.toJson()),
    );
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    final activeSosKey = _currentUserActiveSosKey;

    if (activeSosKey != null) {
      await prefs.remove(activeSosKey);
    }

    await prefs.remove(_legacyActiveSosKey);
  }
}