import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class AuthApiService {
  Future<void> syncUser({
    String? name,
    String? phone,
  }) async {
    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser == null) {
      throw Exception('No Firebase user is signed in');
    }

    final idToken = await firebaseUser.getIdToken();

    if (idToken == null || idToken.isEmpty) {
      throw Exception('Firebase ID token is unavailable');
    }

    final body = <String, dynamic>{};

    final firebaseName = firebaseUser.displayName?.trim();

    if (name != null && name.trim().isNotEmpty) {
      body['name'] = name.trim();
    } else if (firebaseName != null && firebaseName.isNotEmpty) {
      body['name'] = firebaseName;
    }

    if (phone != null && phone.trim().isNotEmpty) {
      body['phone'] = phone.trim();
    }

    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/auth/sync-user'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'User sync failed: ${response.statusCode} ${response.body}',
      );
    }
  }
}