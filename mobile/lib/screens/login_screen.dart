import 'package:flutter/material.dart';

import '../services/auth_session_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final AuthSessionService _authSessionService = AuthSessionService();

  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _nameController = TextEditingController();

  int _step = 1;

  bool _isLoading = false;
  String? _errorMessage;
  String? _registrationToken;

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

  Future<void> requestOtp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authSessionService.requestOtp(_phoneController.text.trim());

      if (!mounted) return;

      setState(() {
        _otpController.clear();
        _step = 2;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> verifyOtp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _authSessionService.verifyOtp(
        phone: _phoneController.text.trim(),
        otp: _otpController.text.trim(),
      );

      if (!mounted) return;

      final registrationRequired = response['registration_required'] == true;

      if (registrationRequired) {
        final data = response['data'];

        if (data is! Map<String, dynamic>) {
          throw Exception('Invalid registration response.');
        }

        final token = data['registration_token'];

        if (token is! String || token.isEmpty) {
          throw Exception('Registration token is missing.');
        }

        setState(() {
          _registrationToken = token;
          _step = 3;
        });

        return;
      }

      _openHome();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> registerUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final registrationToken = _registrationToken;

    if (registrationToken == null || registrationToken.isEmpty) {
      setState(() {
        _errorMessage =
            'Registration session expired. Please request OTP again.';
        _step = 1;
      });

      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authSessionService.register(
        name: _nameController.text.trim(),
        registrationToken: registrationToken,
      );

      if (!mounted) return;

      _openHome();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _openHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  void _changePhoneNumber() {
    if (_isLoading) {
      return;
    }

    setState(() {
      _step = 1;
      _otpController.clear();
      _nameController.clear();
      _registrationToken = null;
      _errorMessage = null;
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _nameController.dispose();

    super.dispose();
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: _mutedText),
      labelStyle: const TextStyle(
        color: _mutedText,
        fontWeight: FontWeight.w600,
      ),
      filled: true,
      fillColor: _fieldColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _mapBlue, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _dangerRed),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _dangerRed, width: 1.4),
      ),
      errorStyle: const TextStyle(
        color: Color(0xFFFCA5A5),
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildStatusBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.13),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF08101E), Color(0xFF0B1120), Color(0xFF111827)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 24),
                      _buildAuthCard(),
                      const SizedBox(height: 18),
                      _buildSafetyNote(),
                    ],
                  ),
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
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF111827), Color(0xFF172033)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.28),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: _dangerRed.withOpacity(0.28), blurRadius: 10),
              ],
              gradient: const RadialGradient(
                colors: [Color(0xFFF87171), _dangerRed, _dangerDark],
                stops: [0.0, 0.65, 1.0],
              ),
              border: Border.all(color: Colors.white24, width: 2),
            ),
            child: const Icon(
              Icons.emergency_share_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Emergency SOS',
            style: TextStyle(
              color: _primaryText,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 9),
          const Text(
            'Sign in securely using your mobile number to access your SOS profile, trusted contacts, and emergency history.',
            style: TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 15,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildStatusBadge(
                icon: Icons.shield_rounded,
                label: 'Safety account',
                color: _successGreen,
              ),
              _buildStatusBadge(
                icon: Icons.sms_rounded,
                label: 'OTP secured',
                color: _mapBlue,
              ),
              _buildStatusBadge(
                icon: Icons.warning_amber_rounded,
                label: 'Emergency use',
                color: _warningAmber,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAuthCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.24),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStepTitle(),
          const SizedBox(height: 20),

          if (_step == 1) _buildPhoneField(),

          if (_step == 2) _buildOtpField(),

          if (_step == 3) _buildNameField(),

          if (_errorMessage != null) ...[
            const SizedBox(height: 18),
            _buildErrorBox(),
          ],

          const SizedBox(height: 24),

          _buildActionButton(),

          if (_step == 2) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: _isLoading ? null : _changePhoneNumber,
              child: const Text('Change mobile number'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepTitle() {
    String title;
    String subtitle;

    if (_step == 1) {
      title = 'Enter mobile number';
      subtitle = 'We will send a 6-digit OTP to verify your number.';
    } else if (_step == 2) {
      title = 'Verify OTP';
      subtitle =
          'Enter the 6-digit OTP sent to ${_phoneController.text.trim()}.';
    } else {
      title = 'Create your account';
      subtitle = 'Your mobile number is verified. Enter your name to continue.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _primaryText,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            color: _mutedText,
            fontSize: 13.5,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneField() {
    return TextFormField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.done,
      style: const TextStyle(color: _primaryText, fontWeight: FontWeight.w700),
      cursorColor: _mapBlue,
      onFieldSubmitted: (_) {
        if (!_isLoading) {
          requestOtp();
        }
      },
      decoration: _inputDecoration(
        label: 'Mobile Number',
        icon: Icons.phone_android_rounded,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Mobile number is required';
        }

        final phone = value.trim().replaceAll(RegExp(r'[\s-]+'), '');

        final valid = RegExp(r'^(\+91|91|0)?[6-9][0-9]{9}$').hasMatch(phone);

        if (!valid) {
          return 'Enter a valid Indian mobile number';
        }

        return null;
      },
    );
  }

  Widget _buildOtpField() {
    return TextFormField(
      controller: _otpController,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      maxLength: 6,
      style: const TextStyle(
        color: _primaryText,
        fontWeight: FontWeight.w700,
        letterSpacing: 6,
      ),
      cursorColor: _mapBlue,
      onFieldSubmitted: (_) {
        if (!_isLoading) {
          verifyOtp();
        }
      },
      decoration: _inputDecoration(
        label: '6-digit OTP',
        icon: Icons.password_rounded,
      ).copyWith(counterText: ''),
      validator: (value) {
        final otp = value?.trim() ?? '';

        if (otp.isEmpty) {
          return 'OTP is required';
        }

        if (!RegExp(r'^[0-9]{6}$').hasMatch(otp)) {
          return 'Enter a valid 6-digit OTP';
        }

        return null;
      },
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.done,
      style: const TextStyle(color: _primaryText, fontWeight: FontWeight.w700),
      cursorColor: _mapBlue,
      onFieldSubmitted: (_) {
        if (!_isLoading) {
          registerUser();
        }
      },
      decoration: _inputDecoration(
        label: 'Full Name',
        icon: Icons.person_outline_rounded,
      ),
      validator: (value) {
        final name = value?.trim() ?? '';

        if (name.isEmpty) {
          return 'Name is required';
        }

        if (name.length < 2) {
          return 'Name must be at least 2 characters';
        }

        return null;
      },
    );
  }

  Widget _buildActionButton() {
    String label;
    IconData icon;
    VoidCallback action;

    if (_step == 1) {
      label = _isLoading ? 'Sending OTP...' : 'Send OTP';
      icon = Icons.sms_rounded;
      action = requestOtp;
    } else if (_step == 2) {
      label = _isLoading ? 'Verifying...' : 'Verify OTP';
      icon = Icons.verified_user_rounded;
      action = verifyOtp;
    } else {
      label = _isLoading ? 'Creating Account...' : 'Continue';
      icon = Icons.person_add_alt_1_rounded;
      action = registerUser;
    }

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton.icon(
        onPressed: _isLoading ? null : action,
        icon: _isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: _dangerRed,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _dangerRed.withOpacity(0.45),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _dangerRed.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _dangerRed.withOpacity(0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: _dangerRed, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                color: Color(0xFFFCA5A5),
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyNote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _fieldColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: _successGreen, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your emergency details are used to help trusted contacts during SOS alerts.',
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
