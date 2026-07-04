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

  final UserProfileApiService _profileApiService = UserProfileApiService();

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

  static const Color _dangerRed = Color(0xFFE53935);
  static const Color _dangerDark = Color(0xFFB91C1C);
  static const Color _darkText = Color(0xFF111827);
  static const Color _mutedText = Color(0xFF6B7280);
  static const Color _softBg = Color(0xFFF8FAFC);
  static const Color _borderColor = Color(0xFFE5E7EB);

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

        showInfo('Cancel active SOS before logging out');

        return;
      }

      final shouldLogout = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: const Text(
              'Logout',
              style: TextStyle(
                fontWeight: FontWeight.w900,
              ),
            ),
            content: const Text(
              'Are you sure you want to logout from your SOS account?',
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
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Logout'),
                style: FilledButton.styleFrom(
                  backgroundColor: _dangerRed,
                  foregroundColor: Colors.white,
                ),
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

      showError('Logout failed: $error');
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
      await _profileLocalService.saveProfile(localProfile);

      final firebaseUser = FirebaseAuth.instance.currentUser;

      if (firebaseUser != null && localProfile.name.isNotEmpty) {
        try {
          await firebaseUser.updateDisplayName(localProfile.name);
          await firebaseUser.reload();
        } catch (error) {
          debugPrint('Firebase display name update failed: $error');
        }
      }

      try {
        final serverProfile = await _profileApiService.updateProfile(
          localProfile,
        );

        await _profileLocalService.saveProfile(serverProfile);

        await _profileLocalService.clearProfilePendingSync();

        profileToReturn = serverProfile;
        syncedWithLaravel = true;
      } catch (error) {
        await _profileLocalService.markProfilePendingSync();

        debugPrint('Laravel profile sync failed: $error');
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      showInfo(
        syncedWithLaravel
            ? 'Profile saved and synced'
            : 'Profile saved locally. Sync will happen when internet is available.',
      );

      Navigator.pop(context, profileToReturn);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      showError('Profile save failed: $error');
    }
  }

  String? requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required';
    }

    return null;
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
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(''),
      ),
    );

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
    TextInputAction textInputAction = TextInputAction.next,
  }) {
    final bool isMultiline = maxLines > 1;

    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: isMultiline
          ? TextInputType.multiline
          : keyboardType ?? TextInputType.text,
      maxLines: maxLines,
      textInputAction: isMultiline
          ? TextInputAction.newline
          : textInputAction,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _softBg,
      appBar: AppBar(
        title: const Text('Emergency Profile'),
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
                : const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildProfileHeader(),
                      const SizedBox(height: 18),
                      if (_isLoadingServerProfile) ...[
                        _buildSyncingBox(),
                        const SizedBox(height: 16),
                      ],
                      _buildFormCard(),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _isSaving ? null : saveProfile,
                        icon: _isSaving
                            ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : const Icon(Icons.save_rounded),
                        label: Text(
                          _isSaving ? 'Saving...' : 'Save Profile',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: _dangerRed,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _isLoggingOut ? null : logout,
                        icon: _isLoggingOut
                            ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                            : const Icon(Icons.logout_rounded),
                        label: Text(
                          _isLoggingOut ? 'Logging out...' : 'Logout',
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildLogoutCard(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
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
              Icons.health_and_safety_rounded,
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
                  'Your Safety Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Keep these details updated for emergency alerts.',
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

  Widget _buildSyncingBox() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _borderColor,
        ),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: _dangerRed,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Loading latest profile details...',
              style: TextStyle(
                color: _mutedText,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
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
            'Personal Details',
            style: TextStyle(
              color: _darkText,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'These details may help your trusted contacts during an emergency.',
            style: TextStyle(
              color: _mutedText,
              fontSize: 13.5,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          buildTextField(
            controller: _nameController,
            label: 'Full Name',
            icon: Icons.person_outline_rounded,
            validator: requiredValidator,
          ),
          const SizedBox(height: 14),
          buildTextField(
            controller: _bloodGroupController,
            label: 'Blood Group',
            icon: Icons.bloodtype_outlined,
          ),
          const SizedBox(height: 14),
          buildTextField(
            controller: _phoneController,
            label: 'Your Phone Number',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            validator: requiredValidator,
          ),
          const SizedBox(height: 14),
          buildTextField(
            controller: _relativeNameController,
            label: 'Emergency Relative Name',
            icon: Icons.family_restroom_outlined,
            validator: requiredValidator,
          ),
          const SizedBox(height: 14),
          buildTextField(
            controller: _relativePhoneController,
            label: 'Emergency Relative Phone',
            icon: Icons.contact_phone_outlined,
            keyboardType: TextInputType.phone,
            validator: requiredValidator,
          ),
          const SizedBox(height: 14),
          buildTextField(
            controller: _addressController,
            label: 'Address',
            icon: Icons.home_outlined,
            maxLines: 3,
            textInputAction: TextInputAction.done,
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _dangerRed.withOpacity(0.06),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _dangerRed.withOpacity(0.15),
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
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'For safety, logout is blocked while an SOS alert is active.',
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