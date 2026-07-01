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

class ActiveSosScreen extends StatefulWidget {
  const ActiveSosScreen({super.key, this.existingSession,});

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

  double? _latitude;
  double? _longitude;

  int? _sosEventId;

  Timer? _locationTimer;
  Timer? _countdownTimer;

  int _nextUpdateSeconds = 15;
  bool _isUpdatingLocation = false;
  bool _isCancelling = false;
  bool _smsSendStarted = false;

  @override
  void initState() {
    super.initState();

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

    startLocationCountdown();
  }

  Future<void> startSosFlow() async {
    final position = await _locationService.getCurrentLocation();

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
      await handleNoInternetSos(position);
      return;
    }

    await handleInternetSos(position, networkStatus);
  }

  Future<void> handleNoInternetSos(Position position) async {
    setState(() {
      _sosDecision = 'SOS active in offline mode';
      _internetAlert = 'Not sent - no internet';
      _liveTracking = 'Not available without internet';
      _trackingUrl = '-';
    });

    await sendAutomaticSmsFallback(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  Future<void> handleInternetSos(
      Position position,
      String networkStatus,
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
        // Native Android service sends periodic locations.
        // Flutter only displays the countdown.
        startLocationCountdown();
      } else {
        // Use Flutter timer only when native service failed.
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
      );
    }
  }

  Future<void> sendAutomaticSmsFallback({
    required double latitude,
    required double longitude,
    String? trackingUrl,
  }) async {
    if (_smsSendStarted) {
      return;
    }

    _smsSendStarted = true;

    final profile = await _profileLocalService.getProfile();

    if (!mounted) {
      return;
    }

    final smsMessage = _directSmsService.createEmergencyMessage(
      latitude: latitude,
      longitude: longitude,
      profile: profile,
      trackingUrl: trackingUrl,
    );

    setState(() {
      _smsMessage = smsMessage;
    });

    final contacts = await _localContactService.getContacts();

    if (!mounted) {
      return;
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
      return;
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
    );

    if (!mounted) {
      return;
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
  }

  void startLocationCountdown() {
    _countdownTimer?.cancel();
    _nextUpdateSeconds = 15;

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
            _nextUpdateSeconds = 15;
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
      const Duration(seconds: 15),
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
        batteryPercentage: null,
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
        _nextUpdateSeconds = 15;
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Current location is not ready yet'),
        ),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tracking link is not ready yet'),
        ),
      );
      return;
    }

    await Clipboard.setData(
      ClipboardData(text: getSafeTrackingUrl()),
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tracking link copied'),
      ),
    );
  }

  Future<void> cancelSos() async {
    if (_isCancelling) {
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'SOS could not be cancelled. Live tracking is still active.',
          ),
        ),
      );
    }
  }

  Widget buildInfoTile(String title, String value) {
    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: Text(value),
      ),
    );
  }

  Widget buildClickableLinkTile({
    required String title,
    required String link,
    required VoidCallback onTap,
    IconData icon = Icons.link,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(
          icon,
          color: Colors.blue,
        ),
        title: Text(title),
        subtitle: Text(
          link,
          style: const TextStyle(
            color: Colors.blue,
            decoration: TextDecoration.underline,
          ),
        ),
        trailing: const Icon(Icons.open_in_new),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasTrackingLink = _trackingUrl != '-';
    final currentLocationUrl = getCurrentLocationUrl();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Active SOS'),
        centerTitle: true,
        automaticallyImplyLeading: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.red,
            size: 80,
          ),
          const SizedBox(height: 12),
          const Text(
            'Emergency SOS Active',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 20),

          buildInfoTile('GPS Location', _gpsStatus),
          buildInfoTile(
            'Latitude',
            _latitude == null ? '-' : _latitude!.toStringAsFixed(7),
          ),
          buildInfoTile(
            'Longitude',
            _longitude == null ? '-' : _longitude!.toStringAsFixed(7),
          ),
          buildInfoTile('Network', _networkStatus),
          buildInfoTile('SOS Decision', _sosDecision),
          buildInfoTile('Internet Alert', _internetAlert),
          buildInfoTile('SMS Alert', _smsFallback),

          if (_smsRecipients != '-')
            buildInfoTile('SMS Recipients', _smsRecipients),

          if (_smsMessage != '-')
            buildInfoTile('SMS Message', _smsMessage),

          buildInfoTile('Live Tracking', _liveTracking),

          if (currentLocationUrl != null)
            buildClickableLinkTile(
              title: 'Current Location Link',
              link: currentLocationUrl,
              icon: Icons.map,
              onTap: () {
                unawaited(openCurrentLocationInMaps());
              },
            ),

          if (_sosEventId != null) ...[
            const SizedBox(height: 8),
            Text(
              _isUpdatingLocation
                  ? 'Updating location...'
                  : 'Next update in ${_nextUpdateSeconds}s',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],

          const SizedBox(height: 16),

          if (hasTrackingLink)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: openTrackingPage,
                icon: const Icon(Icons.open_in_browser),
                label: const Text('Open Tracking Page'),
              ),
            ),

          if (hasTrackingLink)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: copyTrackingLink,
                icon: const Icon(Icons.copy),
                label: const Text('Copy Tracking Link'),
              ),
            ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isCancelling ? null : cancelSos,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.close),
              label: Text(_isCancelling ? 'Cancelling...' : 'Cancel SOS'),
            ),
          ),
        ],
      ),
    );
  }
}