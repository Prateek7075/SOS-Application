import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/user_profile.dart';
import 'background_location_service.dart';
import 'battery_optimization_service.dart';
import 'emergency_contact_local_service.dart';
import 'network_service.dart';
import 'user_profile_local_service.dart';

enum SafetyIssueSeverity { critical, warning }

class SafetyIssue {
  const SafetyIssue({
    required this.key,
    required this.title,
    required this.message,
    required this.severity,
  });

  final String key;
  final String title;
  final String message;
  final SafetyIssueSeverity severity;
}

class SafetyCheckResult {
  const SafetyCheckResult({
    required this.issues,
    required this.readyCount,
    required this.totalChecks,
    required this.networkStatus,
  });

  final List<SafetyIssue> issues;
  final int readyCount;
  final int totalChecks;
  final String networkStatus;

  List<SafetyIssue> get criticalIssues {
    return issues.where((issue) {
      return issue.severity == SafetyIssueSeverity.critical;
    }).toList();
  }

  List<SafetyIssue> get warningIssues {
    return issues.where((issue) {
      return issue.severity == SafetyIssueSeverity.warning;
    }).toList();
  }

  bool get hasIssues => issues.isNotEmpty;

  bool get hasCriticalIssues => criticalIssues.isNotEmpty;

  bool get isReady => !hasCriticalIssues;
}

class SafetyCheckService {
  final EmergencyContactLocalService _contactLocalService =
      EmergencyContactLocalService();

  final UserProfileLocalService _profileLocalService =
      UserProfileLocalService();

  final BatteryOptimizationService _batteryOptimizationService =
      BatteryOptimizationService();

  final NetworkService _networkService = NetworkService();

  final BackgroundLocationService _backgroundLocationService =
      BackgroundLocationService();

  static const int _totalChecks = 8;

  Future<SafetyCheckResult> runCheck({
    int? sosEventId,
    String? trackingToken,
    bool includeBackgroundServiceCheck = false,
  }) async {
    final issues = <SafetyIssue>[];
    int readyCount = 0;

    final locationPermission = await Geolocator.checkPermission();

    final locationPermissionReady =
        locationPermission == LocationPermission.always ||
        locationPermission == LocationPermission.whileInUse;

    if (locationPermissionReady) {
      readyCount++;
    } else {
      issues.add(
        const SafetyIssue(
          key: 'location_permission',
          title: 'Location permission missing',
          message:
              'Live tracking needs location permission. SOS may not share your location properly.',
          severity: SafetyIssueSeverity.critical,
        ),
      );
    }

    final gpsEnabled = await Geolocator.isLocationServiceEnabled();

    if (gpsEnabled) {
      readyCount++;
    } else {
      issues.add(
        const SafetyIssue(
          key: 'gps_disabled',
          title: 'Phone location is off',
          message:
              'Turn on Location/GPS. Live tracking cannot update accurately without it.',
          severity: SafetyIssueSeverity.critical,
        ),
      );
    }

    final smsPermission = await Permission.sms.status;

    if (smsPermission.isGranted) {
      readyCount++;
    } else {
      issues.add(
        const SafetyIssue(
          key: 'sms_permission',
          title: 'SMS permission missing',
          message: 'Offline SMS fallback may fail if internet is unavailable.',
          severity: SafetyIssueSeverity.warning,
        ),
      );
    }

    final notificationPermission = await Permission.notification.status;

    if (notificationPermission.isGranted) {
      readyCount++;
    } else {
      issues.add(
        const SafetyIssue(
          key: 'notification_permission',
          title: 'Notification permission missing',
          message:
              'The foreground tracking notification or important warnings may not appear properly.',
          severity: SafetyIssueSeverity.warning,
        ),
      );
    }

    final contacts = await _contactLocalService.getContacts();

    if (contacts.isNotEmpty) {
      readyCount++;
    } else {
      issues.add(
        const SafetyIssue(
          key: 'trusted_contacts',
          title: 'No trusted contacts',
          message:
              'Emergency SMS cannot be sent because no trusted contact is saved.',
          severity: SafetyIssueSeverity.critical,
        ),
      );
    }

    final profile = await _profileLocalService.getProfile();

    if (_isProfileCompleted(profile)) {
      readyCount++;
    } else {
      issues.add(
        const SafetyIssue(
          key: 'emergency_profile',
          title: 'Emergency profile incomplete',
          message:
              'Add name, phone, relative name and relative phone so helpers get proper details.',
          severity: SafetyIssueSeverity.warning,
        ),
      );
    }

    String networkStatus = 'Unknown';

    try {
      networkStatus = await _networkService.getNetworkStatus();
    } catch (_) {
      networkStatus = 'Could not check';
    }

    if (networkStatus != 'No internet' && networkStatus != 'Could not check') {
      readyCount++;
    } else {
      issues.add(
        const SafetyIssue(
          key: 'internet',
          title: 'No internet detected',
          message:
              'Live tracking may not update online. SMS fallback should still be used.',
          severity: SafetyIssueSeverity.warning,
        ),
      );
    }

    bool batteryOptimizationReady = false;

    try {
      batteryOptimizationReady = await _batteryOptimizationService
          .isIgnoringBatteryOptimizations();
    } catch (_) {
      batteryOptimizationReady = false;
    }

    if (batteryOptimizationReady) {
      readyCount++;
    } else {
      issues.add(
        const SafetyIssue(
          key: 'battery_optimization',
          title: 'Battery restriction enabled',
          message:
              'Background tracking may stop. Set the app to unrestricted battery usage.',
          severity: SafetyIssueSeverity.warning,
        ),
      );
    }

    if (includeBackgroundServiceCheck &&
        sosEventId != null &&
        trackingToken != null &&
        trackingToken.trim().isNotEmpty) {
      final serviceState = await _backgroundLocationService
          .getForegroundLocationServiceState();

      final isServiceFreshForCurrentSos = serviceState.isFreshFor(
        sosEventId: sosEventId,
        trackingToken: trackingToken,
      );

      if (!isServiceFreshForCurrentSos) {
        issues.add(
          const SafetyIssue(
            key: 'background_service_heartbeat',
            title: 'Background tracking service is not fresh',
            message:
                'The app will try to recover it, but live tracking may be delayed.',
            severity: SafetyIssueSeverity.critical,
          ),
        );
      }
    }

    return SafetyCheckResult(
      issues: issues,
      readyCount: readyCount,
      totalChecks: _totalChecks,
      networkStatus: networkStatus,
    );
  }

  bool _isProfileCompleted(UserProfile? profile) {
    if (profile == null) {
      return false;
    }

    return profile.name.trim().isNotEmpty &&
        profile.phone.trim().isNotEmpty &&
        profile.relativeName.trim().isNotEmpty &&
        profile.relativePhone.trim().isNotEmpty;
  }
}
