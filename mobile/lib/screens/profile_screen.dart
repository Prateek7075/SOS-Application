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

  final ActiveSosLocalService _activeSosLocalService = ActiveSosLocalService();

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
                    Icons.logout_rounded,
                    color: _dangerRed,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Logout?',
                    style: TextStyle(
                      color: _primaryText,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            content: const Text(
              'Are you sure you want to logout from your SOS account?',
              style: TextStyle(
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
                icon: const Icon(Icons.logout_rounded),
                label: const Text(
                  'Logout',
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

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _cardColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(
        icon,
        color: _mutedText,
      ),
      labelStyle: const TextStyle(
        color: _mutedText,
        fontWeight: FontWeight.w600,
      ),
      filled: true,
      fillColor: _fieldColor,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: _borderColor,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: _mapBlue,
          width: 1.4,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: _dangerRed,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: _dangerRed,
          width: 1.4,
        ),
      ),
      errorStyle: const TextStyle(
        color: Color(0xFFFCA5A5),
        fontWeight: FontWeight.w600,
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
      textInputAction: isMultiline ? TextInputAction.newline : textInputAction,
      style: const TextStyle(
        color: _primaryText,
        fontWeight: FontWeight.w700,
        height: 1.35,
      ),
      cursorColor: _mapBlue,
      decoration: _inputDecoration(
        label: label,
        icon: icon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text(
          'Emergency Profile',
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
                onPressed: _isLoggingOut ? null : logout,
                tooltip: 'Logout',
                icon: _isLoggingOut
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(
                  Icons.logout_rounded,
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
        child: SafeArea(
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
                        _buildSaveButton(),
                        const SizedBox(height: 12),
                        _buildLogoutButton(),
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
      ),
    );
  }

  Widget _buildProfileHeader() {
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
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: _dangerRed.withOpacity(0.16),
              shape: BoxShape.circle,
              border: Border.all(
                color: _dangerRed.withOpacity(0.35),
              ),
            ),
            child: const Icon(
              Icons.health_and_safety_rounded,
              color: _dangerRed,
              size: 36,
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
                    color: _primaryText,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Keep these details updated for emergency alerts.',
                  style: TextStyle(
                    color: Color(0xFFCBD5E1),
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
        color: _fieldColor,
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
              color: _mapBlue,
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
        color: _cardColor,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: _borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.24),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Personal Details',
            style: TextStyle(
              color: _primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
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

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _dangerRed.withOpacity(0.28),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: FilledButton.icon(
        onPressed: _isSaving ? null : saveProfile,
        icon: _isSaving
            ? const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        )
            : const Icon(Icons.save_rounded),
        label: Text(
          _isSaving ? 'Saving Profile...' : 'Save Profile',
          style: const TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: _dangerRed,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _dangerRed.withOpacity(0.45),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        onPressed: _isLoggingOut ? null : logout,
        icon: _isLoggingOut
            ? const SizedBox(
          width: 17,
          height: 17,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFFFCA5A5),
          ),
        )
            : const Icon(Icons.logout_rounded),
        label: Text(
          _isLoggingOut ? 'Logging out...' : 'Logout',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFFCA5A5),
          side: const BorderSide(
            color: _borderColor,
          ),
          backgroundColor: _fieldColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _fieldColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _dangerRed.withOpacity(0.22),
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