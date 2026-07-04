import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomSosMessageLocalService {
  static const String _legacyKey = 'custom_sos_message';

  String? get _currentUserId {
    return FirebaseAuth.instance.currentUser?.uid;
  }

  String? get _currentUserMessageKey {
    final userId = _currentUserId;

    if (userId == null || userId.isEmpty) {
      return null;
    }

    return 'custom_sos_message_$userId';
  }

  Future<void> saveMessage(String message) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _currentUserMessageKey;

    if (key == null) {
      throw Exception('Cannot save message because user is not logged in');
    }

    await prefs.setString(key, message.trim());
    await prefs.remove(_legacyKey);
  }

  Future<String?> getMessage() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _currentUserMessageKey;

    if (key == null) {
      return null;
    }

    await prefs.remove(_legacyKey);

    final message = prefs.getString(key);

    if (message == null || message.trim().isEmpty) {
      return null;
    }

    return message.trim();
  }

  Future<void> clearMessage() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _currentUserMessageKey;

    if (key != null) {
      await prefs.remove(key);
    }

    await prefs.remove(_legacyKey);
  }
}