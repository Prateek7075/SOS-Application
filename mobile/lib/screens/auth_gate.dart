import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_api_service.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  AuthGate({super.key});

  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return const _AuthenticatedHome();
        }

        return const LoginScreen();
      },
    );
  }
}

class _AuthenticatedHome extends StatefulWidget {
  const _AuthenticatedHome();

  @override
  State<_AuthenticatedHome> createState() =>
      _AuthenticatedHomeState();
}

class _AuthenticatedHomeState extends State<_AuthenticatedHome> {
  final AuthApiService _authApiService = AuthApiService();

  @override
  void initState() {
    super.initState();
    unawaited(syncUser());
  }

  Future<void> syncUser() async {
    try {
      await _authApiService.syncUser();
      debugPrint('Firebase user synchronized with Laravel');
    } catch (error) {
      // Home remains available so offline SOS/SMS can still work.
      debugPrint('Laravel user sync failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const HomeScreen();
  }
}