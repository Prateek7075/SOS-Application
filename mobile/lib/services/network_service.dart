import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkService {
  Future<String> getNetworkStatus() async {
    final results = await Connectivity().checkConnectivity();

    if (results.contains(ConnectivityResult.wifi)) {
      return 'Wi-Fi connected';
    }

    if (results.contains(ConnectivityResult.mobile)) {
      return 'Mobile internet connected';
    }

    if (results.contains(ConnectivityResult.none)) {
      return 'No internet';
    }

    return 'Unknown network';
  }
}