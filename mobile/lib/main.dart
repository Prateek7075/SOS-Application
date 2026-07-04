import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const SosApp());
}

class SosApp extends StatelessWidget {
  const SosApp({super.key});

  static const Color dangerRed = Color(0xFFE53935);
  static const Color darkText = Color(0xFF111827);
  static const Color mutedText = Color(0xFF6B7280);
  static const Color softBackground = Color(0xFFF8FAFC);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Emergency SOS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,

        colorScheme: ColorScheme.fromSeed(
          seedColor: dangerRed,
          primary: dangerRed,
          secondary: darkText,
          surface: Colors.white,
        ),

        scaffoldBackgroundColor: softBackground,

        appBarTheme: const AppBarTheme(
          backgroundColor: softBackground,
          elevation: 0,
          centerTitle: false,
          iconTheme: IconThemeData(
            color: darkText,
          ),
          titleTextStyle: TextStyle(
            color: darkText,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),

        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: dangerRed,
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),

        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: dangerRed,
            minimumSize: const Size(double.infinity, 52),
            side: const BorderSide(
              color: Color(0xFFE5E7EB),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),

        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: dangerRed,
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
          hintStyle: const TextStyle(
            color: mutedText,
          ),
          labelStyle: const TextStyle(
            color: mutedText,
            fontWeight: FontWeight.w600,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: Color(0xFFE5E7EB),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: Color(0xFFE5E7EB),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: dangerRed,
              width: 1.4,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: dangerRed,
            ),
          ),
        ),

        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: darkText,
          contentTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),

        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: dangerRed,
          unselectedItemColor: mutedText,
          type: BottomNavigationBarType.fixed,
          elevation: 10,
        ),

        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            color: darkText,
            fontWeight: FontWeight.w900,
          ),
          headlineMedium: TextStyle(
            color: darkText,
            fontWeight: FontWeight.w800,
          ),
          titleLarge: TextStyle(
            color: darkText,
            fontWeight: FontWeight.w800,
          ),
          titleMedium: TextStyle(
            color: darkText,
            fontWeight: FontWeight.w700,
          ),
          bodyLarge: TextStyle(
            color: darkText,
          ),
          bodyMedium: TextStyle(
            color: darkText,
          ),
          bodySmall: TextStyle(
            color: mutedText,
          ),
        ),
      ),
      home: AuthGate(),
    );
  }
}