import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';

class UserProfileLocalService {
  static const String _legacyProfileKey = 'user_profile';

  String? get _currentUserId {
    return FirebaseAuth.instance.currentUser?.uid;
  }

  String? get _currentUserProfileKey {
    final userId = _currentUserId;

    if (userId == null || userId.isEmpty) {
      return null;
    }

    return 'user_profile_$userId';
  }

  String? get _currentUserPendingSyncKey {
    final userId = _currentUserId;

    if (userId == null || userId.isEmpty) {
      return null;
    }

    return 'user_profile_pending_sync_$userId';
  }

  Future<void> saveProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final profileKey = _currentUserProfileKey;

    if (profileKey == null) {
      throw Exception('Cannot save profile because user is not logged in');
    }

    final profileJson = jsonEncode(profile.toJson());

    await prefs.setString(profileKey, profileJson);

    await prefs.remove(_legacyProfileKey);
  }

  Future<UserProfile?> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final profileKey = _currentUserProfileKey;

    if (profileKey == null) {
      return null;
    }

    final profileJson = prefs.getString(profileKey);

    if (profileJson != null && profileJson.isNotEmpty) {
      final decodedProfile = jsonDecode(profileJson);
      return UserProfile.fromJson(decodedProfile);
    }

    final legacyProfileJson = prefs.getString(_legacyProfileKey);

    if (legacyProfileJson != null && legacyProfileJson.isNotEmpty) {
      final decodedLegacyProfile = jsonDecode(legacyProfileJson);
      final legacyProfile = UserProfile.fromJson(decodedLegacyProfile);

      final firebaseName =
          FirebaseAuth.instance.currentUser?.displayName?.trim() ?? '';

      final legacyName = legacyProfile.name.trim();

      if (firebaseName.isEmpty || firebaseName == legacyName) {
        await prefs.setString(profileKey, legacyProfileJson);
        await prefs.remove(_legacyProfileKey);

        return legacyProfile;
      }
    }

    final firebaseUser = FirebaseAuth.instance.currentUser;

    final firebaseName = firebaseUser?.displayName?.trim() ?? '';
    final firebasePhone = firebaseUser?.phoneNumber?.trim() ?? '';

    if (firebaseName.isEmpty && firebasePhone.isEmpty) {
      return null;
    }

    final fallbackProfile = UserProfile(
      name: firebaseName,
      bloodGroup: '',
      phone: firebasePhone,
      relativeName: '',
      relativePhone: '',
      address: '',
    );

    await saveProfile(fallbackProfile);

    return fallbackProfile;
  }

  Future<void> markProfilePendingSync() async {
    final prefs = await SharedPreferences.getInstance();
    final pendingSyncKey = _currentUserPendingSyncKey;

    if (pendingSyncKey == null) {
      return;
    }

    await prefs.setBool(pendingSyncKey, true);
  }

  Future<void> clearProfilePendingSync() async {
    final prefs = await SharedPreferences.getInstance();
    final pendingSyncKey = _currentUserPendingSyncKey;

    if (pendingSyncKey == null) {
      return;
    }

    await prefs.remove(pendingSyncKey);
  }

  Future<bool> hasPendingProfileSync() async {
    final prefs = await SharedPreferences.getInstance();
    final pendingSyncKey = _currentUserPendingSyncKey;

    if (pendingSyncKey == null) {
      return false;
    }

    return prefs.getBool(pendingSyncKey) ?? false;
  }

  Future<void> clearProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final profileKey = _currentUserProfileKey;
    final pendingSyncKey = _currentUserPendingSyncKey;

    if (profileKey != null) {
      await prefs.remove(profileKey);
    }

    if (pendingSyncKey != null) {
      await prefs.remove(pendingSyncKey);
    }

    await prefs.remove(_legacyProfileKey);
  }
}