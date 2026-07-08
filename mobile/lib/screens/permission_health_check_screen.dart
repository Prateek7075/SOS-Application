import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/user_profile.dart';
import '../services/emergency_contact_local_service.dart';
import '../services/network_service.dart';
import '../services/user_profile_local_service.dart';
import '../services/battery_optimization_service.dart';

class PermissionHealthCheckScreen extends StatefulWidget {
  const PermissionHealthCheckScreen({super.key});

  @override
  State<PermissionHealthCheckScreen> createState() => _PermissionHealthCheckScreenState();
}

class _PermissionHealthCheckScreenState
    extends State<PermissionHealthCheckScreen> {

  final EmergencyContactLocalService _contactLocalService = EmergencyContactLocalService();

  final UserProfileLocalService _profileLocalService = UserProfileLocalService();

  final BatteryOptimizationService _batteryOptimizationService = BatteryOptimizationService();

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

  bool _batteryOptimizationReady = false;
  String _batteryOptimizationStatus = 'Checking...';

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

    bool batteryOptimizationReady = false;
    String batteryOptimizationStatus = 'Could not check';

    try {
      batteryOptimizationReady =
      await _batteryOptimizationService.isIgnoringBatteryOptimizations();

      batteryOptimizationStatus = batteryOptimizationReady
          ? 'Unrestricted / allowed'
          : 'Restricted - background tracking may stop';
    } catch (_) {
      batteryOptimizationReady = false;
      batteryOptimizationStatus = 'Could not check battery optimization';
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

      _batteryOptimizationReady = batteryOptimizationReady;
      _batteryOptimizationStatus = batteryOptimizationStatus;

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
    if (_batteryOptimizationReady) count++;

    return count;
  }

  int getTotalChecks() {
    return 7;
  }

  bool isSosReady() {
    return _locationPermissionReady &&
        _gpsEnabled &&
        _smsPermissionReady &&
        _hasTrustedContacts &&
        _profileCompleted &&
        _batteryOptimizationReady;
  }

  Future<void> requestLocationPermission() async {
    await Geolocator.requestPermission();
    await runHealthCheck();
  }

  Future<void> requestSmsPermission() async {
    await Permission.sms.request();
    await runHealthCheck();
  }

  Future<void> openBatteryOptimizationSettingsPage() async {
    await _batteryOptimizationService.openBatteryOptimizationSettings();
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
      return _warningAmber;
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
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text(
          'Safety Check',
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
                tooltip: 'Refresh',
                onPressed: _isLoading ? null : runHealthCheck,
                icon: const Icon(
                  Icons.refresh_rounded,
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
          child: _isLoading
              ? _buildLoadingView()
              : RefreshIndicator(
            color: _dangerRed,
            backgroundColor: _cardColor,
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

  Widget _buildOverallCard() {
    final overallColor = getOverallColor();

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
          color: overallColor.withOpacity(0.35),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: overallColor.withOpacity(0.16),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: overallColor.withOpacity(0.35),
                  ),
                ),
                child: Icon(
                  isSosReady()
                      ? Icons.shield_rounded
                      : Icons.warning_amber_rounded,
                  color: overallColor,
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
                        color: _primaryText,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${getReadyCount()} of ${getTotalChecks()} checks ready',
                      style: TextStyle(
                        color: overallColor,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      getOverallSubtitle(),
                      style: const TextStyle(
                        color: Color(0xFFCBD5E1),
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
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: getReadyCount() / getTotalChecks(),
              minHeight: 9,
              backgroundColor: _fieldColor,
              color: overallColor,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildStatusBadge(
                icon: Icons.shield_rounded,
                label: isSosReady() ? 'SOS ready' : 'Action needed',
                color: overallColor,
              ),
              _buildStatusBadge(
                icon: Icons.sms_rounded,
                label: 'SMS fallback',
                color: _mapBlue,
              ),
              _buildStatusBadge(
                icon: Icons.location_on_rounded,
                label: 'Location based',
                color: _successGreen,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthChecksCard() {
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
            'Permission Health Check',
            style: TextStyle(
              color: _primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
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
          _buildCheckTile(
            icon: Icons.battery_alert_rounded,
            title: 'Battery Optimization',
            subtitle: _batteryOptimizationReady
                ? 'Battery optimization is unrestricted / allowed'
                : _batteryOptimizationStatus,
            isReady: _batteryOptimizationReady,
            actionLabel: _batteryOptimizationReady ? null : 'Settings',
            onAction:
            _batteryOptimizationReady ? null : openBatteryOptimizationSettingsPage,
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
        ? _warningAmber
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
        color: _fieldColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusColor.withOpacity(0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.14),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: statusColor.withOpacity(0.24),
              ),
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
                    color: _primaryText,
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
                        backgroundColor: statusColor.withOpacity(0.08),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      child: Text(
                        actionLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
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
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: statusColor.withOpacity(0.22),
              ),
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
    final Color statusColor = noInternet ? _warningAmber : _successGreen;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardColor,
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
              color: statusColor.withOpacity(0.14),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: statusColor.withOpacity(0.24),
              ),
            ),
            child: Icon(
              noInternet
                  ? Icons.wifi_off_rounded
                  : Icons.wifi_tethering_rounded,
              color: statusColor,
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
                    color: _primaryText,
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
        color: _fieldColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _warningAmber.withOpacity(0.22),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.battery_alert_outlined,
            color: _warningAmber,
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
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _dangerRed.withOpacity(0.24),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: FilledButton.icon(
        onPressed: _isLoading ? null : runHealthCheck,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text(
          'Run Check Again',
          style: TextStyle(
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
    );
  }
}