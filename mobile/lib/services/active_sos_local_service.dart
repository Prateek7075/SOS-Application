import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ActiveSosSession {
  const ActiveSosSession({
    required this.sosEventId,
    required this.trackingToken,
    required this.trackingUrl,
  });

  final int sosEventId;
  final String trackingToken;
  final String trackingUrl;

  Map<String, dynamic> toJson() {
    return {
      'sos_event_id': sosEventId,
      'tracking_token': trackingToken,
      'tracking_url': trackingUrl,
    };
  }

  factory ActiveSosSession.fromJson(Map<String, dynamic> json) {
    return ActiveSosSession(
      sosEventId: json['sos_event_id'] as int,
      trackingToken: json['tracking_token'] as String,
      trackingUrl: json['tracking_url'] as String,
    );
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
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final activeSosKey = _currentUserActiveSosKey;

    if (activeSosKey == null) {
      throw Exception('Cannot save active SOS because user is not logged in');
    }

    final session = ActiveSosSession(
      sosEventId: sosEventId,
      trackingToken: trackingToken,
      trackingUrl: trackingUrl,
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
        return ActiveSosSession.fromJson(decoded);
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

      await prefs.setString(activeSosKey, legacySessionJson);
      await prefs.remove(_legacyActiveSosKey);

      return ActiveSosSession.fromJson(decoded);
    } catch (_) {
      await prefs.remove(_legacyActiveSosKey);
      return null;
    }
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