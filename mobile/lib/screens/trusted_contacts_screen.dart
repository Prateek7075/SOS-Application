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

      final contactName = displayName.isEmpty
          ? 'Imported Contact'
          : displayName;

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
      return;
    }

    try {
      await apiService.deleteContact(contact.id!);

      setState(() {
        contacts.remove(contact);
      });

      await localService.saveContacts(contacts);
    } catch (error) {
      showError('Failed to delete contact');
    }
  }

  String cleanPhoneNumber(String phone) {
    return phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
  }

  String normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'\D'), '');
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Widget buildBody() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Text(errorMessage!),
      );
    }

    if (contacts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.contacts,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 12),
              const Text(
                'No trusted contacts added yet.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: isImporting ? null : importFromPhoneContacts,
                icon: const Icon(Icons.contact_phone),
                label: Text(
                  isImporting
                      ? 'Importing...'
                      : 'Import from Phone Contacts',
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: openAddContactScreen,
                icon: const Icon(Icons.person_add),
                label: const Text('Add Manually'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: contacts.length,
      separatorBuilder: (context, index) {
        return const Divider();
      },
      itemBuilder: (context, index) {
        final contact = contacts[index];

        return ListTile(
          leading: const CircleAvatar(
            child: Icon(Icons.person),
          ),
          title: Text(contact.name),
          subtitle: Text('${contact.phone} - ${contact.relationship}'),
          trailing: IconButton(
            onPressed: () {
              deleteContact(contact);
            },
            icon: const Icon(Icons.delete_outline),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trusted Contacts'),
        centerTitle: true,
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
                : const Icon(Icons.contact_phone),
          ),
        ],
      ),
      body: buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: openAddContactScreen,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Contact'),
      ),
    );
  }
}