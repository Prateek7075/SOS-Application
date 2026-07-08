import 'package:flutter/material.dart';

import '../services/custom_sos_message_local_service.dart';

class CustomSosMessageScreen extends StatefulWidget {
  const CustomSosMessageScreen({super.key});

  @override
  State<CustomSosMessageScreen> createState() => _CustomSosMessageScreenState();
}

class _CustomSosMessageScreenState extends State<CustomSosMessageScreen> {
  final CustomSosMessageLocalService _messageLocalService =
  CustomSosMessageLocalService();

  final TextEditingController _messageController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  static const String _defaultMessage = 'I need help.';

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
    loadSavedMessage();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> loadSavedMessage() async {
    final savedMessage = await _messageLocalService.getMessage();

    if (!mounted) {
      return;
    }

    setState(() {
      _messageController.text = savedMessage ?? '';
      _isLoading = false;
    });
  }

  String getCurrentMessage() {
    final message = _messageController.text.trim();

    if (message.isEmpty) {
      return _defaultMessage;
    }

    return message;
  }

  String getPreviewMessage() {
    return '''
EMERGENCY SOS!
${getCurrentMessage()}

Name: Your Name
Phone: Your Phone
Blood Group: Your Blood Group
Emergency Relative: Relative Name - Relative Phone
Address: Your Address

Live tracking link:
https://your-tracking-link.com/track/example

Battery: 52%

My current location:
https://maps.google.com/?q=28.1234567,77.1234567

Please contact me immediately.
''';
  }

  Future<void> saveMessage() async {
    final message = _messageController.text.trim();

    if (message.length > 250) {
      showError('Please keep the message under 250 characters.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _messageLocalService.saveMessage(message);

      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      showInfo(
        message.isEmpty
            ? 'Default SOS message will be used'
            : 'Custom SOS message saved',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      showError('Could not save SOS message');
    }
  }

  Future<void> resetMessage() async {
    final shouldReset = await showDialog<bool>(
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
                  Icons.restart_alt_rounded,
                  color: _dangerRed,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Reset message?',
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
            'This will remove your custom message and use the default message: "I need help."',
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
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: _dangerRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Reset',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldReset != true) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _messageLocalService.clearMessage();

      if (!mounted) {
        return;
      }

      setState(() {
        _messageController.clear();
        _isSaving = false;
      });

      showInfo('SOS message reset to default');
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      showError('Could not reset SOS message');
    }
  }

  void showInfo(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _cardColor,
      ),
    );
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

  InputDecoration _messageInputDecoration() {
    return InputDecoration(
      hintText: 'Example: I am in danger. Please call me immediately.',
      alignLabelWithHint: true,
      prefixIcon: const Padding(
        padding: EdgeInsets.only(bottom: 82),
        child: Icon(
          Icons.message_outlined,
          color: _mutedText,
        ),
      ),
      hintStyle: TextStyle(
        color: _mutedText.withOpacity(0.7),
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: _fieldColor,
      counterStyle: const TextStyle(
        color: _mutedText,
        fontWeight: FontWeight.w600,
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
        border: Border.all(
          color: color.withOpacity(0.28),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: color,
          ),
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

  Widget _buildHeaderCard() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                  Icons.edit_note_rounded,
                  color: _dangerRed,
                  size: 38,
                ),
              ),
              const SizedBox(width: 15),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SOS Message',
                      style: TextStyle(
                        color: _primaryText,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Customize the emergency text sent in SMS alerts.',
                      style: TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 13.8,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildStatusBadge(
                icon: Icons.sms_rounded,
                label: 'SMS alert text',
                color: _mapBlue,
              ),
              _buildStatusBadge(
                icon: Icons.location_on_rounded,
                label: 'Location added',
                color: _successGreen,
              ),
              _buildStatusBadge(
                icon: Icons.battery_5_bar_rounded,
                label: 'Battery added',
                color: _warningAmber,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditorCard() {
    final currentLength = _messageController.text.trim().length;

    return Container(
      padding: const EdgeInsets.all(18),
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
            'Custom SOS Message',
            style: TextStyle(
              color: _primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'This replaces only the line "I need help." Location, battery, profile and tracking link will still be added automatically.',
            style: TextStyle(
              color: _mutedText,
              fontSize: 13.5,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _messageController,
            maxLines: 5,
            maxLength: 250,
            textInputAction: TextInputAction.newline,
            keyboardType: TextInputType.multiline,
            style: const TextStyle(
              color: _primaryText,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
            cursorColor: _mapBlue,
            onChanged: (_) {
              setState(() {});
            },
            decoration: _messageInputDecoration(),
          ),
          const SizedBox(height: 4),
          Text(
            currentLength == 0
                ? 'Default message will be used: "$_defaultMessage"'
                : '$currentLength / 250 characters',
            style: TextStyle(
              color: currentLength > 250 ? _dangerRed : _mutedText,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: _borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(
                Icons.preview_rounded,
                color: _dangerRed,
              ),
              SizedBox(width: 9),
              Text(
                'Preview SMS',
                style: TextStyle(
                  color: _primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: _fieldColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _borderColor,
              ),
            ),
            child: Text(
              getPreviewMessage(),
              style: const TextStyle(
                color: Color(0xFFCBD5E1),
                fontSize: 13.5,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
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
            onPressed: _isSaving ? null : saveMessage,
            icon: _isSaving
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : const Icon(Icons.verified_rounded),
            label: Text(
              _isSaving ? 'Saving Message...' : 'Save SOS Message',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15.5,
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
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 54,
          child: OutlinedButton.icon(
            onPressed: _isSaving ? null : resetMessage,
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text(
              'Reset to Default',
              style: TextStyle(
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
        ),
      ],
    );
  }

  Widget _buildSafetyNote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _fieldColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _borderColor,
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: _warningAmber,
            size: 22,
          ),
          SizedBox(width: 11),
          Expanded(
            child: Text(
              'Keep your message short and clear. In an emergency, your contacts should immediately understand that you need help.',
              style: TextStyle(
                color: _mutedText,
                fontSize: 13.3,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView() {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text(
          'SOS Message',
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
          child: _isLoading
              ? _buildLoadingView()
              : ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeaderCard(),
                      const SizedBox(height: 22),
                      _buildEditorCard(),
                      const SizedBox(height: 18),
                      _buildPreviewCard(),
                      const SizedBox(height: 18),
                      _buildSafetyNote(),
                      const SizedBox(height: 22),
                      _buildButtons(),
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
}