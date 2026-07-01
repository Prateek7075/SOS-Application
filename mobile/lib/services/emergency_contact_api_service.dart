import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/emergency_contact.dart';

class EmergencyContactApiService {
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

  Future<List<EmergencyContact>> getContacts() async {
    final response = await http.get(
      Uri.parse('$baseUrl/emergency-contacts'),
      headers: await getAuthHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load contacts: ${response.statusCode} ${response.body}',
      );
    }

    final decodedBody = jsonDecode(response.body);
    final contactsJson = decodedBody['data']['contacts'] as List;

    return contactsJson.map((contactJson) {
      return EmergencyContact.fromJson(contactJson);
    }).toList();
  }

  Future<EmergencyContact> addContact(EmergencyContact contact) async {
    final response = await http.post(
      Uri.parse('$baseUrl/emergency-contacts'),
      headers: await getAuthHeaders(),
      body: jsonEncode({
        'name': contact.name,
        'phone': contact.phone,
        'relationship': contact.relationship,
      }),
    );

    if (response.statusCode != 201) {
      throw Exception(
        'Failed to save contact: ${response.statusCode} ${response.body}',
      );
    }

    final decodedBody = jsonDecode(response.body);
    final contactJson = decodedBody['data']['contact'];

    return EmergencyContact.fromJson(contactJson);
  }

  Future<void> deleteContact(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/emergency-contacts/$id'),
      headers: await getAuthHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to delete contact: ${response.statusCode} ${response.body}',
      );
    }
  }
}