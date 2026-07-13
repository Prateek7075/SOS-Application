import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../config/app_config.dart';

class ForegroundLocationServiceState {
  const ForegroundLocationServiceState({
    required this.lastHeartbeatAt,
    required this.heartbeatAgeMilliseconds,
    required this.activeSosEventId,
    required this.activeTrackingToken,
    required this.isHeartbeatFresh,
  });

  final int lastHeartbeatAt;
  final int? heartbeatAgeMilliseconds;
  final int activeSosEventId;
  final String activeTrackingToken;
  final bool isHeartbeatFresh;

  bool isFreshFor({
    required int sosEventId,
    required String trackingToken,
  }) {
    return isHeartbeatFresh &&
        activeSosEventId == sosEventId &&
        activeTrackingToken == trackingToken;
  }

  factory ForegroundLocationServiceState.empty() {
    return const ForegroundLocationServiceState(
      lastHeartbeatAt: 0,
      heartbeatAgeMilliseconds: null,
      activeSosEventId: -1,
      activeTrackingToken: '',
      isHeartbeatFresh: false,
    );
  }

  factory ForegroundLocationServiceState.fromMap(
      Map<dynamic, dynamic>? map,
      ) {
    if (map == null) {
      return ForegroundLocationServiceState.empty();
    }

    return ForegroundLocationServiceState(
      lastHeartbeatAt: _parseInt(map['lastHeartbeatAt']) ?? 0,
      heartbeatAgeMilliseconds: _parseInt(
        map['heartbeatAgeMilliseconds'],
      ),
      activeSosEventId: _parseInt(map['activeSosEventId']) ?? -1,
      activeTrackingToken: map['activeTrackingToken']?.toString() ?? '',
      isHeartbeatFresh: map['isHeartbeatFresh'] == true,
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

class BackgroundLocationService {
  static const MethodChannel _channel = MethodChannel('sos_sms_channel');

  Future<void> requestNotificationPermission() async {
    final status = await Permission.notification.status;

    if (status.isGranted) {
      return;
    }

    await Permission.notification.request();
  }

  Future<bool> start({
    required int sosEventId,
    required String trackingToken,
  }) async {
    try {
      await requestNotificationPermission();

      final result = await _channel.invokeMethod<bool>(
        'startForegroundLocationService',
        {
          'sosEventId': sosEventId,
          'trackingToken': trackingToken,
          'apiBaseUrl': AppConfig.apiBaseUrl,
        },
      );

      return result == true;
    } catch (error) {
      debugPrint('Failed to start background location service: $error');
      return false;
    }
  }

  Future<bool> stop() async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'stopForegroundLocationService',
      );

      return result == true;
    } catch (error) {
      debugPrint('Failed to stop background location service: $error');
      return false;
    }
  }

  Future<ForegroundLocationServiceState>
  getForegroundLocationServiceState() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getForegroundLocationServiceState',
      );

      return ForegroundLocationServiceState.fromMap(result);
    } catch (error) {
      debugPrint('Failed to read foreground service state: $error');
      return ForegroundLocationServiceState.empty();
    }
  }
}