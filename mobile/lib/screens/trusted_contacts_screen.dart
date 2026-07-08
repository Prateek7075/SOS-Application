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

  static const Color _bgColor = Color(0xFF0B1120);
  static const Color _cardColor = Color(0xFF111827);
  static const Color _fieldColor = Color(0xFF0F172A);
  static const Color _borderColor = Color(0xFF243041);
  static const Color _dangerRed = Color(0xFFEF4444);
  static const Color _dangerDark = Color(0xFFB91C1C);
  static const Color _successGreen = Color(0xFF22C55E);
  static const Color _mapBlue = Color(0xFF3B82F6);
  static const Color _warningAmber = Color(0xFFF59E0B);
  static const Color _primaryText = Color(0xFFF8FAFC);
  static const Color _mutedText = Color(0xFF94A3B8);

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
      barrierColor: Colors.black.withOpacity(0.72),
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _cardColor,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
            side: const BorderSide(
              color: _borderColor,
            ),
          ),
          titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
          contentPadding: const EdgeInsets.fromLTRB(22, 14, 22, 8),
          actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          title: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _dangerRed.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _dangerRed.withOpacity(0.28),
                  ),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: _dangerRed,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Delete Contact?',
                  style: TextStyle(
                    color: _primaryText,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to remove ${contact.name} from your trusted contacts?',
            style: const TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFCBD5E1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text(
                'Delete',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _dangerRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
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
        backgroundColor: _cardColor,
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
      child: SizedBox(
        width: 34,
        height: 34,
        child: CircularProgressIndicator(
          color: _dangerRed,
          strokeWidth: 3,
        ),
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
            color: _cardColor,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: _borderColor,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.26),
                blurRadius: 26,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  color: _dangerRed.withOpacity(0.14),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _dangerRed.withOpacity(0.28),
                  ),
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: _dangerRed,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
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
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: loadContacts,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text(
                    'Try Again',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
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
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: _borderColor,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 94,
                  height: 94,
                  decoration: BoxDecoration(
                    color: _dangerRed.withOpacity(0.14),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _dangerRed.withOpacity(0.28),
                    ),
                  ),
                  child: const Icon(
                    Icons.contacts_rounded,
                    size: 48,
                    color: _dangerRed,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'No trusted contacts yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _primaryText,
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
                _buildImportButton(),
                const SizedBox(height: 12),
                _buildAddManualButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContactsList() {
    return SafeArea(
      child: RefreshIndicator(
        color: _dangerRed,
        backgroundColor: _cardColor,
        onRefresh: loadContacts,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
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
                        color: _primaryText,
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
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F172A),
            Color(0xFF111827),
            Color(0xFF172033),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: _borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.28),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: _dangerRed.withOpacity(0.16),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _dangerRed.withOpacity(0.35),
              ),
            ),
            child: const Icon(
              Icons.groups_rounded,
              color: _dangerRed,
              size: 34,
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
                    color: _primaryText,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'These contacts can receive your SOS alert and location.',
                  style: TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontSize: 13.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
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
        color: _cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 22,
            offset: const Offset(0, 10),
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
                  color: _dangerRed.withOpacity(0.14),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _dangerRed.withOpacity(0.26),
                  ),
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
                        color: _primaryText,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.phone_outlined,
                          size: 15,
                          color: _mapBlue,
                        ),
                        const SizedBox(width: 6),
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
                            color: _warningAmber,
                          ),
                          const SizedBox(width: 6),
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
                  backgroundColor: _dangerRed.withOpacity(0.12),
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

  Widget _buildImportButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        onPressed: isImporting ? null : importFromPhoneContacts,
        icon: isImporting
            ? const SizedBox(
          width: 17,
          height: 17,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: _mapBlue,
          ),
        )
            : const Icon(Icons.contact_phone_rounded),
        label: Text(
          isImporting ? 'Importing...' : 'Import from Phone Contacts',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: _mapBlue,
          side: BorderSide(
            color: _mapBlue.withOpacity(0.45),
          ),
          backgroundColor: _fieldColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
        ),
      ),
    );
  }

  Widget _buildAddManualButton() {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17),
        boxShadow: [
          BoxShadow(
            color: _dangerRed.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: FilledButton.icon(
        onPressed: openAddContactScreen,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text(
          'Add Manually',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: _dangerRed,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF162033),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: const Color(0xFF2B3A52),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.38),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isImporting ? null : importFromPhoneContacts,
                  icon: isImporting
                      ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _mapBlue,
                    ),
                  )
                      : const Icon(Icons.contact_phone_rounded),
                  label: Text(isImporting ? 'Importing' : 'Import'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _mapBlue,
                    side: BorderSide(
                      color: _mapBlue.withOpacity(0.45),
                    ),
                    backgroundColor: _fieldColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: openAddContactScreen,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Add'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _dangerRed,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool showBottomActions =
        !isLoading && errorMessage == null && contacts.isNotEmpty;

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text(
          'Trusted Contacts',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leadingWidth: 60,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Container(
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _borderColor,
              ),
            ),
            child: IconButton(
              tooltip: 'Back',
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
              ),
              onPressed: () {
                Navigator.of(context).maybePop();
              },
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _borderColor,
                ),
              ),
              child: IconButton(
                onPressed: isImporting ? null : importFromPhoneContacts,
                tooltip: 'Import from phone contacts',
                icon: isImporting
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(
                  Icons.contact_phone_rounded,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF08101E),
              Color(0xFF0B1120),
              Color(0xFF111827),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: buildBody(),
      ),
      bottomNavigationBar: showBottomActions ? _buildBottomActionBar() : null,
    );
  }
}