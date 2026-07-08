import 'dart:io';

import 'package:flutter/services.dart';

class BatteryOptimizationService {
  static const MethodChannel _channel = MethodChannel('sos_sms_channel');

  Future<bool> isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) {
      return true;
    }

    final result = await _channel.invokeMethod<bool>(
      'isIgnoringBatteryOptimizations',
    );

    return result ?? false;
  }

  Future<void> openBatteryOptimizationSettings() async {
    if (!Platform.isAndroid) {
      return;
    }

    await _channel.invokeMethod<bool>(
      'openBatteryOptimizationSettings',
    );
  }
}