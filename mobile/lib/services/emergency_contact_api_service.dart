import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/emergency_contact.dart';
import 'authenticated_api_service.dart';

class EmergencyContactApiService {
  static const String baseUrl = AppConfig.apiBaseUrl;

  final AuthenticatedApiService _authenticatedApiService =
      AuthenticatedApiService();

  Future<List<EmergencyContact>> getContacts() async {
    final response = await http.get(
      Uri.parse('$baseUrl/emergency-contacts'),
      headers: await _authenticatedApiService.getAuthHeaders(),
    );

    await _authenticatedApiService.handleUnauthorized(response.statusCode);

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
      headers: await _authenticatedApiService.getAuthHeaders(),
      body: jsonEncode({
        'name': contact.name,
        'phone': contact.phone,
        'relationship': contact.relationship,
      }),
    );

    await _authenticatedApiService.handleUnauthorized(response.statusCode);

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
      headers: await _authenticatedApiService.getAuthHeaders(),
    );

    await _authenticatedApiService.handleUnauthorized(response.statusCode);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to delete contact: ${response.statusCode} ${response.body}',
      );
    }
  }
}
