import 'package:flutter/material.dart';

import 'active_sos_screen.dart';
import 'trusted_contacts_screen.dart';
import 'profile_screen.dart';
import 'sos_history_screen.dart';

import '../models/user_profile.dart';

import '../services/active_sos_local_service.dart';
import '../services/background_location_service.dart';
import '../services/sos_api_service.dart';
import '../services/user_profile_local_service.dart';
import '../services/user_profile_api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String sosStatus = 'SOS not started';

  String name = 'Not added';
  String bloodGroup = 'Not added';
  String phone = 'Not added';
  String relativeName = 'Not added';
  String relativePhone = 'Not added';
  String address = 'Not added';

  final UserProfileLocalService _profileLocalService = UserProfileLocalService();

  final UserProfileApiService _profileApiService = UserProfileApiService();

  final ActiveSosLocalService _activeSosLocalService = ActiveSosLocalService();

  final BackgroundLocationService _backgroundLocationService = BackgroundLocationService();

  final SosApiService _sosApiService = SosApiService();

  ActiveSosSession? _activeSosSession;

  bool _isCheckingSos = true;

  bool _isCancellingSos = false;

  @override
  void initState() {
    super.initState();
    loadSavedProfile();
    loadActiveSos();
  }

  Future<void> loadSavedProfile() async {
    final savedProfile = await _profileLocalService.getProfile();

    if (mounted && savedProfile != null) {
      updateProfileOnHome(savedProfile);
    }

    final pendingSync = await _profileLocalService.hasPendingProfileSync();

    if (pendingSync && savedProfile != null) {
      try {
        final syncedProfile = await _profileApiService.updateProfile(
          savedProfile,
        );

        await _profileLocalService.saveProfile(syncedProfile);
        await _profileLocalService.clearProfilePendingSync();

        if (!mounted) {
          return;
        }

        updateProfileOnHome(syncedProfile);

        debugPrint('Pending profile synced with Laravel');

        return;
      } catch (error) {
        debugPrint('Pending profile sync failed: $error');

        // Keep local profile visible. Do not overwrite it with server data.
        return;
      }
    }

    try {
      final serverProfile = await _profileApiService.getProfile();

      await _profileLocalService.saveProfile(serverProfile);

      if (!mounted) {
        return;
      }

      updateProfileOnHome(serverProfile);
    } catch (error) {
      debugPrint('Could not load profile from Laravel: $error');
    }
  }

  void updateProfileOnHome(UserProfile profile) {
    setState(() {
      name = profile.name.trim().isEmpty ? 'Not added' : profile.name.trim();
      bloodGroup = profile.bloodGroup.trim().isEmpty
          ? 'Not added'
          : profile.bloodGroup.trim();
      phone = profile.phone.trim().isEmpty ? 'Not added' : profile.phone.trim();
      relativeName = profile.relativeName.trim().isEmpty
          ? 'Not added'
          : profile.relativeName.trim();
      relativePhone = profile.relativePhone.trim().isEmpty
          ? 'Not added'
          : profile.relativePhone.trim();
      address = profile.address.trim().isEmpty
          ? 'Not added'
          : profile.address.trim();
    });
  }

  Future<void> startSos() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ActiveSosScreen(),
      ),
    );

    await loadActiveSos();
  }

  Future<void> openActiveSos() async {
    final session = _activeSosSession;

    if (session == null) {
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ActiveSosScreen(
          existingSession: session,
        ),
      ),
    );

    await loadActiveSos();
  }

  Future<void> handleSosLongPress() async {
    if (_isCheckingSos || _isCancellingSos) {
      return;
    }

    if (_activeSosSession == null) {
      await startSos();
    } else {
      await cancelSosFromHome();
    }
  }

  Future<void> cancelSosFromHome() async {
    final session = _activeSosSession;

    if (session == null) {
      return;
    }

    setState(() {
      _isCancellingSos = true;
      sosStatus = 'Cancelling SOS...';
    });

    try {
      await _sosApiService.cancelSos(
        sosEventId: session.sosEventId,
      );

      await _backgroundLocationService.stop();
      await _activeSosLocalService.clear();

      if (!mounted) {
        return;
      }

      setState(() {
        _activeSosSession = null;
        _isCancellingSos = false;
        sosStatus = 'SOS cancelled';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SOS cancelled successfully'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isCancellingSos = false;
        sosStatus = 'SOS is still active';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not cancel SOS'),
        ),
      );
    }
  }

  Future<void> loadActiveSos() async {
    ActiveSosSession? session =
    await _activeSosLocalService.getActiveSos();

    if (session != null) {
      try {
        final backendStatus = await _sosApiService.getTrackingStatus(
          trackingToken: session.trackingToken,
        );

        if (backendStatus != 'active') {
          await _backgroundLocationService.stop();
          await _activeSosLocalService.clear();
          session = null;
        }
      } catch (error) {
        debugPrint('Could not verify active SOS: $error');
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _activeSosSession = session;
      _isCheckingSos = false;
      sosStatus = session == null
          ? 'SOS not started'
          : 'SOS is currently active';
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isSosActive = _activeSosSession != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency SOS'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Emergency Profile',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text('Name: $name'),
                    Text('Blood Group: $bloodGroup'),
                    Text('My Phone: $phone'),
                    Text('Relative: $relativeName ($relativePhone)'),
                    Text('Address: $address'),
                  ],
                ),
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: isSosActive ? openActiveSos : null,
              onLongPress: handleSosLongPress,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  color: isSosActive ? Colors.black : Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _isCancellingSos
                        ? 'CANCELLING...'
                        : isSosActive
                        ? 'SOS ACTIVE\nHOLD TO CANCEL'
                        : 'HOLD\nSOS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSosActive ? 24 : 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              sosStatus,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isSosActive
                  ? 'Tap to view the active SOS. Long press to cancel it.'
                  : 'Long press the SOS button to start emergency alert.',
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TrustedContactsScreen(),
                    ),
                  );
                },
                child: const Text('Trusted Contacts'),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileScreen(),
                    ),
                  );

                  if (result != null && result is UserProfile) {
                    updateProfileOnHome(result);
                  } else {
                    await loadSavedProfile();
                  }
                },
                child: const Text('Profile'),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SosHistoryScreen(),
                    ),
                  );
                },
                child: const Text('SOS History'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}