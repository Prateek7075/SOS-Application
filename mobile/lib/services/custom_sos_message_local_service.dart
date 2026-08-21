import 'package:shared_preferences/shared_preferences.dart';

import 'auth_token_service.dart';

class CustomSosMessageLocalService {
  final AuthTokenService _authTokenService = AuthTokenService();

  Future<String?> _getCurrentUserMessageKey() async {
    final userId = await _authTokenService.getUserId();

    if (userId == null) {
      return null;
    }

    return 'custom_sos_message_$userId';
  }

  Future<void> saveMessage(String message) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getCurrentUserMessageKey();

    if (key == null) {
      throw Exception('Cannot save message because user is not logged in');
    }

    await prefs.setString(key, message.trim());
  }

  Future<String?> getMessage() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getCurrentUserMessageKey();

    if (key == null) {
      return null;
    }

    final message = prefs.getString(key);

    if (message == null || message.trim().isEmpty) {
      return null;
    }

    return message.trim();
  }

  Future<void> clearMessage() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getCurrentUserMessageKey();

    if (key != null) {
      await prefs.remove(key);
    }
  }
}
