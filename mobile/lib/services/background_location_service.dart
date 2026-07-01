import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../config/app_config.dart';

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
}