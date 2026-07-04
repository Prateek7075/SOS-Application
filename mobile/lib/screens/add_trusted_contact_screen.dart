import 'package:flutter/material.dart';

import '../models/emergency_contact.dart';

class AddTrustedContactScreen extends StatefulWidget {
  const AddTrustedContactScreen({super.key});

  @override
  State<AddTrustedContactScreen> createState() =>
      _AddTrustedContactScreenState();
}

class _AddTrustedContactScreenState extends State<AddTrustedContactScreen> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final relationshipController = TextEditingController();

  static const Color _dangerRed = Color(0xFFE53935);
  static const Color _dangerDark = Color(0xFFB91C1C);
  static const Color _darkText = Color(0xFF111827);
  static const Color _mutedText = Color(0xFF6B7280);
  static const Color _softBg = Color(0xFFF8FAFC);
  static const Color _borderColor = Color(0xFFE5E7EB);

  void saveContact() {
    if (!_formKey.currentState!.validate()) {
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
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _dangerRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String? requiredValidator(String? value, String message) {
    if (value == null || value.trim().isEmpty) {
      return message;
    }

    return null;
  }

  String? phoneValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter contact phone number';
    }

    final cleanedPhone = value.replaceAll(RegExp(r'\D'), '');

    if (cleanedPhone.length < 10) {
      return 'Enter a valid phone number';
    }

    return null;
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
      backgroundColor: _softBg,
      appBar: AppBar(
        title: const Text('Add Trusted Contact'),
        backgroundColor: _softBg,
        foregroundColor: _darkText,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            Navigator.of(context).maybePop();
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _buildFormCard(),
                    const SizedBox(height: 20),
                    _buildSaveButton(),
                    const SizedBox(height: 16),
                    _buildSafetyNote(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            _dangerRed,
            _dangerDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: _dangerRed.withOpacity(0.24),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_add_alt_1_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Trusted Contact',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'This person can receive your SOS alert and location.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: _borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Contact Details',
            style: TextStyle(
              color: _darkText,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Add a person you trust during emergencies.',
            style: TextStyle(
              color: _mutedText,
              fontSize: 13.5,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: nameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Contact Name',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            validator: (value) {
              return requiredValidator(
                value,
                'Please enter contact name',
              );
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            validator: phoneValidator,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: relationshipController,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) {
              saveContact();
            },
            decoration: const InputDecoration(
              labelText: 'Relationship',
              hintText: 'Example: Father, Mother, Friend',
              prefixIcon: Icon(Icons.favorite_border_rounded),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton.icon(
        onPressed: saveContact,
        icon: const Icon(Icons.save_rounded),
        label: const Text(
          'Save Contact',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: _dangerRed,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildSafetyNote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _dangerRed.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _dangerRed.withOpacity(0.12),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: _dangerRed,
            size: 22,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Make sure the phone number is correct. SOS alerts will be sent to this contact during emergency.',
              style: TextStyle(
                color: _mutedText,
                fontSize: 13.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}