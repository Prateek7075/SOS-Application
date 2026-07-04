import 'package:battery_plus/battery_plus.dart';

class BatteryService {
  final Battery _battery = Battery();

  Future<int?> getBatteryPercentage() async {
    try {
      final level = await _battery.batteryLevel;

      if (level < 0 || level > 100) {
        return null;
      }

      return level;
    } catch (_) {
      return null;
    }
  }
}