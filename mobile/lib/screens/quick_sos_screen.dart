import 'dart:async';

import 'package:flutter/material.dart';

import 'active_sos_screen.dart';

class QuickSosScreen extends StatefulWidget {
  const QuickSosScreen({super.key});

  @override
  State<QuickSosScreen> createState() => _QuickSosScreenState();
}

class _QuickSosScreenState extends State<QuickSosScreen> {
  Timer? _timer;
  int _secondsLeft = 3;
  bool _hasStarted = false;

  static const Color _dangerRed = Color(0xFFE53935);
  static const Color _dangerDark = Color(0xFFB91C1C);
  static const Color _darkText = Color(0xFF111827);
  static const Color _mutedText = Color(0xFF6B7280);
  static const Color _softBg = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void startCountdown() {
    _timer?.cancel();

    _timer = Timer.periodic(
      const Duration(seconds: 1),
          (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (_secondsLeft <= 1) {
          timer.cancel();
          startSosNow();
          return;
        }

        setState(() {
          _secondsLeft--;
        });
      },
    );
  }

  Future<void> startSosNow() async {
    if (_hasStarted) {
      return;
    }

    _hasStarted = true;
    _timer?.cancel();

    await Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const ActiveSosScreen(),
      ),
          (route) => route.isFirst,
    );
  }

  void cancelQuickSos() {
    _timer?.cancel();
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _softBg,
      appBar: AppBar(
        title: const Text('Quick SOS'),
        backgroundColor: _softBg,
        foregroundColor: _darkText,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: cancelQuickSos,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 132,
                    height: 132,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          _dangerRed,
                          _dangerDark,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _dangerRed.withOpacity(0.3),
                          blurRadius: 34,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.sos_rounded,
                      color: Colors.white,
                      size: 74,
                    ),
                  ),

                  const SizedBox(height: 28),

                  const Text(
                    'Quick SOS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _darkText,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                    ),
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    'Emergency alert will start automatically after countdown.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _mutedText,
                      fontSize: 15,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 34),

                  Container(
                    width: 118,
                    height: 118,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _dangerRed.withOpacity(0.18),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Text(
                      '$_secondsLeft',
                      style: const TextStyle(
                        color: _dangerRed,
                        fontSize: 54,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  Text(
                    'Starting SOS in $_secondsLeft second${_secondsLeft == 1 ? '' : 's'}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _darkText,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 34),

                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: FilledButton.icon(
                      onPressed: startSosNow,
                      icon: const Icon(Icons.warning_amber_rounded),
                      label: const Text(
                        'Start SOS Now',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: _dangerRed,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: cancelQuickSos,
                      icon: const Icon(Icons.close_rounded),
                      label: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _darkText,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'This countdown prevents accidental SOS alerts.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _mutedText,
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}