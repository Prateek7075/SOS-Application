import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/active_sos_local_service.dart';
import '../services/auth_service.dart';
import '../services/background_location_service.dart';
import '../services/sos_api_service.dart';
import '../services/user_profile_api_service.dart';
import '../services/user_profile_local_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.initialProfile,
  });

  final UserProfile? initialProfile;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserProfileLocalService _profileLocalService =
  UserProfileLocalService();

  final UserProfileApiService _profileApiService =
  UserProfileApiService();

  final ActiveSosLocalService _activeSosLocalService =
  ActiveSosLocalService();

  final BackgroundLocationService _backgroundLocationService =
  BackgroundLocationService();

  final SosApiService _sosApiService = SosApiService();

  final AuthService _authService = AuthService();

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bloodGroupController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _relativeNameController =
  TextEditingController();
  final TextEditingController _relativePhoneController =
  TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  bool _isSaving = false;
  bool _isLoggingOut = false;
  bool _isLoadingServerProfile = false;

  @override
  void initState() {
    super.initState();

    if (widget.initialProfile != null) {
      fillProfile(widget.initialProfile!);
    }

    loadProfile();
  }

  Future<void> loadProfile() async {
    final savedProfile = await _profileLocalService.getProfile();

    if (mounted && savedProfile != null) {
      fillProfile(savedProfile);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoadingServerProfile = true;
    });

    try {
      final pendingSync = await _profileLocalService.hasPendingProfileSync();

      if (pendingSync && savedProfile != null) {
        try {
          final syncedProfile = await _profileApiService.updateProfile(
            savedProfile,
          );

          await _profileLocalService.saveProfile(syncedProfile);
          await _profileLocalService.clearProfilePendingSync();

          if (!mounted) {
            return;
          }

          fillProfile(syncedProfile);

          debugPrint('Pending profile synced with Laravel from ProfileScreen');

          return;
        } catch (error) {
          debugPrint('Pending profile sync failed from ProfileScreen: $error');

          // Keep local profile visible.
          // Do not fetch Laravel profile because it may overwrite unsynced local data.
          return;
        }
      }

      final serverProfile = await _profileApiService.getProfile();

      await _profileLocalService.saveProfile(serverProfile);

      if (!mounted) {
        return;
      }

      fillProfile(serverProfile);
    } catch (error) {
      debugPrint('Could not load profile from Laravel: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingServerProfile = false;
        });
      }
    }
  }

  void fillProfile(UserProfile profile) {
    _nameController.text = profile.name;
    _bloodGroupController.text = profile.bloodGroup;
    _phoneController.text = profile.phone;
    _relativeNameController.text = profile.relativeName;
    _relativePhoneController.text = profile.relativePhone;
    _addressController.text = profile.address;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bloodGroupController.dispose();
    _phoneController.dispose();
    _relativeNameController.dispose();
    _relativePhoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<bool> hasActiveSos() async {
    final activeSosSession = await _activeSosLocalService.getActiveSos();

    if (activeSosSession == null) {
      return false;
    }

    try {
      final backendStatus = await _sosApiService.getTrackingStatus(
        trackingToken: activeSosSession.trackingToken,
      );

      if (backendStatus != 'active') {
        await _backgroundLocationService.stop();
        await _activeSosLocalService.clear();
        return false;
      }

      return true;
    } catch (_) {
      return true;
    }
  }

  Future<void> logout() async {
    if (_isLoggingOut) {
      return;
    }

    setState(() {
      _isLoggingOut = true;
    });

    try {
      final activeSosExists = await hasActiveSos();

      if (!mounted) {
        return;
      }

      if (activeSosExists) {
        setState(() {
          _isLoggingOut = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cancel active SOS before logging out'),
          ),
        );

        return;
      }

      final shouldLogout = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Logout'),
            content: const Text('Are you sure you want to logout?'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, false);
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext, true);
                },
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
              ),
            ],
          );
        },
      );

      if (shouldLogout != true) {
        if (!mounted) {
          return;
        }

        setState(() {
          _isLoggingOut = false;
        });

        return;
      }

      await _authService.logout();

      if (!mounted) {
        return;
      }

      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoggingOut = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logout failed: $error'),
        ),
      );
    }
  }

  Future<void> saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final localProfile = UserProfile(
      name: _nameController.text.trim(),
      bloodGroup: _bloodGroupController.text.trim(),
      phone: _phoneController.text.trim(),
      relativeName: _relativeNameController.text.trim(),
      relativePhone: _relativePhoneController.text.trim(),
      address: _addressController.text.trim(),
    );

    UserProfile profileToReturn = localProfile;
    bool syncedWithLaravel = false;

    try {
      // 1. Save locally first
      await _profileLocalService.saveProfile(localProfile);

      // 2. Update Firebase display name
      final firebaseUser = FirebaseAuth.instance.currentUser;

      if (firebaseUser != null && localProfile.name.isNotEmpty) {
        try {
          await firebaseUser.updateDisplayName(localProfile.name);
          await firebaseUser.reload();
        } catch (error) {
          debugPrint('Firebase display name update failed: $error');
        }
      }

      // 3. Try syncing with Laravel
      try {
        final serverProfile = await _profileApiService.updateProfile(
          localProfile,
        );

        await _profileLocalService.saveProfile(serverProfile);

        // Laravel sync worked, so pending flag can be removed.
        await _profileLocalService.clearProfilePendingSync();

        profileToReturn = serverProfile;
        syncedWithLaravel = true;
      } catch (error) {
        // Laravel sync failed, so mark this profile for future sync.
        await _profileLocalService.markProfilePendingSync();

        debugPrint('Laravel profile sync failed: $error');
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            syncedWithLaravel
                ? 'Profile saved and synced'
                : 'Profile saved locally. Sync will happen when internet is available.',
          ),
        ),
      );

      Navigator.pop(context, profileToReturn);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profile save failed: $error'),
        ),
      );
    }
  }

  String? requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required';
    }

    return null;
  }

  Widget buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Profile'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _isLoggingOut ? null : logout,
            tooltip: 'Logout',
            icon: _isLoggingOut
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.logout),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_isLoadingServerProfile) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
            ],

            buildTextField(
              controller: _nameController,
              label: 'Full Name',
              icon: Icons.person,
              validator: requiredValidator,
            ),
            const SizedBox(height: 12),

            buildTextField(
              controller: _bloodGroupController,
              label: 'Blood Group',
              icon: Icons.bloodtype,
            ),
            const SizedBox(height: 12),

            buildTextField(
              controller: _phoneController,
              label: 'Your Phone Number',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
              validator: requiredValidator,
            ),
            const SizedBox(height: 12),

            buildTextField(
              controller: _relativeNameController,
              label: 'Emergency Relative Name',
              icon: Icons.family_restroom,
              validator: requiredValidator,
            ),
            const SizedBox(height: 12),

            buildTextField(
              controller: _relativePhoneController,
              label: 'Emergency Relative Phone',
              icon: Icons.contact_phone,
              keyboardType: TextInputType.phone,
              validator: requiredValidator,
            ),
            const SizedBox(height: 12),

            buildTextField(
              controller: _addressController,
              label: 'Address',
              icon: Icons.home,
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : saveProfile,
                icon: const Icon(Icons.save),
                label: Text(_isSaving ? 'Saving...' : 'Save Profile'),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoggingOut ? null : logout,
                icon: const Icon(Icons.logout),
                label: Text(_isLoggingOut ? 'Logging out...' : 'Logout'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}