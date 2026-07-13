import 'dart:async';


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/direct_sms_service.dart';
import '../services/emergency_contact_local_service.dart';
import '../services/location_service.dart';
import '../services/network_service.dart';
import '../services/sos_api_service.dart';
import '../services/user_profile_local_service.dart';
import '../services/background_location_service.dart';
import '../services/active_sos_local_service.dart';
import '../services/battery_service.dart';
import '../services/offline_sos_local_service.dart';
import '../services/custom_sos_message_local_service.dart';
import '../services/battery_optimization_service.dart';
import '../services/failed_sos_location_local_service.dart';
import '../services/active_sos_monitor_service.dart';

class ActiveSosScreen extends StatefulWidget {
  const ActiveSosScreen({
    super.key,
    this.existingSession,
  });

  final ActiveSosSession? existingSession;

  @override
  State<ActiveSosScreen> createState() => _ActiveSosScreenState();
}

class _ActiveSosScreenState extends State<ActiveSosScreen> {

  static const int _locationUpdateIntervalSeconds = 30;

  final LocationService _locationService = LocationService();
  final NetworkService _networkService = NetworkService();
  final SosApiService _sosApiService = SosApiService();
  final EmergencyContactLocalService _localContactService = EmergencyContactLocalService();
  final UserProfileLocalService _profileLocalService = UserProfileLocalService();
  final DirectSmsService _directSmsService = DirectSmsService();
  final BackgroundLocationService _backgroundLocationService = BackgroundLocationService();
  final ActiveSosLocalService _activeSosLocalService = ActiveSosLocalService();
  final BatteryService _batteryService = BatteryService();
  final OfflineSosLocalService _offlineSosLocalService = OfflineSosLocalService();
  final CustomSosMessageLocalService _customSosMessageLocalService = CustomSosMessageLocalService();
  final BatteryOptimizationService _batteryOptimizationService = BatteryOptimizationService();
  final FailedSosLocationLocalService _failedSosLocationLocalService = FailedSosLocationLocalService();

  String _gpsStatus = 'Finding location...';
  String _networkStatus = 'Checking network...';
  String _sosDecision = 'Starting SOS...';
  String _internetAlert = 'Waiting...';
  String _smsFallback = 'Waiting...';
  String _smsMessage = '-';
  String _smsRecipients = '-';
  String _liveTracking = 'Waiting...';
  String _trackingUrl = '-';
  String? _trackingToken;
  int? _batteryPercentage;

  double? _latitude;
  double? _longitude;

  int? _sosEventId;

  Timer? _locationTimer;
  Timer? _countdownTimer;
  Timer? _statusCheckTimer;
  Timer? _offlineInternetCheckTimer;

  int _nextUpdateSeconds = _locationUpdateIntervalSeconds;
  DateTime? _nextLocationUpdateAt;

  bool _isUpdatingLocation = false;
  bool _isCancelling = false;
  bool _smsSendStarted = false;
  bool _isStoppingBecauseInactive = false;
  bool _isConvertingOfflineSosToLive = false;
  bool _isSyncingFailedLocationUpdates = false;

  String _batteryOptimizationStatus = 'Checking battery optimization...';
  bool _isBatteryOptimizationAllowed = true;
  bool _batteryOptimizationDialogShown = false;


  static const Color _dangerRed = Color(0xFFEF4444);
  static const Color _dangerDark = Color(0xFFB91C1C);
  static const Color _successGreen = Color(0xFF22C55E);
  static const Color _warningAmber = Color(0xFFF59E0B);
  static const Color _mutedText = Color(0xFF94A3B8);

  @override
  void initState() {
    super.initState();

    unawaited(syncPendingOfflineSosEvents());

    unawaited(
      checkBatteryOptimizationStatus(
        showWarningIfRestricted: true,
      ),
    );

    final existingSession = widget.existingSession;

    if (existingSession != null) {
      resumeExistingSos(existingSession);
    } else {
      startSosFlow();
    }
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _countdownTimer?.cancel();
    _statusCheckTimer?.cancel();
    _offlineInternetCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> resumeExistingSos(ActiveSosSession session) async {
    setState(() {
      _sosEventId = session.sosEventId;
      _trackingToken = session.trackingToken;
      _trackingUrl = session.trackingUrl;
      _sosDecision = 'SOS active with internet';
      _internetAlert = 'Already sent';
      _smsFallback = 'Already handled';
      _liveTracking = 'Background live tracking active';
    });

    final position = await _locationService.getCurrentLocation();
    final networkStatus = await _networkService.getNetworkStatus();

    if (!mounted) {
      return;
    }

    setState(() {
      _networkStatus = networkStatus;

      if (position != null) {
        _gpsStatus = 'Location found';
        _latitude = position.latitude;
        _longitude = position.longitude;
      }
    });

    setState(() {
      _batteryPercentage = session.batteryPercentage;
    });

    await refreshCountdownFromSavedActiveSos();

    startLiveLocationUpdates();
    startSosStatusCheckTimer();
    ActiveSosMonitorService.instance.start();
  }

  int getRemainingSecondsUntilNextLocationUpdate(DateTime? nextLocationUpdateAt) {
    if (nextLocationUpdateAt == null) {
      return _locationUpdateIntervalSeconds;
    }

    final remainingSeconds = nextLocationUpdateAt
        .difference(DateTime.now())
        .inSeconds;

    if (remainingSeconds <= 0) {
      return 0;
    }

    if (remainingSeconds > _locationUpdateIntervalSeconds) {
      return _locationUpdateIntervalSeconds;
    }

    return remainingSeconds;
  }

  Future<void> refreshCountdownFromSavedActiveSos() async {
    final activeSosSession = await _activeSosLocalService.getActiveSos();

    if (!mounted || activeSosSession == null) {
      return;
    }

    setState(() {
      _nextLocationUpdateAt = activeSosSession.nextLocationUpdateAt;
      _nextUpdateSeconds = getRemainingSecondsUntilNextLocationUpdate(
        _nextLocationUpdateAt,
      );
    });
  }

  Future<void> saveNextLocationUpdateTime() async {
    final nextUpdateAt = DateTime.now().add(
      const Duration(seconds: _locationUpdateIntervalSeconds),
    );

    _nextLocationUpdateAt = nextUpdateAt;

    await _activeSosLocalService.saveNextLocationUpdateTime(
      nextLocationUpdateAt: nextUpdateAt,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _nextUpdateSeconds = getRemainingSecondsUntilNextLocationUpdate(
        _nextLocationUpdateAt,
      );
    });
  }

  Future<void> startSosFlow() async {
    final position = await _locationService.getCurrentLocation();
    final batteryPercentage = await refreshBatteryPercentage();

    if (!mounted) {
      return;
    }

    if (position == null) {
      setState(() {
        _gpsStatus = 'Location permission denied or GPS unavailable';
        _sosDecision = 'SOS could not start';
        _internetAlert = 'Not sent';
        _smsFallback = 'Not sent';
        _liveTracking = 'Not started';
      });
      return;
    }

    setState(() {
      _gpsStatus = 'Location found';
      _latitude = position.latitude;
      _longitude = position.longitude;
    });

    final networkStatus = await _networkService.getNetworkStatus();

    if (!mounted) {
      return;
    }

    setState(() {
      _networkStatus = networkStatus;
    });

    if (networkStatus == 'No internet') {
      await handleNoInternetSos(
        position,
        batteryPercentage,
      );
      return;
    }

    await handleInternetSos(
      position,
      networkStatus,
      batteryPercentage,
    );
  }

  Future<void> handleNoInternetSos(Position position, int? batteryPercentage) async {
    setState(() {
      _sosDecision = 'SOS active in offline mode';
      _internetAlert = 'Not sent - no internet';
      _liveTracking = 'Not available without internet';
      _trackingUrl = '-';
    });

    final sentCount = await sendAutomaticSmsFallback(
      latitude: position.latitude,
      longitude: position.longitude,
      batteryPercentage: batteryPercentage,
    );

    await saveOfflineSosForLaterSync(
      position: position,
      batteryPercentage: batteryPercentage,
      smsSentCount: sentCount,
      smsMessage: _smsMessage == '-' ? null : _smsMessage,
    );

    startOfflineInternetCheckTimer();
  }

  void startOfflineInternetCheckTimer() {
    _offlineInternetCheckTimer?.cancel();

    _offlineInternetCheckTimer = Timer.periodic(
      const Duration(seconds: 30),
          (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        unawaited(syncPendingOfflineSosEvents());
      },
    );
  }

  Future<void> handleInternetSos(
      Position position,
      String networkStatus,
      int? batteryPercentage,
      ) async {
    try {
      setState(() {
        _sosDecision = 'SOS active with internet';
        _internetAlert = 'Creating internet alert...';
        _liveTracking = 'Creating tracking link...';
      });

      var sosEvent = await _sosApiService.startSos(
        latitude: position.latitude,
        longitude: position.longitude,
        networkMode: networkStatus,
      );

      if (sosEvent.wasExistingActiveSos) {
        if (!mounted) {
          return;
        }

        setState(() {
          _sosDecision = 'Previous SOS is already active';
          _internetAlert = 'Existing active SOS found';
          _liveTracking = 'Waiting for your choice...';
          _smsFallback = 'Already handled for previous SOS';
        });

        final shouldCancelAndStartNew = await showExistingActiveSosChoiceDialog(existingSosId: sosEvent.id,);

        if (!mounted) {
          return;
        }

        if (shouldCancelAndStartNew == true) {
          setState(() {
            _sosDecision = 'Cancelling previous SOS...';
            _internetAlert = 'Cancelling existing alert';
            _liveTracking = 'Stopping previous tracking...';
            _smsFallback = 'Waiting...';
          });

          await _sosApiService.cancelSos(
            sosEventId: sosEvent.id,
          );

          await _backgroundLocationService.stop();
          await _activeSosLocalService.clear();

          _smsSendStarted = false;

          if (!mounted) {
            return;
          }

          setState(() {
            _sosDecision = 'Starting new SOS...';
            _internetAlert = 'Creating new internet alert...';
            _liveTracking = 'Creating new tracking link...';
          });

          sosEvent = await _sosApiService.startSos(
            latitude: position.latitude,
            longitude: position.longitude,
            networkMode: networkStatus,
          );
        } else {
          showInfo('Continuing previous active SOS');
        }
      }

      await _activeSosLocalService.save(
        sosEventId: sosEvent.id,
        trackingToken: sosEvent.trackingToken,
        trackingUrl: sosEvent.trackingUrl,
        batteryPercentage: batteryPercentage,
        nextLocationUpdateAt: DateTime.now().add(
          const Duration(seconds: _locationUpdateIntervalSeconds),
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _sosEventId = sosEvent.id;
        _trackingToken = sosEvent.trackingToken;
        _trackingUrl = sosEvent.trackingUrl;

        _sosDecision = sosEvent.wasExistingActiveSos
            ? 'Previous SOS is still active'
            : 'SOS active with internet';

        _internetAlert = sosEvent.wasExistingActiveSos
            ? 'Existing internet alert active'
            : 'Internet alert created';

        _liveTracking = 'Starting background live tracking...';

        _smsFallback = sosEvent.wasExistingActiveSos
            ? 'Already handled for previous SOS'
            : _smsFallback;
      });

      await _backgroundLocationService.stop();

      final backgroundStarted = await _backgroundLocationService.start(
        sosEventId: sosEvent.id,
        trackingToken: sosEvent.trackingToken,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _liveTracking = backgroundStarted
            ? 'Background live tracking started'
            : 'Background failed, foreground tracking active';
      });

      startLiveLocationUpdates();
      startSosStatusCheckTimer();
      ActiveSosMonitorService.instance.start();

      unawaited(
        sendLiveLocationUpdate(),
      );

      if (!sosEvent.wasExistingActiveSos) {
        unawaited(
          sendAutomaticSmsFallback(
            latitude: position.latitude,
            longitude: position.longitude,
            trackingUrl: sosEvent.trackingUrl,
            batteryPercentage: batteryPercentage,
          ),
        );
      }
    } catch (error) {
      debugPrint('Internet SOS failed: $error');

      if (!mounted) {
        return;
      }

      setState(() {
        _sosDecision = 'Internet failed, using SMS fallback';
        _internetAlert = 'Failed';
        _liveTracking = 'Not available';
      });

      await sendAutomaticSmsFallback(
        latitude: position.latitude,
        longitude: position.longitude,
        batteryPercentage: batteryPercentage,
      );
    }
  }

  Future<void> syncPendingOfflineSosEvents() async {
    if (_isConvertingOfflineSosToLive) {
      return;
    }

    try {
      final networkStatus = await _networkService.getNetworkStatus();

      if (networkStatus == 'No internet') {
        return;
      }

      final pendingEvents = await _offlineSosLocalService.getOfflineSosEvents();

      if (pendingEvents.isEmpty) {
        _offlineInternetCheckTimer?.cancel();
        return;
      }

      _isConvertingOfflineSosToLive = true;

      final event = pendingEvents.first;

      final latestPosition = await _locationService.getCurrentLocation();
      final latestBatteryPercentage = await refreshBatteryPercentage();

      final latitude = latestPosition?.latitude ?? event.latitude;
      final longitude = latestPosition?.longitude ?? event.longitude;
      final accuracy = latestPosition?.accuracy;
      final batteryPercentage =
          latestBatteryPercentage ?? event.batteryPercentage;

      final sosEvent = await _sosApiService.startSos(
        latitude: latitude,
        longitude: longitude,
        networkMode: networkStatus,
      );

      await _activeSosLocalService.save(
        sosEventId: sosEvent.id,
        trackingToken: sosEvent.trackingToken,
        trackingUrl: sosEvent.trackingUrl,
        batteryPercentage: batteryPercentage,
        nextLocationUpdateAt: DateTime.now().add(
          const Duration(seconds: _locationUpdateIntervalSeconds),
        ),
      );

      await _offlineSosLocalService.removeOfflineSos(event.localId);

      if (!mounted) {
        return;
      }

      setState(() {
        _sosEventId = sosEvent.id;
        _trackingToken = sosEvent.trackingToken;
        _trackingUrl = sosEvent.trackingUrl;
        _latitude = latitude;
        _longitude = longitude;
        _gpsStatus = 'Location updated';
        _networkStatus = networkStatus;
        _sosDecision = 'Offline SOS converted to live tracking';
        _internetAlert = 'Live tracking link created';
        _liveTracking = 'Starting live tracking...';
        _smsFallback = 'Sending live tracking link to contacts...';
      });

      await _backgroundLocationService.stop();

      final backgroundStarted = await _backgroundLocationService.start(
        sosEventId: sosEvent.id,
        trackingToken: sosEvent.trackingToken,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _liveTracking = backgroundStarted
            ? 'Background live tracking started'
            : 'Background failed, foreground tracking active';
      });

      startLiveLocationUpdates();
      startSosStatusCheckTimer();
      ActiveSosMonitorService.instance.start();

      unawaited(
        sendLiveLocationUpdate(),
      );

      await sendLiveTrackingSmsToContacts(
        latitude: latitude,
        longitude: longitude,
        trackingUrl: sosEvent.trackingUrl,
        batteryPercentage: batteryPercentage,
        isOfflineLiveTrackingRecovery: true,
      );

      _offlineInternetCheckTimer?.cancel();

      if (!mounted) {
        return;
      }

      setState(() {
        _smsFallback = 'Live tracking link sent to contacts';
      });

      debugPrint('Offline SOS converted to live SOS ${sosEvent.id}');
    } catch (error) {
      debugPrint('Offline SOS live conversion failed: $error');
    } finally {
      _isConvertingOfflineSosToLive = false;
    }
  }

  Future<int> sendLiveTrackingSmsToContacts({
    required double latitude,
    required double longitude,
    required String trackingUrl,
    int? batteryPercentage,
    bool isOfflineLiveTrackingRecovery = false,
  }) async {
    final profile = await _profileLocalService.getProfile();

    if (!mounted) {
      return 0;
    }

    final customMessage = await _customSosMessageLocalService.getMessage();

    final smsMessage = _directSmsService.createEmergencyMessage(
      latitude: latitude,
      longitude: longitude,
      profile: profile,
      trackingUrl: trackingUrl,
      batteryPercentage: batteryPercentage ?? _batteryPercentage,
      customMessage: customMessage,
      isOfflineLiveTrackingRecovery: isOfflineLiveTrackingRecovery,
    );

    setState(() {
      _smsMessage = smsMessage;
    });

    final contacts = await _localContactService.getContacts();

    if (!mounted) {
      return 0;
    }

    if (contacts.isEmpty) {
      setState(() {
        _smsFallback = 'No trusted contacts saved locally';
      });
      return 0;
    }

    final sentCount = await _directSmsService.sendEmergencySmsToContacts(
      contacts: contacts,
      latitude: latitude,
      longitude: longitude,
      profile: profile,
      trackingUrl: trackingUrl,
      batteryPercentage: batteryPercentage ?? _batteryPercentage,
      customMessage: customMessage,
      isOfflineLiveTrackingRecovery: isOfflineLiveTrackingRecovery,
    );

    if (!mounted) {
      return sentCount;
    }

    setState(() {
      _smsFallback = sentCount > 0
          ? 'Live tracking link sent to $sentCount of ${contacts.length} contacts'
          : 'Live tracking SMS not sent. Check permission, SIM, or SMS balance';
    });

    return sentCount;
  }

  bool isRetryableLocationUpdateError(Object error) {
    final errorText = error.toString();

    if (errorText.contains('401') ||
        errorText.contains('403') ||
        errorText.contains('404') ||
        errorText.contains('409') ||
        errorText.contains('410') ||
        errorText.contains('422')) {
      return false;
    }

    return true;
  }

  Future<void> saveFailedLocationUpdateForRetry({
    required Position position,
    required int? batteryPercentage,
  }) async {
    if (_sosEventId == null || _trackingToken == null) {
      return;
    }

    await _failedSosLocationLocalService.save(
      PendingSosLocationUpdate(
        localId: 'failed_location_${DateTime.now().millisecondsSinceEpoch}',
        sosEventId: _sosEventId!,
        trackingToken: _trackingToken!,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        batteryPercentage: batteryPercentage,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> syncFailedLocationUpdates() async {
    if (_isSyncingFailedLocationUpdates) {
      return;
    }

    if (_sosEventId == null || _trackingToken == null) {
      return;
    }

    try {
      final networkStatus = await _networkService.getNetworkStatus();

      if (networkStatus == 'No internet') {
        return;
      }

      _isSyncingFailedLocationUpdates = true;

      final pendingUpdates =
      await _failedSosLocationLocalService.getPendingUpdates();

      final updatesForCurrentSos = pendingUpdates.where((item) {
        return item.sosEventId == _sosEventId &&
            item.trackingToken == _trackingToken;
      }).toList();

      if (updatesForCurrentSos.isEmpty) {
        return;
      }

      for (final pendingUpdate in updatesForCurrentSos) {
        try {
          await _sosApiService.sendLocationUpdate(
            sosEventId: pendingUpdate.sosEventId,
            trackingToken: pendingUpdate.trackingToken,
            latitude: pendingUpdate.latitude,
            longitude: pendingUpdate.longitude,
            accuracy: pendingUpdate.accuracy,
            batteryPercentage: pendingUpdate.batteryPercentage,
          );

          await _failedSosLocationLocalService.remove(pendingUpdate.localId);

          debugPrint(
            'Retried failed location update ${pendingUpdate.localId}',
          );
        } catch (error) {
          debugPrint(
            'Failed location retry stopped at ${pendingUpdate.localId}: $error',
          );

          if (!isRetryableLocationUpdateError(error)) {
            await _failedSosLocationLocalService.remove(pendingUpdate.localId);
          }

          break;
        }
      }
    } catch (error) {
      debugPrint('Failed location sync failed: $error');
    } finally {
      _isSyncingFailedLocationUpdates = false;
    }
  }

  Future<void> saveOfflineSosForLaterSync({
    required Position position,
    required int? batteryPercentage,
    required int smsSentCount,
    required String? smsMessage,
  }) async {
    try {
      final offlineEvent = OfflineSosEvent(
        localId: 'offline_${DateTime.now().millisecondsSinceEpoch}',
        latitude: position.latitude,
        longitude: position.longitude,
        batteryPercentage: batteryPercentage,
        networkMode: 'offline_sms',
        smsSentCount: smsSentCount,
        smsMessage: smsMessage,
        createdAt: DateTime.now(),
      );

      await _offlineSosLocalService.saveOfflineSos(offlineEvent);

      if (!mounted) {
        return;
      }

      setState(() {
        _sosDecision = 'Offline SOS saved for sync';
      });
    } catch (error) {
      debugPrint('Failed to save offline SOS: $error');
    }
  }

  Future<int> sendAutomaticSmsFallback({
    required double latitude,
    required double longitude,
    String? trackingUrl,
    int? batteryPercentage,
  }) async {
    if (_smsSendStarted) {
      return 0;
    }

    _smsSendStarted = true;

    final profile = await _profileLocalService.getProfile();

    if (!mounted) {
      return 0;
    }

    final customMessage = await _customSosMessageLocalService.getMessage();

    final smsMessage = _directSmsService.createEmergencyMessage(
      latitude: latitude,
      longitude: longitude,
      profile: profile,
      trackingUrl: trackingUrl,
      batteryPercentage: batteryPercentage ?? _batteryPercentage,
      customMessage: customMessage,
    );

    setState(() {
      _smsMessage = smsMessage;
    });

    final contacts = await _localContactService.getContacts();

    if (!mounted) {
      return 0;
    }

    final recipientsText = contacts.map((contact) {
      return '${contact.name} - ${contact.phone}';
    }).join('\n');

    setState(() {
      _smsRecipients = recipientsText.isEmpty ? '-' : recipientsText;
    });

    if (contacts.isEmpty) {
      setState(() {
        _smsFallback = 'No trusted contacts saved locally';
      });
      return 0;
    }

    setState(() {
      _smsFallback = 'Sending SMS to ${contacts.length} contacts...';
    });

    final sentCount = await _directSmsService.sendEmergencySmsToContacts(
      contacts: contacts,
      latitude: latitude,
      longitude: longitude,
      profile: profile,
      trackingUrl: trackingUrl,
      batteryPercentage: batteryPercentage ?? _batteryPercentage,
      customMessage:customMessage,
    );

    if (!mounted) {
      return 0;
    }

    if (sentCount == contacts.length) {
      setState(() {
        _smsFallback = 'SMS sent to $sentCount contacts';
      });
    } else if (sentCount > 0) {
      setState(() {
        _smsFallback = 'SMS sent to $sentCount of ${contacts.length} contacts';
      });
    } else {
      setState(() {
        _smsFallback = 'SMS not sent. Check permission, SIM, or SMS balance';
      });
    }

    return sentCount;
  }

  void startSosStatusCheckTimer() {
    _statusCheckTimer?.cancel();

    _statusCheckTimer = Timer.periodic(
      const Duration(seconds: 30),
          (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        unawaited(checkIfSosStillActive());
      },
    );
  }

  Future<void> checkIfSosStillActive() async {
    if (_isStoppingBecauseInactive) {
      return;
    }

    if (_trackingToken == null || _sosEventId == null) {
      return;
    }

    try {
      final backendStatus = await _sosApiService.getTrackingStatus(
        trackingToken: _trackingToken!,
      );

      if (backendStatus == 'active') {
        return;
      }

      _isStoppingBecauseInactive = true;

      debugPrint(
        'SOS $_sosEventId is no longer active. Backend status: $backendStatus',
      );

      _locationTimer?.cancel();
      _countdownTimer?.cancel();
      _statusCheckTimer?.cancel();

      ActiveSosMonitorService.instance.stop();

      await _backgroundLocationService.stop();
      await _activeSosLocalService.clear();

      if (!mounted) {
        return;
      }

      setState(() {
        _sosDecision = 'SOS stopped';
        _internetAlert = 'SOS is no longer active';
        _liveTracking = 'Live tracking stopped';
        _smsFallback = 'No further SMS action';
      });

      showInfo('SOS was cancelled or expired. Tracking has stopped.');

      Navigator.pop(context, true);
    } catch (error) {
      debugPrint('SOS status check failed: $error');

      // Do not stop SOS if status check fails.
      // Internet may be slow/offline.
    }
  }

  void startLocationCountdown() {
    _countdownTimer?.cancel();

    unawaited(refreshCountdownFromSavedActiveSos());

    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
          (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        setState(() {
          _nextUpdateSeconds = getRemainingSecondsUntilNextLocationUpdate(
            _nextLocationUpdateAt,
          );
        });
      },
    );
  }

  void startLiveLocationUpdates() {
    _locationTimer?.cancel();

    unawaited(saveNextLocationUpdateTime());

    startLocationCountdown();

    debugPrint('Flutter fallback location timer started');

    _locationTimer = Timer.periodic(
      const Duration(seconds: _locationUpdateIntervalSeconds),
          (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        unawaited(saveNextLocationUpdateTime());
        unawaited(sendLiveLocationUpdate());
      },
    );
  }

  Future<void> sendLiveLocationUpdate() async {
    if (_sosEventId == null || _trackingToken == null) {
      debugPrint('Live update skipped because SOS event ID or token is null');
      return;
    }

    if (_isUpdatingLocation) {
      debugPrint('Live update skipped because previous update is still running');
      return;
    }

    debugPrint(
      'Sending live location update for SOS $_sosEventId at ${DateTime.now()}',
    );

    Position? position;
    int? batteryPercentage;

    if (mounted) {
      setState(() {
        _isUpdatingLocation = true;
        _liveTracking = 'Updating location...';
      });
    }

    try {
      await syncFailedLocationUpdates();

      position = await _locationService.getCurrentLocation();
      batteryPercentage = await refreshBatteryPercentage();

      if (!mounted) {
        return;
      }

      if (position == null) {
        setState(() {
          _liveTracking = 'Unable to get latest location';
        });
        return;
      }

      await _sosApiService.sendLocationUpdate(
        sosEventId: _sosEventId!,
        trackingToken: _trackingToken!,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        batteryPercentage: batteryPercentage,
      );

      final now = DateTime.now();

      final nextUpdateAt = _nextLocationUpdateAt != null &&
          _nextLocationUpdateAt!.isAfter(now)
          ? _nextLocationUpdateAt!
          : now.add(
        const Duration(seconds: _locationUpdateIntervalSeconds),
      );

      _nextLocationUpdateAt = nextUpdateAt;

      await _activeSosLocalService.saveLocationUpdateTiming(
        lastLocationUpdateAt: now,
        nextLocationUpdateAt: nextUpdateAt,
      );

      debugPrint('Live location update success for SOS $_sosEventId');

      if (!mounted) {
        return;
      }

      setState(() {
        _latitude = position!.latitude;
        _longitude = position!.longitude;
        _gpsStatus = 'Location updated';
        _liveTracking = 'Live location updated';
        _nextUpdateSeconds = getRemainingSecondsUntilNextLocationUpdate(
          _nextLocationUpdateAt,
        );
      });

    } catch (error) {
      debugPrint('Live location update failed: $error');

      if (position != null && isRetryableLocationUpdateError(error)) {
        await saveFailedLocationUpdateForRetry(
          position: position,
          batteryPercentage: batteryPercentage,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _liveTracking = position == null
            ? 'Failed to update location'
            : 'Network issue - location saved for retry';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingLocation = false;
        });
      }
    }
  }

  String getSafeTrackingUrl() {
    return _trackingUrl
        .replaceFirst('http://127.0.0.1:8000', 'http://10.0.2.2:8000')
        .replaceFirst('http://localhost:8000', 'http://10.0.2.2:8000');
  }

  String? getCurrentLocationUrl() {
    if (_latitude == null || _longitude == null) {
      return null;
    }

    return 'https://maps.google.com/?q=${_latitude!.toStringAsFixed(7)},${_longitude!.toStringAsFixed(7)}';
  }

  Future<void> openTrackingPage() async {
    if (_trackingUrl == '-') {
      return;
    }

    final uri = Uri.parse(getSafeTrackingUrl());

    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> openCurrentLocationInMaps() async {
    final currentLocationUrl = getCurrentLocationUrl();

    if (currentLocationUrl == null) {
      showInfo('Current location is not ready yet');
      return;
    }

    final uri = Uri.parse(currentLocationUrl);

    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> copyTrackingLink() async {
    if (_trackingUrl == '-') {
      showInfo('Tracking link is not ready yet');
      return;
    }

    await Clipboard.setData(
      ClipboardData(text: getSafeTrackingUrl()),
    );

    if (!mounted) {
      return;
    }

    showInfo('Tracking link copied');
  }

  Future<void> cancelSos() async {
    if (_isCancelling) {
      return;
    }

    final shouldCancel = await showCancelConfirmation();

    if (shouldCancel != true) {
      return;
    }

    setState(() {
      _isCancelling = true;
    });

    try {
      if (_sosEventId != null) {
        await _sosApiService.cancelSos(
          sosEventId: _sosEventId!,
        );
      }

      _locationTimer?.cancel();
      _countdownTimer?.cancel();
      _statusCheckTimer?.cancel();

      ActiveSosMonitorService.instance.stop();

      await _backgroundLocationService.stop();
      await _activeSosLocalService.clear();

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
    } catch (error) {
      debugPrint('Cancel SOS failed: $error');

      if (!mounted) {
        return;
      }

      setState(() {
        _isCancelling = false;
      });

      showError('SOS could not be cancelled. Live tracking is still active.');
    }
  }

  Future<bool?> showCancelConfirmation() {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.72),
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF111827),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
            side: const BorderSide(
              color: Color(0xFF243041),
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
                  Icons.warning_amber_rounded,
                  color: _dangerRed,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Cancel SOS?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'Are you sure you want to cancel this active SOS alert? Your live tracking will stop.',
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
                'Keep Active',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              icon: const Icon(Icons.close_rounded),
              label: const Text(
                'Cancel SOS',
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
  }

  Future<bool?> showExistingActiveSosChoiceDialog({
    required int existingSosId,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Previous SOS is active',
            style: TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            'SOS #$existingSosId is still active.\n\n'
                'Do you want to keep tracking the previous SOS, or cancel it and start a new SOS?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Keep Active SOS'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('Cancel & Start New'),
              style: FilledButton.styleFrom(
                backgroundColor: _dangerRed,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> checkBatteryOptimizationStatus({
    bool showWarningIfRestricted = false,
  }) async {
    try {
      final isAllowed =
      await _batteryOptimizationService.isIgnoringBatteryOptimizations();

      if (!mounted) {
        return;
      }

      setState(() {
        _isBatteryOptimizationAllowed = isAllowed;
        _batteryOptimizationStatus = isAllowed
            ? 'Unrestricted / allowed'
            : 'Restricted - background tracking may stop';
      });

      if (showWarningIfRestricted &&
          !isAllowed &&
          !_batteryOptimizationDialogShown) {
        _batteryOptimizationDialogShown = true;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }

          unawaited(showBatteryOptimizationWarningDialog());
        });
      }
    } catch (error) {
      debugPrint('Battery optimization check failed: $error');

      if (!mounted) {
        return;
      }

      setState(() {
        _batteryOptimizationStatus = 'Could not check battery optimization';
      });
    }
  }

  Future<void> showBatteryOptimizationWarningDialog() async {
    final shouldOpenSettings = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Allow background tracking?',
            style: TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
          content: const Text(
            'Your phone may restrict this app in the background.\n\n'
                'For emergency live tracking, set battery usage to Unrestricted or Allow background activity.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Later'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              icon: const Icon(Icons.battery_alert_rounded),
              label: const Text('Open Settings'),
              style: FilledButton.styleFrom(
                backgroundColor: _dangerRed,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );

    if (shouldOpenSettings == true) {
      await _batteryOptimizationService.openBatteryOptimizationSettings();

      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) {
        return;
      }

      unawaited(
        checkBatteryOptimizationStatus(),
      );
    }
  }

  Future<int?> refreshBatteryPercentage() async {
    final batteryPercentage = await _batteryService.getBatteryPercentage();

    if (!mounted) {
      return batteryPercentage;
    }

    setState(() {
      _batteryPercentage = batteryPercentage;
    });

    return batteryPercentage;
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Color getBatteryColor() {
    if (_batteryPercentage == null) {
      return _mutedText;
    }

    if (_batteryPercentage! <= 15) {
      return _dangerRed;
    }

    if (_batteryPercentage! <= 30) {
      return _warningAmber;
    }

    return _successGreen;
  }


  Color getStatusColor(String value) {
    final cleanValue = value.toLowerCase();

    if (cleanValue.contains('unrestricted') ||
        cleanValue.contains('allowed')) {
      return _successGreen;
    }



    if (cleanValue.contains('failed') ||
        cleanValue.contains('denied') ||
        cleanValue.contains('not sent') ||
        cleanValue.contains('not available') ||
        cleanValue.contains('unavailable') ||
        cleanValue.contains('restricted') ||
        cleanValue.contains('could not')) {
      return _dangerRed;
    }

    if (cleanValue.contains('warning') ||
        cleanValue.contains('waiting') ||
        cleanValue.contains('checking') ||
        cleanValue.contains('updating') ||
        cleanValue.contains('starting')) {
      return _warningAmber;
    }

    if (cleanValue.contains('no internet') ||
        cleanValue.contains('offline')) {
      return _warningAmber;
    }

    if (cleanValue.contains('wifi') ||
        cleanValue.contains('mobile data') ||
        cleanValue.contains('internet') ||
        cleanValue.contains('connected')) {
      return _successGreen;
    }

    if (cleanValue.contains('found') ||
        cleanValue.contains('created') ||
        cleanValue.contains('sent') ||
        cleanValue.contains('started') ||
        cleanValue.contains('active') ||
        cleanValue.contains('updated') ||
        cleanValue.contains('ready')) {
      return _successGreen;
    }

    return _mutedText;
  }

  Color getStatusBackgroundColor(String value) {
    return getStatusColor(value).withOpacity(0.14);
  }

  IconData getStatusIcon(String value) {
    final cleanValue = value.toLowerCase();

    if (cleanValue.contains('unrestricted') ||
        cleanValue.contains('allowed')) {
      return Icons.check_circle_outline_rounded;
    }

    if (cleanValue.contains('failed') ||
        cleanValue.contains('denied') ||
        cleanValue.contains('not sent') ||
        cleanValue.contains('not available') ||
        cleanValue.contains('unavailable') ||
        cleanValue.contains('restricted') ||
        cleanValue.contains('could not')) {
      return Icons.error_outline_rounded;
    }

    if (cleanValue.contains('warning') ||
        cleanValue.contains('waiting') ||
        cleanValue.contains('checking') ||
        cleanValue.contains('updating') ||
        cleanValue.contains('starting')) {
      return Icons.timelapse_rounded;
    }

    if (cleanValue.contains('found') ||
        cleanValue.contains('created') ||
        cleanValue.contains('sent') ||
        cleanValue.contains('started') ||
        cleanValue.contains('active') ||
        cleanValue.contains('updated') ||
        cleanValue.contains('ready')) {
      return Icons.check_circle_outline_rounded;
    }

    return Icons.info_outline_rounded;
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF243041),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 16),
          ...children,
        ],
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
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildInfoTile({
    required String title,
    required String value,
    required IconData icon,
    bool showStatus = true,
    Color? iconColor,
  }) {
    final statusColor = showStatus
        ? getStatusColor(value)
        : iconColor ?? const Color(0xFF3B82F6);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF243041),
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
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: statusColor,
              size: 22,
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
                    color: Color(0xFF94A3B8),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.2,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          if (showStatus) ...[
            const SizedBox(width: 8),
            Icon(
              getStatusIcon(value),
              color: statusColor,
              size: 18,
            ),
          ],
        ],
      ),
    );
  }

  Widget buildClickableLinkTile({
    required String title,
    required String link,
    required VoidCallback onTap,
    IconData icon = Icons.link_rounded,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF243041),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: const Color(0xFF3B82F6),
                    size: 22,
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
                          color: Color(0xFF94A3B8),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        link,
                        style: const TextStyle(
                          color: Color(0xFF60A5FA),
                          fontSize: 14,
                          height: 1.45,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                          decorationColor: Color(0xFF60A5FA),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.open_in_new_rounded,
                  color: Color(0xFF94A3B8),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    final networkLabel = _networkStatus == 'No internet' ? 'Offline mode' : 'Internet ready';
    final trackingSubtitle = _trackingUrl != '-' ? 'Contacts can follow your live location.' : 'Trying to create tracking access.';

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
          color: const Color(0xFF243041),
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
          const Text(
            'Emergency SOS Active',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _sosDecision,
            style: const TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildStatusBadge(
                icon: Icons.location_on_rounded,
                label: _gpsStatus,
                color: getStatusColor(_gpsStatus),
              ),
              _buildStatusBadge(
                icon: _networkStatus == 'No internet'
                    ? Icons.wifi_off_rounded
                    : Icons.wifi_rounded,
                label: networkLabel,
                color: _networkStatus == 'No internet'
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFF22C55E),
              ),
              _buildStatusBadge(
                icon: Icons.battery_5_bar_rounded,
                label: _batteryPercentage == null
                    ? 'Battery unknown'
                    : 'Battery ${_batteryPercentage!}% ',
                color: _batteryPercentage != null && _batteryPercentage! <= 20
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFF3B82F6),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEF4444).withOpacity(0.28),
                    blurRadius: 36,
                    spreadRadius: 8,
                  ),
                ],
                gradient: const RadialGradient(
                  colors: [
                    Color(0xFFF87171),
                    Color(0xFFEF4444),
                    Color(0xFFB91C1C),
                  ],
                  stops: [0.0, 0.65, 1.0],
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.22),
                  width: 3,
                ),
              ),
              child: Container(
                margin: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.35),
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'SOS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 56,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _trackingUrl != '-' ? 'LIVE TRACKING ACTIVE' : 'EMERGENCY MODE ACTIVE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.94),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Next update in $_nextUpdateSeconds sec',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1220),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF243041),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: getStatusBackgroundColor(_liveTracking),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.location_searching_rounded,
                    color: getStatusColor(_liveTracking),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tracking status',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _liveTracking,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.2,
                          height: 1.4,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        trackingSubtitle,
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12.5,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    final currentLocationUrl = getCurrentLocationUrl();

    return _buildSectionCard(
      title: 'Location',
      subtitle: 'Current coordinates and direct map access for the active SOS.',
      children: [
        buildInfoTile(
          title: 'GPS status',
          value: _gpsStatus,
          icon: Icons.my_location_rounded,
        ),
        buildInfoTile(
          title: 'Latitude',
          value: _latitude == null ? '-' : _latitude!.toStringAsFixed(7),
          icon: Icons.pin_drop_outlined,
          showStatus: false,
          iconColor: const Color(0xFF3B82F6),
        ),
        buildInfoTile(
          title: 'Longitude',
          value: _longitude == null ? '-' : _longitude!.toStringAsFixed(7),
          icon: Icons.location_on_outlined,
          showStatus: false,
          iconColor: const Color(0xFF3B82F6),
        ),
        if (currentLocationUrl != null)
          buildClickableLinkTile(
            title: 'Open current location in Google Maps',
            link: currentLocationUrl,
            icon: Icons.map_rounded,
            onTap: () {
              unawaited(openCurrentLocationInMaps());
            },
          ),
      ],
    );
  }

  Widget _buildAlertStatusCard() {
    return _buildSectionCard(
      title: 'Alert status',
      subtitle: 'This section shows how the SOS is being delivered and maintained.',
      children: [
        buildInfoTile(
          title: 'Network',
          value: _networkStatus,
          icon: Icons.wifi_tethering_rounded,
        ),
        buildInfoTile(
          title: 'SOS decision',
          value: _sosDecision,
          icon: Icons.emergency_share_rounded,
        ),
        buildInfoTile(
          title: 'Internet alert',
          value: _internetAlert,
          icon: Icons.cloud_done_outlined,
        ),
        buildInfoTile(
          title: 'SMS alert',
          value: _smsFallback,
          icon: Icons.sms_outlined,
        ),
        buildInfoTile(
          title: 'Battery',
          value: _batteryPercentage == null
              ? 'Not available'
              : '$_batteryPercentage%',
          icon: Icons.battery_5_bar_rounded,
          showStatus: false,
          iconColor: getBatteryColor(),
        ),
        buildInfoTile(
          title: 'Battery optimization',
          value: _batteryOptimizationStatus,
          icon: Icons.battery_alert_rounded,
        ),
        if (!_isBatteryOptimizationAllowed) ...[
          const SizedBox(height: 4),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () {
                unawaited(
                  _batteryOptimizationService.openBatteryOptimizationSettings(),
                );
              },
              icon: const Icon(Icons.settings_rounded),
              label: const Text('Open Battery Settings'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFCA5A5),
                side: const BorderSide(
                  color: Color(0xFFEF4444),
                ),
                backgroundColor: const Color(0xFF0F172A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (_smsRecipients != '-')
          buildInfoTile(
            title: 'SMS recipients',
            value: _smsRecipients,
            icon: Icons.groups_outlined,
            showStatus: false,
            iconColor: const Color(0xFF3B82F6),
          ),
        if (_smsMessage != '-')
          buildInfoTile(
            title: 'SMS message',
            value: _smsMessage,
            icon: Icons.message_outlined,
            showStatus: false,
            iconColor: const Color(0xFF3B82F6),
          ),
      ],
    );
  }

  Widget _buildLiveTrackingCard() {
    final hasTrackingLink = _trackingUrl != '-';

    return _buildSectionCard(
      title: 'Live tracking',
      subtitle: 'Open or share the live tracking page for this emergency.',
      children: [
        buildInfoTile(
          title: 'Tracking',
          value: _liveTracking,
          icon: Icons.location_searching_rounded,
        ),
        if (hasTrackingLink)
          buildClickableLinkTile(
            title: 'Tracking link',
            link: getSafeTrackingUrl(),
            icon: Icons.link_rounded,
            onTap: openTrackingPage,
          ),
        if (hasTrackingLink)
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: openTrackingPage,
                    icon: const Icon(Icons.open_in_browser_rounded),
                    label: const Text('Open'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: OutlinedButton.icon(
                    onPressed: copyTrackingLink,
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Copy link'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(
                        color: Color(0xFF243041),
                      ),
                      backgroundColor: const Color(0xFF0F172A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildCancelButton() {
    return Container(
      width: double.infinity,
      height: 58,
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
        onPressed: _isCancelling ? null : cancelSos,
        icon: _isCancelling
            ? const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        )
            : const Icon(Icons.power_settings_new_rounded),
        label: Text(
          _isCancelling ? 'Stopping Emergency...' : 'Stop Active SOS',
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

  Widget _buildSafetyNote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF243041),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(
            Icons.shield_moon_rounded,
            color: Color(0xFF22C55E),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Keep this screen open if possible. The app will continue trying to update your location and deliver emergency tracking.',
              style: TextStyle(
                color: Color(0xFFCBD5E1),
                fontSize: 13.5,
                height: 1.45,
                fontWeight: FontWeight.w500,
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
      backgroundColor: const Color(0xFF0B1120),
      appBar: AppBar(
        title: const Text(
          'Active SOS',
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
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF243041),
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
                      _buildHeaderCard(),
                      const SizedBox(height: 22),
                      _buildLocationCard(),
                      const SizedBox(height: 18),
                      _buildAlertStatusCard(),
                      const SizedBox(height: 18),
                      _buildLiveTrackingCard(),
                      const SizedBox(height: 18),
                      _buildSafetyNote(),
                      const SizedBox(height: 22),
                      _buildCancelButton(),
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
