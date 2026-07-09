import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';

import 'dart:async';

import '../route_observer.dart';

import 'active_sos_screen.dart';
import 'custom_sos_message_screen.dart';
import 'trusted_contacts_screen.dart';
import 'profile_screen.dart';
import 'sos_history_screen.dart';
import 'permission_health_check_screen.dart';
import 'app_tour_screen.dart';

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
  static const Color _activeDark = Color(0xFF111827);

  static const String _shortcutInfoPopupDisabledKey =
      'shortcut_info_popup_disabled_v1';

  bool _shortcutInfoDialogShownInThisSession = false;

  static const bool _showAppTourEveryTimeForTesting = false;

  static const String _appTourCompletedKey = 'app_tour_completed_v1';

  bool _appTourCheckedInThisSession = false;

  static const bool _showHomeShowcaseEveryTimeForTesting = false;

  static const String _homeShowcaseCompletedKey =
      'home_showcase_completed_v1';

  bool _homeShowcaseStarted = false;

  final GlobalKey _sosButtonShowcaseKey = GlobalKey();
  final GlobalKey _sosMessageShowcaseKey = GlobalKey();
  final GlobalKey _safetyCheckShowcaseKey = GlobalKey();
  final GlobalKey _contactsShowcaseKey = GlobalKey();
  final GlobalKey _profileShowcaseKey = GlobalKey();
  final GlobalKey _historyShowcaseKey = GlobalKey();



  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    ShowcaseView.register(
      blurValue: 1.4,
      globalTooltipActionConfig: const TooltipActionConfig(
        position: TooltipActionPosition.outside,
        alignment: MainAxisAlignment.spaceBetween,
        actionGap: 12,
        gapBetweenContentAndAction: 14,
      ),
      globalTooltipActions: [
        TooltipActionButton(
          type: TooltipDefaultActionType.previous,
          backgroundColor: _fieldColor,
          borderRadius: BorderRadius.circular(999),
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 8,
          ),
          border: Border.all(
            color: _borderColor,
          ),
          textStyle: const TextStyle(
            color: Color(0xFFCBD5E1),
            fontWeight: FontWeight.w900,
          ),
        ),
        TooltipActionButton(
          type: TooltipDefaultActionType.next,
          backgroundColor: _dangerRed,
          borderRadius: BorderRadius.circular(999),
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          textStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        TooltipActionButton(
          type: TooltipDefaultActionType.skip,
          backgroundColor: Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          textStyle: const TextStyle(
            color: Color(0xFFFCA5A5),
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );

    unawaited(loadSavedProfile());
    unawaited(loadActiveSos());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(startHomeIntroFlow());
    });
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

  Future<void> showAppTourIfNeeded() async {
    if (!mounted || _appTourCheckedInThisSession) {
      return;
    }

    _appTourCheckedInThisSession = true;

    final prefs = await SharedPreferences.getInstance();

    if (!_showAppTourEveryTimeForTesting) {
      final isTourCompleted = prefs.getBool(_appTourCompletedKey) ?? false;

      if (isTourCompleted) {
        return;
      }
    }

    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const AppTourScreen(),
      ),
    );

    if (completed == true && !_showAppTourEveryTimeForTesting) {
      await prefs.setBool(_appTourCompletedKey, true);
    }
  }

  Future<void> startHomeIntroFlow() async {
    await showAppTourIfNeeded();

    if (!mounted) {
      return;
    }

    await Future.delayed(const Duration(milliseconds: 700));

    if (!mounted) {
      return;
    }

    final didStartHomeShowcase = await showHomeShowcaseIfNeeded();

    if (didStartHomeShowcase) {
      // Do not show shortcut popup on the same app open,
      // otherwise it can overlap/confuse the showcase flow.
      return;
    }

    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) {
      return;
    }

    await showShortcutFeatureInfoPopupIfNeeded();
  }

  Future<bool> showHomeShowcaseIfNeeded() async {
    if (!mounted || _homeShowcaseStarted) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();

    if (!_showHomeShowcaseEveryTimeForTesting) {
      final isShowcaseCompleted =
          prefs.getBool(_homeShowcaseCompletedKey) ?? false;

      if (isShowcaseCompleted) {
        return false;
      }
    }

    _homeShowcaseStarted = true;

    ShowcaseView.get().startShowCase([
      _sosButtonShowcaseKey,
      _sosMessageShowcaseKey,
      _safetyCheckShowcaseKey,
      _contactsShowcaseKey,
      _profileShowcaseKey,
      _historyShowcaseKey,
    ]);

    if (!_showHomeShowcaseEveryTimeForTesting) {
      await prefs.setBool(_homeShowcaseCompletedKey, true);
    }

    return true;
  }


  Future<void> showShortcutFeatureInfoPopupIfNeeded() async {
    if (!mounted || _shortcutInfoDialogShownInThisSession) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final isPopupDisabled =
        prefs.getBool(_shortcutInfoPopupDisabledKey) ?? false;

    if (isPopupDisabled) {
      return;
    }

    _shortcutInfoDialogShownInThisSession = true;

    bool doNotShowAgain = false;

    if (!_showAppTourEveryTimeForTesting) {
      final isTourCompleted = prefs.getBool(_appTourCompletedKey) ?? false;

      if (!isTourCompleted) {
        return;
      }
    }

    final shouldDisablePopup = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.72),
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: _cardColor,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
                side: const BorderSide(
                  color: _borderColor,
                ),
              ),
              titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
              contentPadding: const EdgeInsets.fromLTRB(22, 14, 22, 8),
              actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              title: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _dangerRed.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _dangerRed.withOpacity(0.28),
                      ),
                    ),
                    child: const Icon(
                      Icons.flash_on_rounded,
                      color: _dangerRed,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Quick SOS Shortcut',
                      style: TextStyle(
                        color: _primaryText,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'You can start emergency SOS faster using the home screen widget or quick SOS shortcut.',
                      style: TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 15,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'How it works',
                      style: TextStyle(
                        color: _primaryText,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),

                    _buildShortcutInfoPoint(
                      icon: Icons.widgets_rounded,
                      text: 'Add the SOS widget or shortcut icon to your home screen.',
                      color: _mapBlue,
                    ),
                    const SizedBox(height: 10),
                    _buildShortcutInfoPoint(
                      icon: Icons.touch_app_rounded,
                      text: 'Tap the widget or shortcut to open Quick SOS faster.',
                      color: _successGreen,
                    ),
                    const SizedBox(height: 10),
                    _buildShortcutInfoPoint(
                      icon: Icons.warning_amber_rounded,
                      text: 'Use it carefully to avoid accidental emergency alerts.',
                      color: _warningAmber,
                    ),

                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _dangerRed.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: _dangerRed.withOpacity(0.24),
                        ),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: _dangerRed,
                            size: 22,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Only use this shortcut when you really want to start emergency SOS.',
                              style: TextStyle(
                                fontSize: 13.5,
                                height: 1.45,
                                color: Color(0xFFFCA5A5),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    Theme(
                      data: Theme.of(context).copyWith(
                        checkboxTheme: CheckboxThemeData(
                          fillColor: WidgetStateProperty.resolveWith((states) {
                            if (states.contains(WidgetState.selected)) {
                              return _dangerRed;
                            }

                            return Colors.transparent;
                          }),
                          checkColor: WidgetStateProperty.all(Colors.white),
                          side: const BorderSide(
                            color: _mutedText,
                            width: 1.4,
                          ),
                        ),
                      ),
                      child: CheckboxListTile(
                        value: doNotShowAgain,
                        onChanged: (value) {
                          setDialogState(() {
                            doNotShowAgain = value ?? false;
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: _dangerRed,
                        title: const Text(
                          'Do not show again',
                          style: TextStyle(
                            color: _primaryText,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(false);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFCBD5E1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _dangerRed,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(dialogContext).pop(doNotShowAgain);
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: const Text(
                    'Got it',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldDisablePopup == true) {
      await prefs.setBool(_shortcutInfoPopupDisabledKey, true);
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
    ShowcaseView.get().unregister();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isSosActive = _activeSosSession != null;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double sosSize = screenWidth < 360 ? 198 : 230;

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text(
          'Emergency SOS',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
          ),
        ),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _buildAppBarStatus(isSosActive),
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 540),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(isSosActive),
                        const SizedBox(height: 18),
                        _buildStatusCard(isSosActive),
                        const SizedBox(height: 26),
                        _buildThemedShowcase(
                          showcaseKey: _sosButtonShowcaseKey,
                          title: 'Hold SOS Button',
                          description:
                              'Long press this button to start emergency SOS. It creates live tracking and alerts trusted contacts.',
                          targetShapeBorder: const CircleBorder(),
                          targetPadding: const EdgeInsets.all(8),
                          child: _buildSosButton(
                            isSosActive: isSosActive,
                            sosSize: sosSize,
                          ),
                        ),
                        const SizedBox(height: 22),
                        _buildInstructionText(isSosActive),
                        const SizedBox(height: 26),
                        _buildSosMessageAction(),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomActionBar(),
    );
  }

  Widget _buildAppBarStatus(bool isSosActive) {
    final Color color = isSosActive ? _dangerRed : _successGreen;

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _borderColor,
        ),
      ),
      child: Icon(
        isSosActive ? Icons.warning_amber_rounded : Icons.shield_rounded,
        color: color,
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

  Widget _buildThemedShowcase({
    required GlobalKey showcaseKey,
    required String title,
    required String description,
    required Widget child,
    ShapeBorder? targetShapeBorder,
    BorderRadius? targetBorderRadius,
    EdgeInsets targetPadding = EdgeInsets.zero,
  }) {
    final borderRadius = targetBorderRadius ?? BorderRadius.circular(22);

    return Showcase(
      key: showcaseKey,
      title: title,
      description: description,
      overlayColor: Colors.black,
      overlayOpacity: 0.74,
      blurValue: 1.4,
      tooltipBackgroundColor: _cardColor,
      textColor: _primaryText,
      tooltipBorderRadius: BorderRadius.circular(24),
      tooltipPadding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      titleTextStyle: const TextStyle(
        color: _primaryText,
        fontSize: 17,
        fontWeight: FontWeight.w900,
        height: 1.25,
      ),
      descTextStyle: const TextStyle(
        color: Color(0xFFCBD5E1),
        fontSize: 13.5,
        height: 1.45,
        fontWeight: FontWeight.w600,
      ),
      targetShapeBorder: targetShapeBorder ??
          RoundedRectangleBorder(
            borderRadius: borderRadius,
          ),
      targetBorderRadius: targetShapeBorder == null ? borderRadius : null,
      targetPadding: targetPadding,
      child: child,
    );
  }

  Widget _buildHeader(bool isSosActive) {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: (isSosActive ? _dangerRed : _successGreen)
                      .withOpacity(0.16),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: (isSosActive ? _dangerRed : _successGreen)
                        .withOpacity(0.35),
                  ),
                ),
                child: Icon(
                  isSosActive
                      ? Icons.emergency_share_rounded
                      : Icons.shield_rounded,
                  color: isSosActive ? _dangerRed : _successGreen,
                  size: 34,
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
                        color: _primaryText,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      isSosActive
                          ? 'Your emergency tracking session is currently running.'
                          : 'Hold the SOS button when you need emergency help.',
                      style: const TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 14,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildStatusBadge(
                icon: isSosActive
                    ? Icons.location_searching_rounded
                    : Icons.check_circle_outline_rounded,
                label: isSosActive ? 'Live tracking' : 'Ready',
                color: isSosActive ? _dangerRed : _successGreen,
              ),
              _buildStatusBadge(
                icon: Icons.sms_rounded,
                label: 'SMS fallback',
                color: _mapBlue,
              ),
              _buildStatusBadge(
                icon: Icons.contacts_rounded,
                label: 'Trusted contacts',
                color: _warningAmber,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(bool isSosActive) {
    final Color statusColor = isSosActive ? _dangerRed : _successGreen;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: statusColor.withOpacity(0.30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.24),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.14),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: statusColor.withOpacity(0.26),
              ),
            ),
            child: Icon(
              isSosActive
                  ? Icons.location_on_rounded
                  : Icons.check_circle_outline_rounded,
              color: statusColor,
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
                    color: _primaryText,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  isSosActive
                      ? 'Tap the SOS button to view active tracking details.'
                      : 'Emergency alert is ready to start.',
                  style: const TextStyle(
                    color: _mutedText,
                    fontSize: 13.5,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _buildLiveIndicator(isSosActive),
        ],
      ),
    );
  }

  Widget _buildLiveIndicator(bool isSosActive) {
    final Color color = isSosActive ? _dangerRed : _successGreen;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withOpacity(0.24),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isSosActive ? 'LIVE' : 'READY',
            style: TextStyle(
              color: color,
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
            boxShadow: [
              BoxShadow(
                color: _dangerRed.withOpacity(isSosActive ? 0.22 : 0.34),
                blurRadius: 38,
                spreadRadius: isSosActive ? 4 : 8,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.34),
                blurRadius: 28,
                offset: const Offset(0, 18),
              ),
            ],
            gradient: RadialGradient(
              colors: isSosActive
                  ? [
                      const Color(0xFFF87171),
                      _dangerRed,
                      _dangerDark,
                    ]
                  : [
                      const Color(0xFFFF8A8A),
                      _dangerRed,
                      _dangerDark,
                    ],
              stops: const [0.0, 0.65, 1.0],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.22),
              width: 3,
            ),
          ),
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.36),
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
                          ? 'STOPPING...'
                          : isSosActive
                              ? 'SOS ACTIVE\nTAP TO VIEW'
                              : 'HOLD\nSOS',
                  key: ValueKey(
                    '$_isCheckingSos-$_isCancellingSos-$isSosActive',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSosActive ? 20 : 38,
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
            color: _primaryText,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          isSosActive
              ? 'To stop the active SOS, open the active SOS screen or long press again.'
              : 'Your trusted contacts will receive emergency information with location.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _mutedText,
            fontSize: 13.5,
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Future<void> _openSafetyCheck() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PermissionHealthCheckScreen(),
      ),
    );
  }

  Future<void> _openTrustedContacts() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TrustedContactsScreen(),
      ),
    );
  }

  Future<void> _openProfile() async {
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
  }

  Future<void> _openSosHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SosHistoryScreen(),
      ),
    );
  }

  Future<void> _openSosMessage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CustomSosMessageScreen(),
      ),
    );
  }

  Widget _buildSosMessageAction() {
    return _buildThemedShowcase(
      showcaseKey: _sosMessageShowcaseKey,
      title: 'SOS Message',
      description:
          'Use this to customize the emergency SMS text that your trusted contacts will receive.',
      targetBorderRadius: BorderRadius.circular(22),
      targetPadding: const EdgeInsets.all(4),
      child: _buildActionTile(
        icon: Icons.edit_note_rounded,
        title: 'SOS Message',
        subtitle: 'Customize emergency SMS text',
        iconColor: _mapBlue,
        onTap: () {
          unawaited(_openSosMessage());
        },
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF162033), // slightly different from home bg
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: const Color(0xFF2B3A52),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.38),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              _buildBottomBarItem(
                showcaseKey: _safetyCheckShowcaseKey,
                showcaseTitle: 'Safety Check',
                showcaseDescription:
                    'Check GPS, SMS permission, internet, battery settings, profile, and trusted contacts before testing SOS.',
                icon: Icons.health_and_safety_rounded,
                label: 'Safety',
                color: _successGreen,
                onTap: () {
                  unawaited(_openSafetyCheck());
                },
              ),
              _buildBottomBarItem(
                showcaseKey: _contactsShowcaseKey,
                showcaseTitle: 'Trusted Contacts',
                showcaseDescription:
                    'Add or import the people who should receive your SOS alert and live location.',
                icon: Icons.contacts_rounded,
                label: 'Contacts',
                color: _dangerRed,
                onTap: () {
                  unawaited(_openTrustedContacts());
                },
              ),
              _buildBottomBarItem(
                showcaseKey: _profileShowcaseKey,
                showcaseTitle: 'Emergency Profile',
                showcaseDescription:
                    'Add your name, phone, blood group, address, and emergency relative details.',
                icon: Icons.person_rounded,
                label: 'Profile',
                color: _warningAmber,
                onTap: () {
                  unawaited(_openProfile());
                },
              ),
              _buildBottomBarItem(
                showcaseKey: _historyShowcaseKey,
                showcaseTitle: 'SOS History',
                showcaseDescription:
                    'View previous SOS events, start location, last updated location, status, and time details.',
                icon: Icons.history_rounded,
                label: 'History',
                color: _mapBlue,
                onTap: () {
                  unawaited(_openSosHistory());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBarItem({
    GlobalKey? showcaseKey,
    String? showcaseTitle,
    String? showcaseDescription,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    Widget item = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: color.withOpacity(0.25),
                  ),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFCBD5E1),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (showcaseKey != null) {
      item = _buildThemedShowcase(
        showcaseKey: showcaseKey,
        title: showcaseTitle ?? label,
        description: showcaseDescription ?? '',
        targetBorderRadius: BorderRadius.circular(20),
        targetPadding: const EdgeInsets.all(4),
        child: item,
      );
    }

    return Expanded(
      child: item,
    );
  }


  Widget _buildShortcutInfoPoint({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _fieldColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _borderColor,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withOpacity(0.26),
              ),
            ),
            child: Icon(
              icon,
              color: color,
              size: 19,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: _mutedText,
                fontSize: 13.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color iconColor,
  }) {
    return Material(
      color: _cardColor,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
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
                  color: iconColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: iconColor.withOpacity(0.26),
                  ),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
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
                        color: _primaryText,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _mutedText,
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
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
