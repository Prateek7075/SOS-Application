import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/emergency_contact.dart';

class EmergencyContactLocalService {
  static const String _legacyContactsKey = 'trusted_contacts';

  String? get _currentUserId {
    return FirebaseAuth.instance.currentUser?.uid;
  }

  String? get _currentUserContactsKey {
    final userId = _currentUserId;

    if (userId == null || userId.isEmpty) {
      return null;
    }

    return 'trusted_contacts_$userId';
  }

  Future<void> saveContacts(List<EmergencyContact> contacts) async {
    final prefs = await SharedPreferences.getInstance();
    final contactsKey = _currentUserContactsKey;

    if (contactsKey == null) {
      throw Exception('Cannot save contacts because user is not logged in');
    }

    final contactsJsonList = contacts.map((contact) {
      return jsonEncode(contact.toJson());
    }).toList();

    await prefs.setStringList(contactsKey, contactsJsonList);

    // Remove old common cache so another account does not read it.
    await prefs.remove(_legacyContactsKey);
  }

  Future<List<EmergencyContact>> getContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final contactsKey = _currentUserContactsKey;

    if (contactsKey == null) {
      return [];
    }

    final contactsJsonList = prefs.getStringList(contactsKey) ?? [];

    // Remove old common cache. We do not migrate contacts because
    // old cached contacts may belong to another logged-in user.
    await prefs.remove(_legacyContactsKey);

    return contactsJsonList.map((contactJson) {
      final decodedContact = jsonDecode(contactJson);
      return EmergencyContact.fromJson(decodedContact);
    }).toList();
  }

  Future<void> clearContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final contactsKey = _currentUserContactsKey;

    if (contactsKey != null) {
      await prefs.remove(contactsKey);
    }

    await prefs.remove(_legacyContactsKey);
  }
}