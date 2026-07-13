import 'dart:async';

import 'package:flutter/foundation.dart';

import 'active_sos_local_service.dart';
import 'background_location_service.dart';
import 'sos_api_service.dart';

class ActiveSosMonitorService {
  ActiveSosMonitorService._internal();

  static final ActiveSosMonitorService instance =
  ActiveSosMonitorService._internal();

  static const int _monitorIntervalSeconds = 30;

  final ActiveSosLocalService _activeSosLocalService =
  ActiveSosLocalService();

  final BackgroundLocationService _backgroundLocationService =
  BackgroundLocationService();

  final SosApiService _sosApiService = SosApiService();

  Timer? _monitorTimer;

  bool _isChecking = false;

  bool get isRunning => _monitorTimer?.isActive == true;

  void start() {
    if (isRunning) {
      return;
    }

    debugPrint('Active SOS monitor started');

    unawaited(checkNow());

    _monitorTimer = Timer.periodic(
      const Duration(seconds: _monitorIntervalSeconds),
          (_) {
        unawaited(checkNow());
      },
    );
  }

  void stop() {
    debugPrint('Active SOS monitor stopped');

    _monitorTimer?.cancel();
    _monitorTimer = null;
    _isChecking = false;
  }

  Future<void> checkNow() async {
    if (_isChecking) {
      return;
    }

    _isChecking = true;

    try {
      final activeSosSession =
      await _activeSosLocalService.getActiveSos();

      if (activeSosSession == null) {
        debugPrint('Active SOS monitor stopped: no local active SOS');
        stop();
        return;
      }

      await ensureNativeServiceRunning(activeSosSession);

      await verifyBackendSosStatus(activeSosSession);
    } catch (error) {
      debugPrint('Active SOS monitor check failed: $error');

      // Do not clear active SOS here.
      // Internet may be temporarily unavailable.
    } finally {
      _isChecking = false;
    }
  }

  Future<void> ensureNativeServiceRunning(
      ActiveSosSession activeSosSession,
      ) async {
    final serviceState =
    await _backgroundLocationService.getForegroundLocationServiceState();

    final isServiceFreshForCurrentSos = serviceState.isFreshFor(
      sosEventId: activeSosSession.sosEventId,
      trackingToken: activeSosSession.trackingToken,
    );

    if (isServiceFreshForCurrentSos) {
      debugPrint(
        'Active SOS monitor: foreground service heartbeat is fresh. '
            'Age=${serviceState.heartbeatAgeMilliseconds}ms',
      );

      return;
    }

    debugPrint(
      'Active SOS monitor: foreground service heartbeat stale/missing. '
          'Restarting service. '
          'HeartbeatAge=${serviceState.heartbeatAgeMilliseconds}ms '
          'HeartbeatSos=${serviceState.activeSosEventId}',
    );

    final serviceStarted = await _backgroundLocationService.start(
      sosEventId: activeSosSession.sosEventId,
      trackingToken: activeSosSession.trackingToken,
    );

    debugPrint(
      serviceStarted
          ? 'Active SOS monitor restarted foreground service'
          : 'Active SOS monitor could not restart foreground service',
    );
  }

  Future<void> verifyBackendSosStatus(
      ActiveSosSession activeSosSession,
      ) async {
    try {
      final trackingStatus = await _sosApiService.getTrackingStatus(
        trackingToken: activeSosSession.trackingToken,
      );

      if (trackingStatus == 'active') {
        debugPrint('Active SOS monitor: backend SOS is active');
        return;
      }

      debugPrint(
        'Active SOS monitor found inactive SOS. Status: $trackingStatus',
      );

      await _backgroundLocationService.stop();
      await _activeSosLocalService.clear();

      stop();
    } catch (error) {
      debugPrint(
        'Active SOS monitor backend status check failed: $error',
      );

      // Important:
      // Do not stop native service and do not clear local active SOS.
      // Internet may be OFF, but SOS should continue locally.
    }
  }
}