import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/user_profile.dart';
import 'authenticated_api_service.dart';

class UserProfileApiService {
  static const String baseUrl = AppConfig.apiBaseUrl;

  final AuthenticatedApiService _authenticatedApiService =
      AuthenticatedApiService();

  Future<UserProfile> getProfile() async {
    final response = await http.get(
      Uri.parse('$baseUrl/user-profile'),
      headers: await _authenticatedApiService.getAuthHeaders(),
    );

    await _authenticatedApiService.handleUnauthorized(response.statusCode);

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
      headers: await _authenticatedApiService.getAuthHeaders(),
      body: jsonEncode({
        'name': profile.name,
        'phone': profile.phone,
        'blood_group': profile.bloodGroup,
        'relative_name': profile.relativeName,
        'relative_phone': profile.relativePhone,
        'address': profile.address,
      }),
    );

    await _authenticatedApiService.handleUnauthorized(response.statusCode);

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
