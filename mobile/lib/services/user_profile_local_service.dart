import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';
import 'auth_token_service.dart';

class UserProfileLocalService {
  final AuthTokenService _authTokenService = AuthTokenService();

  Future<String?> _getCurrentUserProfileKey() async {
    final userId = await _authTokenService.getUserId();

    if (userId == null) {
      return null;
    }

    return 'user_profile_$userId';
  }

  Future<String?> _getCurrentUserPendingSyncKey() async {
    final userId = await _authTokenService.getUserId();

    if (userId == null) {
      return null;
    }

    return 'user_profile_pending_sync_$userId';
  }

  Future<void> saveProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final profileKey = await _getCurrentUserProfileKey();

    if (profileKey == null) {
      throw Exception('Cannot save profile because user is not logged in');
    }

    await prefs.setString(profileKey, jsonEncode(profile.toJson()));
  }

  Future<UserProfile?> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final profileKey = await _getCurrentUserProfileKey();

    if (profileKey == null) {
      return null;
    }

    final profileJson = prefs.getString(profileKey);

    if (profileJson == null || profileJson.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(profileJson);

      return UserProfile.fromJson(decoded);
    } catch (_) {
      await prefs.remove(profileKey);

      return null;
    }
  }

  Future<void> markProfilePendingSync() async {
    final prefs = await SharedPreferences.getInstance();
    final pendingSyncKey = await _getCurrentUserPendingSyncKey();

    if (pendingSyncKey == null) {
      return;
    }

    await prefs.setBool(pendingSyncKey, true);
  }

  Future<void> clearProfilePendingSync() async {
    final prefs = await SharedPreferences.getInstance();
    final pendingSyncKey = await _getCurrentUserPendingSyncKey();

    if (pendingSyncKey == null) {
      return;
    }

    await prefs.remove(pendingSyncKey);
  }

  Future<bool> hasPendingProfileSync() async {
    final prefs = await SharedPreferences.getInstance();
    final pendingSyncKey = await _getCurrentUserPendingSyncKey();

    if (pendingSyncKey == null) {
      return false;
    }

    return prefs.getBool(pendingSyncKey) ?? false;
  }

  Future<void> clearProfile() async {
    final prefs = await SharedPreferences.getInstance();

    final profileKey = await _getCurrentUserProfileKey();
    final pendingSyncKey = await _getCurrentUserPendingSyncKey();

    if (profileKey != null) {
      await prefs.remove(profileKey);
    }

    if (pendingSyncKey != null) {
      await prefs.remove(pendingSyncKey);
    }
  }
}
