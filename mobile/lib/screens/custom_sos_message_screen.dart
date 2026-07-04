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

  static const Color _dangerRed = Color(0xFFE53935);
  static const Color _dangerDark = Color(0xFFB91C1C);
  static const Color _darkText = Color(0xFF111827);
  static const Color _mutedText = Color(0xFF6B7280);
  static const Color _softBg = Color(0xFFF8FAFC);
  static const Color _borderColor = Color(0xFFE5E7EB);

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
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Reset message?',
            style: TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
          content: const Text(
            'This will remove your custom message and use the default message: "I need help."',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: _dangerRed,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reset'),
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

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            _dangerRed,
            _dangerDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _dangerRed.withOpacity(0.25),
            blurRadius: 26,
            offset: const Offset(0, 13),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.edit_note_rounded,
              color: Colors.white,
              size: 38,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SOS Message',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Customize the emergency text sent in SMS alerts.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.88),
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
    );
  }

  Widget _buildEditorCard() {
    final currentLength = _messageController.text.trim().length;

    return Container(
      padding: const EdgeInsets.all(18),
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
            'Custom SOS Message',
            style: TextStyle(
              color: _darkText,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'This will replace only the line "I need help." Location, battery, profile and tracking link will still be added automatically.',
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
            onChanged: (_) {
              setState(() {});
            },
            decoration: InputDecoration(
              hintText: 'Example: I am in danger. Please call me immediately.',
              alignLabelWithHint: true,
              prefixIcon: const Padding(
                padding: EdgeInsets.only(bottom: 82),
                child: Icon(Icons.message_outlined),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
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
        color: Colors.white,
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
                  color: _darkText,
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
              color: _softBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _borderColor,
              ),
            ),
            child: Text(
              getPreviewMessage(),
              style: const TextStyle(
                color: _darkText,
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
        SizedBox(
          height: 54,
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
                : const Icon(Icons.save_rounded),
            label: Text(
              _isSaving ? 'Saving...' : 'Save Message',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _dangerRed,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _dangerRed.withOpacity(0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(17),
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
              foregroundColor: _dangerRed,
              side: BorderSide(
                color: _dangerRed.withOpacity(0.4),
              ),
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
        color: _dangerRed.withOpacity(0.06),
        borderRadius: BorderRadius.circular(22),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _softBg,
      appBar: AppBar(
        title: const Text('SOS Message'),
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
        child: _isLoading
            ? const Center(
          child: CircularProgressIndicator(
            color: _dangerRed,
          ),
        )
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
    );
  }
}