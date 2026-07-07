import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
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

  int _nextUpdateSeconds = 30;
  bool _isUpdatingLocation = false;
  bool _isCancelling = false;
  bool _smsSendStarted = false;


  static const Color _dangerRed = Color(0xFFE53935);
  static const Color _dangerDark = Color(0xFFB91C1C);
  static const Color _darkText = Color(0xFF111827);
  static const Color _mutedText = Color(0xFF6B7280);
  static const Color _softBg = Color(0xFFF8FAFC);
  static const Color _borderColor = Color(0xFFE5E7EB);
  static const Color _successGreen = Color(0xFF16A34A);

  @override
  void initState() {
    super.initState();

    unawaited(syncPendingOfflineSosEvents());

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
    super.dispose();
  }

  Future<void> resumeExistingSos(ActiveSosSession session) async {
    setState(() {
      _sosEventId = session.sosEventId;
      _trackingToken = session.trackingToken;
      _trackingUrl = session.trackingUrl;
      _sosDecision = 'Existing SOS is active';
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

    startLocationCountdown();
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

      final sosEvent = await _sosApiService.startSos(
        latitude: position.latitude,
        longitude: position.longitude,
        networkMode: networkStatus,
      );

      await _activeSosLocalService.save(
        sosEventId: sosEvent.id,
        trackingToken: sosEvent.trackingToken,
        trackingUrl: sosEvent.trackingUrl,
        batteryPercentage: batteryPercentage,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _sosEventId = sosEvent.id;
        _trackingToken = sosEvent.trackingToken;
        _trackingUrl = sosEvent.trackingUrl;
        _internetAlert = 'Internet alert created';
        _liveTracking = 'Starting background live tracking...';
      });

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

      if (backgroundStarted) {
        startLocationCountdown();
      } else {
        startLiveLocationUpdates();

        unawaited(
          sendLiveLocationUpdate(),
        );
      }

      unawaited(
        sendAutomaticSmsFallback(
          latitude: position.latitude,
          longitude: position.longitude,
          trackingUrl: sosEvent.trackingUrl,
          batteryPercentage: batteryPercentage,
        ),
      );
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
    try {
      final networkStatus = await _networkService.getNetworkStatus();

      if (networkStatus == 'No internet') {
        return;
      }

      final pendingEvents = await _offlineSosLocalService.getOfflineSosEvents();

      if (pendingEvents.isEmpty) {
        return;
      }

      for (final event in pendingEvents) {
        try {
          await _sosApiService.syncOfflineSos(event: event);
          await _offlineSosLocalService.removeOfflineSos(event.localId);
        } catch (error) {
          debugPrint('Offline SOS sync failed for ${event.localId}: $error');
        }
      }
    } catch (error) {
      debugPrint('Offline SOS sync check failed: $error');
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

  void startLocationCountdown() {
    _countdownTimer?.cancel();
    _nextUpdateSeconds = 30;

    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
          (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        setState(() {
          if (_nextUpdateSeconds > 1) {
            _nextUpdateSeconds--;
          } else {
            _nextUpdateSeconds = 30;
          }
        });
      },
    );
  }

  void startLiveLocationUpdates() {
    _locationTimer?.cancel();
    startLocationCountdown();

    debugPrint('Flutter fallback location timer started');

    _locationTimer = Timer.periodic(
      const Duration(seconds: 30),
          (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

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

    if (mounted) {
      setState(() {
        _isUpdatingLocation = true;
        _liveTracking = 'Updating location...';
      });
    }

    try {
      final position = await _locationService.getCurrentLocation();
      final batteryPercentage = await refreshBatteryPercentage();

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

      debugPrint('Live location update success for SOS $_sosEventId');

      if (!mounted) {
        return;
      }

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _gpsStatus = 'Location updated';
        _liveTracking = 'Live location updated';
        _nextUpdateSeconds = 30;
      });
    } catch (error) {
      debugPrint('Live location update failed: $error');

      if (!mounted) {
        return;
      }

      setState(() {
        _liveTracking = 'Failed to update location';
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
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Cancel SOS?',
            style: TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
          content: const Text(
            'Are you sure you want to cancel this active SOS alert?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Keep Active'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              icon: const Icon(Icons.close_rounded),
              label: const Text('Cancel SOS'),
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

  Color getStatusColor(String value) {
    final cleanValue = value.toLowerCase();

    if (cleanValue.contains('failed') ||
        cleanValue.contains('denied') ||
        cleanValue.contains('not sent') ||
        cleanValue.contains('not available') ||
        cleanValue.contains('unavailable')) {
      return _dangerRed;
    }

    if (cleanValue.contains('found') ||
        cleanValue.contains('created') ||
        cleanValue.contains('sent') ||
        cleanValue.contains('started') ||
        cleanValue.contains('active') ||
        cleanValue.contains('updated')) {
      return _successGreen;
    }

    return _mutedText;
  }

  IconData getStatusIcon(String value) {
    final cleanValue = value.toLowerCase();

    if (cleanValue.contains('failed') ||
        cleanValue.contains('denied') ||
        cleanValue.contains('not sent') ||
        cleanValue.contains('not available') ||
        cleanValue.contains('unavailable')) {
      return Icons.error_outline_rounded;
    }

    if (cleanValue.contains('found') ||
        cleanValue.contains('created') ||
        cleanValue.contains('sent') ||
        cleanValue.contains('started') ||
        cleanValue.contains('active') ||
        cleanValue.contains('updated')) {
      return Icons.check_circle_outline_rounded;
    }

    return Icons.info_outline_rounded;
  }

  Widget buildInfoTile({
    required String title,
    required String value,
    required IconData icon,
  }) {
    final statusColor = getStatusColor(value);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
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
                    color: _mutedText,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: const TextStyle(
                    color: _darkText,
                    fontSize: 14.5,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
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
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.blue,
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
                          color: _mutedText,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        link,
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 14,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.open_in_new_rounded,
                  color: _mutedText,
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
            color: _dangerRed.withOpacity(0.28),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.white,
              size: 52,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Emergency SOS Active',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            _sosDecision,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.88),
              fontSize: 14.5,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    final currentLocationUrl = getCurrentLocationUrl();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Location',
          style: TextStyle(
            color: _darkText,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        buildInfoTile(
          title: 'GPS Location',
          value: _gpsStatus,
          icon: Icons.my_location_rounded,
        ),
        buildInfoTile(
          title: 'Latitude',
          value: _latitude == null ? '-' : _latitude!.toStringAsFixed(7),
          icon: Icons.pin_drop_outlined,
        ),
        buildInfoTile(
          title: 'Longitude',
          value: _longitude == null ? '-' : _longitude!.toStringAsFixed(7),
          icon: Icons.location_on_outlined,
        ),
        if (currentLocationUrl != null)
          buildClickableLinkTile(
            title: 'Current Location Link',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Alert Status',
          style: TextStyle(
            color: _darkText,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        buildInfoTile(
          title: 'Network',
          value: _networkStatus,
          icon: Icons.wifi_tethering_rounded,
        ),
        buildInfoTile(
          title: 'SOS Decision',
          value: _sosDecision,
          icon: Icons.emergency_share_rounded,
        ),
        buildInfoTile(
          title: 'Internet Alert',
          value: _internetAlert,
          icon: Icons.cloud_done_outlined,
        ),
        buildInfoTile(
          title: 'SMS Alert',
          value: _smsFallback,
          icon: Icons.sms_outlined,
        ),
        buildInfoTile(
          title: 'Battery',
          value: _batteryPercentage == null
              ? 'Not available'
              : '${_batteryPercentage!}%',
          icon: Icons.battery_5_bar_rounded,
        ),
        if (_smsRecipients != '-')
          buildInfoTile(
            title: 'SMS Recipients',
            value: _smsRecipients,
            icon: Icons.groups_outlined,
          ),
        if (_smsMessage != '-')
          buildInfoTile(
            title: 'SMS Message',
            value: _smsMessage,
            icon: Icons.message_outlined,
          ),
      ],
    );
  }

  Widget _buildLiveTrackingCard() {
    final hasTrackingLink = _trackingUrl != '-';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Live Tracking',
          style: TextStyle(
            color: _darkText,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        buildInfoTile(
          title: 'Live Tracking',
          value: _liveTracking,
          icon: Icons.location_searching_rounded,
        ),
        if (_sosEventId != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _successGreen.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _successGreen.withOpacity(0.15),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isUpdatingLocation
                      ? Icons.sync_rounded
                      : Icons.timer_outlined,
                  color: _successGreen,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isUpdatingLocation
                        ? 'Updating location...'
                        : 'Next update in ${_nextUpdateSeconds}s',
                    style: const TextStyle(
                      color: _darkText,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (hasTrackingLink)
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: openTrackingPage,
              icon: const Icon(Icons.open_in_browser_rounded),
              label: const Text('Open Tracking Page'),
              style: FilledButton.styleFrom(
                backgroundColor: _dangerRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        if (hasTrackingLink) const SizedBox(height: 12),
        if (hasTrackingLink)
          SizedBox(
            height: 54,
            child: OutlinedButton.icon(
              onPressed: copyTrackingLink,
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copy Tracking Link'),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCancelButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
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
            : const Icon(Icons.close_rounded),
        label: Text(
          _isCancelling ? 'Cancelling...' : 'Cancel SOS',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: _darkText,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _darkText.withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _softBg,
      appBar: AppBar(
        title: const Text('Active SOS'),
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
                    const SizedBox(height: 24),
                    _buildLocationCard(),
                    const SizedBox(height: 22),
                    _buildAlertStatusCard(),
                    const SizedBox(height: 22),
                    _buildLiveTrackingCard(),
                    const SizedBox(height: 24),
                    _buildCancelButton(),
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