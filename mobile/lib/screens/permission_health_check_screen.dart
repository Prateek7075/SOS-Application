import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/emergency_contact.dart';
import '../models/user_profile.dart';
import '../services/emergency_contact_local_service.dart';
import '../services/network_service.dart';
import '../services/user_profile_local_service.dart';

class PermissionHealthCheckScreen extends StatefulWidget {
  const PermissionHealthCheckScreen({super.key});

  @override
  State<PermissionHealthCheckScreen> createState() =>
      _PermissionHealthCheckScreenState();
}

class _PermissionHealthCheckScreenState
    extends State<PermissionHealthCheckScreen> {
  final EmergencyContactLocalService _contactLocalService =
  EmergencyContactLocalService();

  final UserProfileLocalService _profileLocalService =
  UserProfileLocalService();

  final NetworkService _networkService = NetworkService();

  bool _isLoading = true;

  bool _locationPermissionReady = false;
  bool _gpsEnabled = false;
  bool _smsPermissionReady = false;
  bool _contactsPermissionReady = false;
  bool _hasTrustedContacts = false;
  bool _profileCompleted = false;

  String _networkStatus = 'Checking...';
  int _trustedContactCount = 0;

  static const Color _dangerRed = Color(0xFFE53935);
  static const Color _dangerDark = Color(0xFFB91C1C);
  static const Color _darkText = Color(0xFF111827);
  static const Color _mutedText = Color(0xFF6B7280);
  static const Color _softBg = Color(0xFFF8FAFC);
  static const Color _borderColor = Color(0xFFE5E7EB);
  static const Color _successGreen = Color(0xFF16A34A);
  static const Color _warningOrange = Color(0xFFF97316);

  @override
  void initState() {
    super.initState();
    runHealthCheck();
  }

  Future<void> runHealthCheck() async {
    setState(() {
      _isLoading = true;
    });

    final locationPermission = await Geolocator.checkPermission();
    final gpsEnabled = await Geolocator.isLocationServiceEnabled();

    final smsPermission = await Permission.sms.status;
    final contactsPermission = await Permission.contacts.status;

    final contacts = await _contactLocalService.getContacts();
    final profile = await _profileLocalService.getProfile();

    String networkStatus = 'Unknown';

    try {
      networkStatus = await _networkService.getNetworkStatus();
    } catch (_) {
      networkStatus = 'Could not check';
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _locationPermissionReady =
          locationPermission == LocationPermission.always ||
              locationPermission == LocationPermission.whileInUse;

      _gpsEnabled = gpsEnabled;

      _smsPermissionReady = smsPermission.isGranted;
      _contactsPermissionReady = contactsPermission.isGranted;

      _trustedContactCount = contacts.length;
      _hasTrustedContacts = contacts.isNotEmpty;

      _profileCompleted = isProfileCompleted(profile);

      _networkStatus = networkStatus;

      _isLoading = false;
    });
  }

  bool isProfileCompleted(UserProfile? profile) {
    if (profile == null) {
      return false;
    }

    return profile.name.trim().isNotEmpty &&
        profile.phone.trim().isNotEmpty &&
        profile.relativeName.trim().isNotEmpty &&
        profile.relativePhone.trim().isNotEmpty;
  }

  int getReadyCount() {
    int count = 0;

    if (_locationPermissionReady) count++;
    if (_gpsEnabled) count++;
    if (_smsPermissionReady) count++;
    if (_contactsPermissionReady) count++;
    if (_hasTrustedContacts) count++;
    if (_profileCompleted) count++;

    return count;
  }

  int getTotalChecks() {
    return 6;
  }

  bool isSosReady() {
    return _locationPermissionReady &&
        _gpsEnabled &&
        _smsPermissionReady &&
        _hasTrustedContacts &&
        _profileCompleted;
  }

  Future<void> requestLocationPermission() async {
    await Geolocator.requestPermission();
    await runHealthCheck();
  }

  Future<void> requestSmsPermission() async {
    await Permission.sms.request();
    await runHealthCheck();
  }

  Future<void> requestContactsPermission() async {
    await Permission.contacts.request();
    await runHealthCheck();
  }

  Future<void> openAppSettingsPage() async {
    await openAppSettings();
    await runHealthCheck();
  }

  Color getOverallColor() {
    if (isSosReady()) {
      return _successGreen;
    }

    if (getReadyCount() >= 4) {
      return _warningOrange;
    }

    return _dangerRed;
  }

  String getOverallTitle() {
    if (isSosReady()) {
      return 'Ready for SOS';
    }

    if (getReadyCount() >= 4) {
      return 'Almost Ready';
    }

    return 'Needs Attention';
  }

  String getOverallSubtitle() {
    if (isSosReady()) {
      return 'Your app has the important permissions and details needed for SOS.';
    }

    return 'Some important permissions or emergency details are missing.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _softBg,
      appBar: AppBar(
        title: const Text('Safety Check'),
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
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : runHealthCheck,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
          child: CircularProgressIndicator(
            color: _dangerRed,
          ),
        )
            : RefreshIndicator(
          color: _dangerRed,
          onRefresh: runHealthCheck,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildOverallCard(),
                      const SizedBox(height: 20),
                      _buildHealthChecksCard(),
                      const SizedBox(height: 18),
                      _buildInternetCard(),
                      const SizedBox(height: 18),
                      _buildBatteryOptimizationCard(),
                      const SizedBox(height: 20),
                      _buildRefreshButton(),
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

  Widget _buildOverallCard() {
    final overallColor = getOverallColor();

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isSosReady()
              ? [
            _successGreen,
            const Color(0xFF15803D),
          ]
              : [
            _dangerRed,
            _dangerDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: overallColor.withOpacity(0.25),
            blurRadius: 26,
            offset: const Offset(0, 13),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isSosReady()
                  ? Icons.shield_rounded
                  : Icons.warning_amber_rounded,
              color: Colors.white,
              size: 38,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  getOverallTitle(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${getReadyCount()} of ${getTotalChecks()} checks ready',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  getOverallSubtitle(),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.86),
                    fontSize: 13.5,
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

  Widget _buildHealthChecksCard() {
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
            'Permission Health Check',
            style: TextStyle(
              color: _darkText,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'These checks help confirm your SOS app can work during emergency.',
            style: TextStyle(
              color: _mutedText,
              fontSize: 13.5,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          _buildCheckTile(
            icon: Icons.location_on_outlined,
            title: 'Location Permission',
            subtitle: _locationPermissionReady
                ? 'Location permission is allowed'
                : 'Location permission is required for SOS location',
            isReady: _locationPermissionReady,
            actionLabel: _locationPermissionReady ? null : 'Allow',
            onAction: _locationPermissionReady ? null : requestLocationPermission,
          ),
          _buildCheckTile(
            icon: Icons.gps_fixed_rounded,
            title: 'GPS / Location Service',
            subtitle: _gpsEnabled
                ? 'GPS is enabled'
                : 'Turn on phone location/GPS',
            isReady: _gpsEnabled,
            actionLabel: _gpsEnabled ? null : 'Settings',
            onAction: _gpsEnabled ? null : openAppSettingsPage,
          ),
          _buildCheckTile(
            icon: Icons.sms_outlined,
            title: 'SMS Permission',
            subtitle: _smsPermissionReady
                ? 'SMS permission is allowed'
                : 'SMS permission is required for offline fallback',
            isReady: _smsPermissionReady,
            actionLabel: _smsPermissionReady ? null : 'Allow',
            onAction: _smsPermissionReady ? null : requestSmsPermission,
          ),
          _buildCheckTile(
            icon: Icons.contacts_rounded,
            title: 'Contacts Permission',
            subtitle: _contactsPermissionReady
                ? 'Contacts permission is allowed'
                : 'Needed only when importing contacts from phone',
            isReady: _contactsPermissionReady,
            actionLabel: _contactsPermissionReady ? null : 'Allow',
            onAction:
            _contactsPermissionReady ? null : requestContactsPermission,
            isOptional: true,
          ),
          _buildCheckTile(
            icon: Icons.groups_outlined,
            title: 'Trusted Contacts',
            subtitle: _hasTrustedContacts
                ? '$_trustedContactCount trusted contact${_trustedContactCount == 1 ? '' : 's'} added'
                : 'Add at least one trusted contact',
            isReady: _hasTrustedContacts,
          ),
          _buildCheckTile(
            icon: Icons.badge_outlined,
            title: 'Emergency Profile',
            subtitle: _profileCompleted
                ? 'Emergency profile is completed'
                : 'Name, phone, relative name and relative phone are required',
            isReady: _profileCompleted,
          ),
        ],
      ),
    );
  }

  Widget _buildCheckTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isReady,
    String? actionLabel,
    VoidCallback? onAction,
    bool isOptional = false,
  }) {
    final Color statusColor = isReady
        ? _successGreen
        : isOptional
        ? _warningOrange
        : _dangerRed;

    final String statusText = isReady
        ? 'Ready'
        : isOptional
        ? 'Optional'
        : 'Needed';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusColor.withOpacity(0.14),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              icon,
              color: statusColor,
              size: 23,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _darkText,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _mutedText,
                    fontSize: 13.2,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 38,
                    child: OutlinedButton(
                      onPressed: onAction,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: statusColor,
                        side: BorderSide(
                          color: statusColor.withOpacity(0.35),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      child: Text(actionLabel),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInternetCard() {
    final bool noInternet = _networkStatus == 'No internet';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _borderColor,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: noInternet
                  ? _warningOrange.withOpacity(0.1)
                  : _successGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              noInternet
                  ? Icons.wifi_off_rounded
                  : Icons.wifi_tethering_rounded,
              color: noInternet ? _warningOrange : _successGreen,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Internet Status',
                  style: TextStyle(
                    color: _darkText,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  noInternet
                      ? 'No internet. SMS fallback can still work.'
                      : _networkStatus,
                  style: const TextStyle(
                    color: _mutedText,
                    fontSize: 13.5,
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

  Widget _buildBatteryOptimizationCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _warningOrange.withOpacity(0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _warningOrange.withOpacity(0.15),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.battery_alert_outlined,
            color: _warningOrange,
            size: 24,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Battery optimization can stop background location on some phones. If live tracking stops in background, disable battery optimization for this app from phone settings.',
              style: TextStyle(
                color: _mutedText,
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

  Widget _buildRefreshButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton.icon(
        onPressed: _isLoading ? null : runHealthCheck,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text(
          'Run Check Again',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: _dangerRed,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
        ),
      ),
    );
  }
}