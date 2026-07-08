import 'package:flutter/material.dart';

import 'dart:async';

import '../route_observer.dart';

import 'active_sos_screen.dart';
import 'custom_sos_message_screen.dart';
import 'trusted_contacts_screen.dart';
import 'profile_screen.dart';
import 'sos_history_screen.dart';
import 'permission_health_check_screen.dart';

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

class _HomeScreenState extends State<HomeScreen> with RouteAware, WidgetsBindingObserver {

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
  bool _isRouteObserverSubscribed = false;

  static const Color _dangerRed = Color(0xFFE53935);
  static const Color _dangerDark = Color(0xFFB91C1C);
  static const Color _darkText = Color(0xFF111827);
  static const Color _mutedText = Color(0xFF6B7280);
  static const Color _softBg = Color(0xFFF8FAFC);
  static const Color _cardBg = Colors.white;
  static const Color _activeDark = Color(0xFF111827);

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    unawaited(loadSavedProfile());
    unawaited(loadActiveSos());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_isRouteObserverSubscribed) {
      return;
    }

    final route = ModalRoute.of(context);

    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
      _isRouteObserverSubscribed = true;
    }
  }

  @override
  void didPopNext() {
    // Called when user comes back to Home from Active SOS / Quick SOS.
    unawaited(loadActiveSos());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(loadActiveSos());
    }
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
          behavior: SnackBarBehavior.floating,
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
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> loadActiveSos() async {
    final localSession = await _activeSosLocalService.getActiveSos();

    if (!mounted) {
      return;
    }

    // Fast UI update from local storage first.
    setState(() {
      _activeSosSession = localSession;
      _isCheckingSos = false;
      sosStatus = localSession == null
          ? 'Checking active SOS...'
          : 'SOS is currently active';
    });

    try {
      final backendActiveSos = await _sosApiService.getActiveSos();

      if (!mounted) {
        return;
      }

      if (backendActiveSos == null) {
        await _backgroundLocationService.stop();
        await _activeSosLocalService.clear();

        if (!mounted) {
          return;
        }

        setState(() {
          _activeSosSession = null;
          _isCheckingSos = false;
          sosStatus = 'SOS not started';
        });

        return;
      }

      await _activeSosLocalService.save(
        sosEventId: backendActiveSos.id,
        trackingToken: backendActiveSos.trackingToken,
        trackingUrl: backendActiveSos.trackingUrl,
        batteryPercentage: localSession?.batteryPercentage,
      );

      final updatedSession = await _activeSosLocalService.getActiveSos();

      if (!mounted) {
        return;
      }

      setState(() {
        _activeSosSession = updatedSession;
        _isCheckingSos = false;
        sosStatus = 'SOS is currently active';
      });
    } catch (error) {
      debugPrint('Could not load active SOS from backend: $error');

      if (!mounted) {
        return;
      }

      // If backend check fails, keep local session if available.
      // Do not clear it because the user may have slow/no internet.
      setState(() {
        _isCheckingSos = false;
        sosStatus = localSession == null
            ? 'SOS not started'
            : 'SOS is currently active';
      });
    }
  }

  Future<void> verifyActiveSosWithBackend(ActiveSosSession session) async {
    try {
      final backendStatus = await _sosApiService.getTrackingStatus(
        trackingToken: session.trackingToken,
      );

      final latestLocalSession = await _activeSosLocalService.getActiveSos();

      if (!mounted) {
        return;
      }

      // If local session changed while backend was checking, ignore old result.
      if (latestLocalSession == null ||
          latestLocalSession.trackingToken != session.trackingToken) {
        return;
      }

      if (backendStatus != 'active') {
        await _backgroundLocationService.stop();
        await _activeSosLocalService.clear();

        if (!mounted) {
          return;
        }

        setState(() {
          _activeSosSession = null;
          sosStatus = 'SOS not started';
        });
      }
    } catch (error) {
      debugPrint('Could not verify active SOS with backend: $error');

      // Do not clear local SOS if backend check fails.
      // Internet may be slow/offline, but SOS may still be active.
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isSosActive = _activeSosSession != null;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double sosSize = screenWidth < 360 ? 190 : 220;

    return Scaffold(
      backgroundColor: _softBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _softBg,
        centerTitle: false,
        title: const Text(
          'Emergency SOS',
          style: TextStyle(
            color: _darkText,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              backgroundColor:
              isSosActive ? _dangerRed.withOpacity(0.12) : Colors.green.withOpacity(0.12),
              child: Icon(
                isSosActive
                    ? Icons.warning_amber_rounded
                    : Icons.shield_outlined,
                color: isSosActive ? _dangerRed : Colors.green,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(isSosActive),
                      const SizedBox(height: 18),
                      _buildStatusCard(isSosActive),
                      const SizedBox(height: 26),
                      _buildSosButton(
                        isSosActive: isSosActive,
                        sosSize: sosSize,
                      ),
                      const SizedBox(height: 22),
                      _buildInstructionText(isSosActive),
                      const SizedBox(height: 26),
                      _buildEmergencyProfileCard(),
                      const SizedBox(height: 20),
                      _buildQuickActions(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(bool isSosActive) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isSosActive
              ? [
            _activeDark,
            const Color(0xFF374151),
          ]
              : [
            _dangerRed,
            _dangerDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: (isSosActive ? _activeDark : _dangerRed).withOpacity(0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emergency_share_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSosActive ? 'SOS is active' : 'Stay safe, $name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isSosActive
                      ? 'Your emergency session is running.'
                      : 'Hold the SOS button when you need help.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.88),
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(bool isSosActive) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isSosActive
              ? _dangerRed.withOpacity(0.24)
              : Colors.green.withOpacity(0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isSosActive
                  ? _dangerRed.withOpacity(0.12)
                  : Colors.green.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              isSosActive
                  ? Icons.location_on_rounded
                  : Icons.check_circle_outline_rounded,
              color: isSosActive ? _dangerRed : Colors.green,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sosStatus,
                  style: const TextStyle(
                    color: _darkText,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isSosActive
                      ? 'Tap SOS button to view active tracking.'
                      : 'Emergency alert is ready to start.',
                  style: const TextStyle(
                    color: _mutedText,
                    fontSize: 13.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          _buildLiveIndicator(isSosActive),
        ],
      ),
    );
  }

  Widget _buildLiveIndicator(bool isSosActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isSosActive
            ? _dangerRed.withOpacity(0.1)
            : Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: isSosActive ? _dangerRed : Colors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isSosActive ? 'LIVE' : 'READY',
            style: TextStyle(
              color: isSosActive ? _dangerRed : Colors.green,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSosButton({
    required bool isSosActive,
    required double sosSize,
  }) {
    final bool disabled = _isCheckingSos || _isCancellingSos;

    return Center(
      child: GestureDetector(
        onTap: isSosActive
            ? () {
          openActiveSos();
        }
            : null,
        onLongPress: disabled
            ? null
            : () {
          handleSosLongPress();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: sosSize,
          height: sosSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: isSosActive
                  ? [
                _activeDark,
                const Color(0xFF374151),
              ]
                  : [
                const Color(0xFFFF5252),
                _dangerRed,
                _dangerDark,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: (isSosActive ? _activeDark : _dangerRed)
                    .withOpacity(0.35),
                blurRadius: 32,
                offset: const Offset(0, 18),
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.9),
                blurRadius: 10,
                offset: const Offset(-4, -4),
              ),
            ],
          ),
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.55),
                width: 2,
              ),
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  _isCheckingSos
                      ? 'CHECKING...'
                      : _isCancellingSos
                      ? 'CANCELLING...'
                      : isSosActive
                      ? 'SOS ACTIVE\nHOLD TO CANCEL'
                      : 'HOLD\nSOS',
                  key: ValueKey(
                    '$_isCheckingSos-$_isCancellingSos-$isSosActive',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSosActive ? 20 : 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    height: 1.12,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionText(bool isSosActive) {
    return Column(
      children: [
        Text(
          isSosActive
              ? 'Tap the button to view live SOS details.'
              : 'Long press the SOS button to send emergency alert.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _darkText,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          isSosActive
              ? 'Long press again only if you want to cancel the active SOS.'
              : 'Your contacts will receive emergency information with location.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _mutedText,
            fontSize: 13.5,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildEmergencyProfileCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _dangerRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.badge_outlined,
                  color: _dangerRed,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Emergency Profile',
                      style: TextStyle(
                        color: _darkText,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Important details for emergency use',
                      style: TextStyle(
                        color: _mutedText,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildProfileRow(
            icon: Icons.person_outline_rounded,
            label: 'Name',
            value: name,
          ),
          _buildProfileRow(
            icon: Icons.bloodtype_outlined,
            label: 'Blood Group',
            value: bloodGroup,
            isImportant: true,
          ),
          _buildProfileRow(
            icon: Icons.phone_outlined,
            label: 'My Phone',
            value: phone,
          ),
          _buildProfileRow(
            icon: Icons.family_restroom_outlined,
            label: 'Relative',
            value: '$relativeName ($relativePhone)',
          ),
          _buildProfileRow(
            icon: Icons.home_outlined,
            label: 'Address',
            value: address,
          ),
        ],
      ),
    );
  }

  Widget _buildProfileRow({
    required IconData icon,
    required String label,
    required String value,
    bool isImportant = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: isImportant ? _dangerRed : _mutedText,
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(
                color: _mutedText,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isImportant ? _dangerRed : _darkText,
                fontSize: 14.5,
                fontWeight: isImportant ? FontWeight.w800 : FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            color: _darkText,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        _buildActionTile(
          icon: Icons.health_and_safety_rounded,
          title: 'Safety Check',
          subtitle: 'Check permissions and SOS readiness',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PermissionHealthCheckScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildActionTile(
          icon: Icons.edit_note_rounded,
          title: 'SOS Message',
          subtitle: 'Customize emergency SMS text',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CustomSosMessageScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildActionTile(
          icon: Icons.contacts_rounded,
          title: 'Trusted Contacts',
          subtitle: 'Add, edit, or delete emergency contacts',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const TrustedContactsScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildActionTile(
          icon: Icons.person_rounded,
          title: 'Profile',
          subtitle: 'Update your medical and personal details',
          onTap: () async {
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
        ),
        const SizedBox(height: 12),
        _buildActionTile(
          icon: Icons.history_rounded,
          title: 'SOS History',
          subtitle: 'View your previous emergency alerts',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SosHistoryScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: _cardBg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFE5E7EB),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _dangerRed.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  icon,
                  color: _dangerRed,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _darkText,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _mutedText,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: _mutedText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}