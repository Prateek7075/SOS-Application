import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/emergency_contact.dart';
import 'auth_token_service.dart';

class EmergencyContactLocalService {
  final AuthTokenService _authTokenService = AuthTokenService();

  Future<String?> _getCurrentUserContactsKey() async {
    final userId = await _authTokenService.getUserId();

    if (userId == null) {
      return null;
    }

    return 'trusted_contacts_$userId';
  }

  Future<void> saveContacts(List<EmergencyContact> contacts) async {
    final prefs = await SharedPreferences.getInstance();
    final contactsKey = await _getCurrentUserContactsKey();

    if (contactsKey == null) {
      throw Exception('Cannot save contacts because user is not logged in');
    }

    final contactsJsonList = contacts.map((contact) {
      return jsonEncode(contact.toJson());
    }).toList();

    await prefs.setStringList(contactsKey, contactsJsonList);
  }

  Future<List<EmergencyContact>> getContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final contactsKey = await _getCurrentUserContactsKey();

    if (contactsKey == null) {
      return [];
    }

    final contactsJsonList = prefs.getStringList(contactsKey) ?? [];

    return contactsJsonList.map((contactJson) {
      final decodedContact = jsonDecode(contactJson);

      return EmergencyContact.fromJson(decodedContact);
    }).toList();
  }

  Future<void> clearContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final contactsKey = await _getCurrentUserContactsKey();

    if (contactsKey != null) {
      await prefs.remove(contactsKey);
    }
  }
}
