import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/user_profile.dart';

class UserProfileApiService {
  static const String baseUrl = AppConfig.apiBaseUrl;

  Future<Map<String, String>> getAuthHeaders() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser == null) {
      throw Exception('User is not logged in');
    }

    final idToken = await firebaseUser.getIdToken();

    if (idToken == null || idToken.isEmpty) {
      throw Exception('Firebase ID token is unavailable');
    }

    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $idToken',
    };
  }

  Future<UserProfile> getProfile() async {
    final response = await http.get(Uri.parse('$baseUrl/user-profile'), headers: await getAuthHeaders(),);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load profile: ${response.statusCode} ${response.body}',
      );
    }

    final decodedBody = jsonDecode(response.body);
    final profileJson = decodedBody['data']['profile'];

    return UserProfile(
      name: profileJson['name']?.toString() ?? '',
      bloodGroup: profileJson['blood_group']?.toString() ?? '',
      phone: profileJson['phone']?.toString() ?? '',
      relativeName: profileJson['relative_name']?.toString() ?? '',
      relativePhone: profileJson['relative_phone']?.toString() ?? '',
      address: profileJson['address']?.toString() ?? '',
    );
  }

  Future<UserProfile> updateProfile(UserProfile profile) async {
    final response = await http.put(
      Uri.parse('$baseUrl/user-profile'),
      headers: await getAuthHeaders(),
      body: jsonEncode({
        'name': profile.name,
        'phone': profile.phone,
        'blood_group': profile.bloodGroup,
        'relative_name': profile.relativeName,
        'relative_phone': profile.relativePhone,
        'address': profile.address,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to update profile: ${response.statusCode} ${response.body}',
      );
    }

    final decodedBody = jsonDecode(response.body);
    final profileJson = decodedBody['data']['profile'];

    return UserProfile(
      name: profileJson['name']?.toString() ?? '',
      bloodGroup: profileJson['blood_group']?.toString() ?? '',
      phone: profileJson['phone']?.toString() ?? '',
      relativeName: profileJson['relative_name']?.toString() ?? '',
      relativePhone: profileJson['relative_phone']?.toString() ?? '',
      address: profileJson['address']?.toString() ?? '',
    );
  }
}