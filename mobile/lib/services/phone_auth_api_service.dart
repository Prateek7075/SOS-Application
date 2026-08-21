import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class PhoneAuthApiService {
  Future<void> requestOtp(String phone) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/auth/request-otp'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'phone': phone.trim()}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response, 'Unable to send OTP.'));
    }
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/auth/verify-otp'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'phone': phone.trim(), 'otp': otp.trim()}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response, 'OTP verification failed.'));
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    return body;
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String registrationToken,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/auth/register'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': name.trim(),
        'registration_token': registrationToken,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response, 'Registration failed.'));
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    return body;
  }

  Future<void> logout(String token) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/auth/logout'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 401) {
      return;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response, 'Logout failed.'));
    }
  }

  String _errorMessage(http.Response response, String fallback) {
    try {
      final body = jsonDecode(response.body);

      if (body is Map<String, dynamic>) {
        return body['message']?.toString() ?? fallback;
      }
    } catch (_) {}

    return fallback;
  }
}
