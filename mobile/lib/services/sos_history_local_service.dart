import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/sos_history_item.dart';
import 'auth_token_service.dart';

class SosHistoryLocalService {
  static const String _keyPrefix = 'sos_history_';

  final AuthTokenService _authTokenService = AuthTokenService();

  Future<String?> _getUserKey() async {
    final userId = await _authTokenService.getUserId();

    if (userId == null) {
      return null;
    }

    return '$_keyPrefix$userId';
  }

  Future<List<SosHistoryItem>> getHistory() async {
    final key = await _getUserKey();

    if (key == null) {
      return [];
    }

    final prefs = await SharedPreferences.getInstance();
    final rawHistory = prefs.getString(key);

    if (rawHistory == null || rawHistory.trim().isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(rawHistory);

      if (decoded is! List) {
        return [];
      }

      return decoded.map((item) {
        return SosHistoryItem.fromJson(Map<String, dynamic>.from(item as Map));
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveRawHistory(List<dynamic> history) async {
    final key = await _getUserKey();

    if (key == null) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(key, jsonEncode(history));
  }

  Future<void> clear() async {
    final key = await _getUserKey();

    if (key == null) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(key);
  }
}
