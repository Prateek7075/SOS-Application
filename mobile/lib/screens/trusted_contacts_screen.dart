import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import '../models/emergency_contact.dart';
import '../services/emergency_contact_api_service.dart';
import '../services/emergency_contact_local_service.dart';
import 'add_trusted_contact_screen.dart';

class TrustedContactsScreen extends StatefulWidget {
  const TrustedContactsScreen({super.key});

  @override
  State<TrustedContactsScreen> createState() => _TrustedContactsScreenState();
}

class _TrustedContactsScreenState extends State<TrustedContactsScreen> {
  final EmergencyContactApiService apiService = EmergencyContactApiService();

  final EmergencyContactLocalService localService =
  EmergencyContactLocalService();

  List<EmergencyContact> contacts = [];
  bool isLoading = true;
  bool isImporting = false;
  String? errorMessage;

  static const Color _dangerRed = Color(0xFFE53935);
  static const Color _dangerDark = Color(0xFFB91C1C);
  static const Color _darkText = Color(0xFF111827);
  static const Color _mutedText = Color(0xFF6B7280);
  static const Color _softBg = Color(0xFFF8FAFC);
  static const Color _borderColor = Color(0xFFE5E7EB);

  @override
  void initState() {
    super.initState();
    loadContacts();
  }

  Future<void> loadContacts() async {
    try {
      final cachedContacts = await localService.getContacts();

      if (cachedContacts.isNotEmpty && mounted) {
        setState(() {
          contacts = cachedContacts;
          isLoading = false;
          errorMessage = null;
        });
      }

      final loadedContacts = await apiService.getContacts();

      await localService.saveContacts(loadedContacts);

      if (!mounted) {
        return;
      }

      setState(() {
        contacts = loadedContacts;
        isLoading = false;
        errorMessage = null;
      });
    } catch (error) {
      final cachedContacts = await localService.getContacts();

      if (!mounted) {
        return;
      }

      setState(() {
        contacts = cachedContacts;
        isLoading = false;
        errorMessage =
        cachedContacts.isEmpty ? 'Failed to load trusted contacts' : null;
      });

      if (cachedContacts.isNotEmpty) {
        showInfo('Showing locally saved contacts');
      }
    }
  }

  Future<void> openAddContactScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddTrustedContactScreen(),
      ),
    );

    if (result != null && result is EmergencyContact) {
      await saveTrustedContact(result);
    }
  }

  Future<void> importFromPhoneContacts() async {
    if (isImporting) {
      return;
    }

    setState(() {
      isImporting = true;
    });

    try {
      final permissionStatus = await FlutterContacts.permissions.request(
        PermissionType.read,
      );

      if (permissionStatus != PermissionStatus.granted) {
        if (!mounted) {
          return;
        }

        setState(() {
          isImporting = false;
        });

        showError('Contacts permission denied');
        return;
      }

      Contact? selectedContact = await FlutterContacts.native.showPicker(
        properties: {
          ContactProperty.name,
          ContactProperty.phone,
        },
      );

      if (selectedContact == null) {
        if (!mounted) {
          return;
        }

        setState(() {
          isImporting = false;
        });

        return;
      }

      if (selectedContact.phones.isEmpty &&
          selectedContact.id != null &&
          selectedContact.id!.isNotEmpty) {
        final fullContact = await FlutterContacts.get(
          selectedContact.id!,
          properties: {
            ContactProperty.name,
            ContactProperty.phone,
          },
        );

        if (fullContact != null) {
          selectedContact = fullContact;
        }
      }

      if (selectedContact.phones.isEmpty) {
        if (!mounted) {
          return;
        }

        setState(() {
          isImporting = false;
        });

        showError('Selected contact has no phone number');
        return;
      }

      final displayName = selectedContact.displayName?.trim() ?? '';

      final contactName =
      displayName.isEmpty ? 'Imported Contact' : displayName;

      final phoneNumber = cleanPhoneNumber(
        selectedContact.phones.first.number,
      );

      final alreadyExists = contacts.any((contact) {
        return normalizePhone(contact.phone) == normalizePhone(phoneNumber);
      });

      if (alreadyExists) {
        if (!mounted) {
          return;
        }

        setState(() {
          isImporting = false;
        });

        showInfo('This contact is already added');
        return;
      }

      final emergencyContact = EmergencyContact(
        name: contactName,
        phone: phoneNumber,
        relationship: 'Imported from phone',
      );

      await saveTrustedContact(emergencyContact);

      if (!mounted) {
        return;
      }

      setState(() {
        isImporting = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        isImporting = false;
      });

      showError('Failed to import contact: $error');
    }
  }

  Future<void> saveTrustedContact(EmergencyContact contact) async {
    try {
      final savedContact = await apiService.addContact(contact);

      if (!mounted) {
        return;
      }

      setState(() {
        contacts.add(savedContact);
      });

      await localService.saveContacts(contacts);

      showInfo('Trusted contact added');
    } catch (error) {
      showError('Failed to save contact');
    }
  }

  Future<void> deleteContact(EmergencyContact contact) async {
    if (contact.id == null) {
      showError('Cannot delete this contact');
      return;
    }

    final shouldDelete = await showDeleteConfirmation(contact);

    if (shouldDelete != true) {
      return;
    }

    try {
      await apiService.deleteContact(contact.id!);

      if (!mounted) {
        return;
      }

      setState(() {
        contacts.removeWhere((item) => item.id == contact.id);
      });

      await localService.saveContacts(contacts);

      showInfo('Trusted contact deleted');
    } catch (error) {
      showError('Failed to delete contact');
    }
  }

  Future<bool?> showDeleteConfirmation(EmergencyContact contact) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Delete Contact?',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'Are you sure you want to remove ${contact.name} from your trusted contacts?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Delete'),
              style: FilledButton.styleFrom(
                backgroundColor: _dangerRed,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  String cleanPhoneNumber(String phone) {
    return phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
  }

  String normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'\D'), '');
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

  void showInfo(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget buildBody() {
    if (isLoading) {
      return _buildLoadingState();
    }

    if (errorMessage != null) {
      return _buildErrorState();
    }

    if (contacts.isEmpty) {
      return _buildEmptyState();
    }

    return _buildContactsList();
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        color: _dangerRed,
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _dangerRed.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: _dangerRed,
                  size: 34,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _darkText,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please check your internet connection and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _mutedText,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: loadContacts,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try Again'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _dangerRed.withOpacity(0.14),
                      _dangerRed.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.contacts_rounded,
                  size: 46,
                  color: _dangerRed,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'No trusted contacts yet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _darkText,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Add people who should receive your SOS alert and location during an emergency.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _mutedText,
                  fontSize: 14.5,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: isImporting ? null : importFromPhoneContacts,
                  icon: isImporting
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(Icons.contact_phone_rounded),
                  label: Text(
                    isImporting
                        ? 'Importing...'
                        : 'Import from Phone Contacts',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton.icon(
                  onPressed: openAddContactScreen,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Add Manually'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactsList() {
    return SafeArea(
      child: RefreshIndicator(
        color: _dangerRed,
        onRefresh: loadContacts,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTopSummaryCard(),
                    const SizedBox(height: 18),
                    const Text(
                      'Saved Contacts',
                      style: TextStyle(
                        color: _darkText,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...contacts.map(_buildContactCard),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSummaryCard() {
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
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(19),
            ),
            child: const Icon(
              Icons.groups_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${contacts.length} Trusted Contact${contacts.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'These contacts can receive your SOS alert and location.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.88),
                    fontSize: 13.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(EmergencyContact contact) {
    final String initial = contact.name.trim().isNotEmpty
        ? contact.name.trim()[0].toUpperCase()
        : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _dangerRed.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: _dangerRed,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _darkText,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(
                          Icons.phone_outlined,
                          size: 15,
                          color: _mutedText,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            contact.phone,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _mutedText,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (contact.relationship.trim().isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(
                            Icons.favorite_border_rounded,
                            size: 15,
                            color: _mutedText,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              contact.relationship,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _mutedText,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  deleteContact(contact);
                },
                style: IconButton.styleFrom(
                  backgroundColor: _dangerRed.withOpacity(0.08),
                ),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: _dangerRed,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Colors.black.withOpacity(0.06),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isImporting ? null : importFromPhoneContacts,
                icon: isImporting
                    ? const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.contact_phone_rounded),
                label: Text(isImporting ? 'Importing' : 'Import'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: openAddContactScreen,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Add'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool showBottomActions =
        !isLoading && errorMessage == null && contacts.isNotEmpty;

    return Scaffold(
      backgroundColor: _softBg,
      appBar: AppBar(
        title: const Text('Trusted Contacts'),
        backgroundColor: _softBg,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: isImporting ? null : importFromPhoneContacts,
            tooltip: 'Import from phone contacts',
            icon: isImporting
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.contact_phone_rounded),
          ),
        ],
      ),
      body: buildBody(),
      bottomNavigationBar: showBottomActions ? _buildBottomActionBar() : null,
    );
  }
}