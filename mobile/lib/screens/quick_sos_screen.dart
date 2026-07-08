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

  static const Color _bgColor = Color(0xFF0B1120);
  static const Color _cardColor = Color(0xFF111827);
  static const Color _fieldColor = Color(0xFF0F172A);
  static const Color _borderColor = Color(0xFF243041);
  static const Color _dangerRed = Color(0xFFEF4444);
  static const Color _dangerDark = Color(0xFFB91C1C);
  static const Color _warningAmber = Color(0xFFF59E0B);
  static const Color _primaryText = Color(0xFFF8FAFC);
  static const Color _mutedText = Color(0xFF94A3B8);

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
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text(
          'Quick SOS',
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
              onPressed: cancelQuickSos,
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
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(22),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildHeaderCard(),
                    const SizedBox(height: 26),
                    _buildCountdownCircle(),
                    const SizedBox(height: 18),
                    Text(
                      'Starting SOS in $_secondsLeft second${_secondsLeft == 1 ? '' : 's'}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _primaryText,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Emergency alert will start automatically after countdown.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _mutedText,
                        fontSize: 13.5,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 34),
                    _buildStartNowButton(),
                    const SizedBox(height: 14),
                    _buildCancelButton(),
                    const SizedBox(height: 20),
                    _buildSafetyNote(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
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
        children: [
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _dangerRed.withOpacity(0.30),
                  blurRadius: 36,
                  spreadRadius: 6,
                ),
              ],
              gradient: const RadialGradient(
                colors: [
                  Color(0xFFF87171),
                  _dangerRed,
                  _dangerDark,
                ],
                stops: [0.0, 0.65, 1.0],
              ),
              border: Border.all(
                color: Colors.white24,
                width: 2.5,
              ),
            ),
            child: const Icon(
              Icons.sos_rounded,
              color: Colors.white,
              size: 66,
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Quick SOS',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _primaryText,
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'This screen gives you 3 seconds to cancel before the emergency alert starts.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 14.5,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownCircle() {
    return Container(
      width: 126,
      height: 126,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _cardColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: _dangerRed.withOpacity(0.35),
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: _dangerRed.withOpacity(0.22),
            blurRadius: 34,
            spreadRadius: 4,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.34),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Text(
        '$_secondsLeft',
        style: const TextStyle(
          color: _dangerRed,
          fontSize: 58,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildStartNowButton() {
    return Container(
      width: double.infinity,
      height: 58,
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
        onPressed: startSosNow,
        icon: const Icon(Icons.warning_amber_rounded),
        label: const Text(
          'Start SOS Now',
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
          ),
        ),
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
    );
  }

  Widget _buildCancelButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        onPressed: cancelQuickSos,
        icon: const Icon(Icons.close_rounded),
        label: const Text(
          'Cancel Quick SOS',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFCBD5E1),
          side: const BorderSide(
            color: _borderColor,
          ),
          backgroundColor: _fieldColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  Widget _buildSafetyNote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _fieldColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _warningAmber.withOpacity(0.22),
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
              'This countdown prevents accidental SOS alerts. Press cancel if this was opened by mistake.',
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
}