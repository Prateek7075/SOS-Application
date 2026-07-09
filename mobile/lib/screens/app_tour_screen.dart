import 'package:flutter/material.dart';

class AppTourScreen extends StatefulWidget {
  const AppTourScreen({super.key});

  @override
  State<AppTourScreen> createState() => _AppTourScreenState();
}

class _AppTourScreenState extends State<AppTourScreen> {
  final PageController _pageController = PageController();

  int _currentPage = 0;

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

  final List<_TourItem> _tourItems = const [
    _TourItem(
      icon: Icons.sos_rounded,
      title: 'Start Emergency SOS',
      description:
      'Use the main SOS button when you are in danger. It starts emergency mode, creates a live tracking link, and alerts your trusted contacts.',
      color: _dangerRed,
    ),
    _TourItem(
      icon: Icons.location_on_rounded,
      title: 'Live Tracking',
      description:
      'During an active SOS, your latest location is updated on the tracking page so trusted contacts can follow your movement.',
      color: _mapBlue,
    ),
    _TourItem(
      icon: Icons.sms_rounded,
      title: 'SMS Fallback',
      description:
      'If internet is not available, the app can still send your current location through SMS to your trusted contacts.',
      color: _warningAmber,
    ),
    _TourItem(
      icon: Icons.contacts_rounded,
      title: 'Trusted Contacts',
      description:
      'Add or import trusted contacts. These are the people who will receive your SOS alert and location.',
      color: _successGreen,
    ),
    _TourItem(
      icon: Icons.person_rounded,
      title: 'Emergency Profile',
      description:
      'Add your name, phone number, blood group, address, and emergency relative details. These details help people assist you faster.',
      color: _mapBlue,
    ),
    _TourItem(
      icon: Icons.history_rounded,
      title: 'SOS History',
      description:
      'View your previous SOS events, starting location, last updated location, status, and time details.',
      color: _warningAmber,
    ),
    _TourItem(
      icon: Icons.widgets_rounded,
      title: 'Widget & Shortcut',
      description:
      'Use the home screen widget or quick SOS shortcut to start emergency SOS faster. Use carefully to avoid accidental alerts.',
      color: _dangerRed,
    ),
  ];

  void _goNext() {
    if (_currentPage == _tourItems.length - 1) {
      Navigator.of(context).pop(true);
      return;
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  void _skipTour() {
    Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == _tourItems.length - 1;

    return Scaffold(
      backgroundColor: _bgColor,
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
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Welcome',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: _primaryText,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _skipTour,
                      style: TextButton.styleFrom(
                        foregroundColor: _dangerRed,
                      ),
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _tourItems.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      final item = _tourItems[index];

                      return _buildTourCard(item);
                    },
                  ),
                ),
                const SizedBox(height: 18),
                _buildPageIndicators(),
                const SizedBox(height: 18),
                _buildNextButton(isLastPage),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTourCard(_TourItem item) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 118,
            height: 118,
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(36),
              border: Border.all(
                color: item.color.withOpacity(0.30),
              ),
              boxShadow: [
                BoxShadow(
                  color: item.color.withOpacity(0.24),
                  blurRadius: 32,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: Icon(
              item.icon,
              size: 62,
              color: item.color,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            item.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: _primaryText,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            item.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15.5,
              height: 1.55,
              fontWeight: FontWeight.w600,
              color: Color(0xFFCBD5E1),
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              _buildStatusBadge(
                icon: Icons.shield_rounded,
                label: 'Safety first',
                color: _successGreen,
              ),
              _buildStatusBadge(
                icon: Icons.flash_on_rounded,
                label: 'Fast action',
                color: _dangerRed,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _tourItems.length,
            (index) {
          final isActive = index == _currentPage;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 26 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive ? _dangerRed : _borderColor,
              borderRadius: BorderRadius.circular(999),
              boxShadow: isActive
                  ? [
                BoxShadow(
                  color: _dangerRed.withOpacity(0.35),
                  blurRadius: 12,
                ),
              ]
                  : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildNextButton(bool isLastPage) {
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
        onPressed: _goNext,
        icon: Icon(
          isLastPage
              ? Icons.check_circle_outline_rounded
              : Icons.arrow_forward_rounded,
        ),
        label: Text(
          isLastPage ? 'Finish Tour' : 'Next',
          style: const TextStyle(
            fontSize: 16,
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
}

class _TourItem {
  const _TourItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;
}