import 'package:flutter/material.dart';

import '../models/emergency_contact.dart';

class AddTrustedContactScreen extends StatefulWidget {
  const AddTrustedContactScreen({super.key});

  @override
  State<AddTrustedContactScreen> createState() => _AddTrustedContactScreenState();
}

class _AddTrustedContactScreenState extends State<AddTrustedContactScreen> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final relationshipController = TextEditingController();

  void saveContact() {
    if (nameController.text.trim().isEmpty) {
      showError('Please enter contact name');
      return;
    }

    if (phoneController.text.trim().isEmpty) {
      showError('Please enter contact phone number');
      return;
    }

    final contact = EmergencyContact(
      name: nameController.text.trim(),
      phone: phoneController.text.trim(),
      relationship: relationshipController.text.trim().isEmpty
          ? 'Trusted Contact'
          : relationshipController.text.trim(),
    );

    Navigator.pop(context, contact);
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    relationshipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Trusted Contact'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Contact Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: relationshipController,
              decoration: const InputDecoration(
                labelText: 'Relationship',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: saveContact,
                child: const Text('Save Contact'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}