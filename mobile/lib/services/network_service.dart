import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class NetworkService {
  Future<bool> isBackendReachable() async {
    final connectivity = await Connectivity().checkConnectivity();

    if (connectivity.contains(ConnectivityResult.none)) {
      return false;
    }

    if (AppConfig.backendBaseUrl.isEmpty) {
      return false;
    }

    try {
      final response = await http
          .get(Uri.parse(AppConfig.backendBaseUrl))
          .timeout(const Duration(seconds: 10));

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Future<String> getNetworkStatus() async {
    final connectivity = await Connectivity().checkConnectivity();

    if (connectivity.contains(ConnectivityResult.none)) {
      return 'No internet';
    }

    final backendReachable = await isBackendReachable();

    if (!backendReachable) {
      return 'Internet connected, backend unavailable';
    }

    if (connectivity.contains(ConnectivityResult.wifi)) {
      return 'Wi-Fi connected';
    }

    if (connectivity.contains(ConnectivityResult.mobile)) {
      return 'Mobile internet connected';
    }

    return 'Internet connected';
  }
}
