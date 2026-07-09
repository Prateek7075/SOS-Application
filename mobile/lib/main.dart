import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'firebase_options.dart';
import 'route_observer.dart';
import 'screens/auth_gate.dart';
import 'screens/quick_sos_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const SosApp());
}

class SosApp extends StatelessWidget {
  const SosApp({super.key});

  static const Color bgColor = Color(0xFF0B1120);
  static const Color cardColor = Color(0xFF111827);
  static const Color fieldColor = Color(0xFF0F172A);
  static const Color borderColor = Color(0xFF243041);

  static const Color dangerRed = Color(0xFFEF4444);
  static const Color dangerDark = Color(0xFFB91C1C);
  static const Color successGreen = Color(0xFF22C55E);
  static const Color mapBlue = Color(0xFF3B82F6);
  static const Color warningAmber = Color(0xFFF59E0B);

  static const Color primaryText = Color(0xFFF8FAFC);
  static const Color mutedText = Color(0xFF94A3B8);
  static const Color softText = Color(0xFFCBD5E1);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Emergency SOS',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [routeObserver],

      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);

        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: const TextScaler.linear(0.92),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },

      routes: {
        '/quick-sos': (context) => const QuickSosScreen(),
      },
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: GoogleFonts.poppins().fontFamily,
        brightness: Brightness.dark,

        colorScheme: const ColorScheme.dark(
          primary: dangerRed,
          secondary: mapBlue,
          tertiary: warningAmber,
          surface: cardColor,
          error: dangerRed,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: primaryText,
          onError: Colors.white,
        ),

        scaffoldBackgroundColor: bgColor,
        canvasColor: bgColor,
        dialogBackgroundColor: cardColor,

        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          iconTheme: IconThemeData(
            color: Colors.white,
          ),
          actionsIconTheme: IconThemeData(
            color: Colors.white,
          ),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),

        cardTheme: CardThemeData(
          color: cardColor,
          elevation: 0,
          margin: EdgeInsets.zero,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(
              color: borderColor,
            ),
          ),
        ),

        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: dangerRed,
            foregroundColor: Colors.white,
            disabledBackgroundColor: dangerRed.withOpacity(0.45),
            disabledForegroundColor: Colors.white70,
            elevation: 0,
            shadowColor: Colors.transparent,
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            textStyle: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: dangerRed,
            foregroundColor: Colors.white,
            disabledBackgroundColor: dangerRed.withOpacity(0.45),
            disabledForegroundColor: Colors.white70,
            elevation: 0,
            shadowColor: Colors.transparent,
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            textStyle: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
        ),

        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: softText,
            disabledForegroundColor: mutedText,
            backgroundColor: fieldColor,
            minimumSize: const Size(double.infinity, 54),
            side: const BorderSide(
              color: borderColor,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),

        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: dangerRed,
            disabledForegroundColor: mutedText,
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: fieldColor,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          hintStyle: TextStyle(
            color: mutedText.withOpacity(0.72),
            fontWeight: FontWeight.w500,
          ),
          labelStyle: const TextStyle(
            color: mutedText,
            fontWeight: FontWeight.w600,
          ),
          prefixIconColor: mutedText,
          suffixIconColor: mutedText,
          errorStyle: const TextStyle(
            color: Color(0xFFFCA5A5),
            fontWeight: FontWeight.w600,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(
              color: borderColor,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(
              color: borderColor,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(
              color: mapBlue,
              width: 1.4,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(
              color: dangerRed,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(
              color: dangerRed,
              width: 1.4,
            ),
          ),
        ),

        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: cardColor,
          contentTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(
              color: borderColor,
            ),
          ),
        ),

        dialogTheme: DialogThemeData(
          backgroundColor: cardColor,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
            side: const BorderSide(
              color: borderColor,
            ),
          ),
          titleTextStyle: const TextStyle(
            color: primaryText,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
          contentTextStyle: const TextStyle(
            color: softText,
            fontSize: 14,
            height: 1.45,
            fontWeight: FontWeight.w500,
          ),
        ),

        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return dangerRed;
            }

            return Colors.transparent;
          }),
          checkColor: const WidgetStatePropertyAll(Colors.white),
          side: const BorderSide(
            color: mutedText,
            width: 1.4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
          ),
        ),

        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: dangerRed,
          circularTrackColor: borderColor,
        ),

        dividerTheme: const DividerThemeData(
          color: borderColor,
          thickness: 1,
        ),

        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: cardColor,
          selectedItemColor: dangerRed,
          unselectedItemColor: mutedText,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),

        iconTheme: const IconThemeData(
          color: softText,
        ),

        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: mapBlue,
          selectionColor: Color(0x553B82F6),
          selectionHandleColor: mapBlue,
        ),

        textTheme: GoogleFonts.poppinsTextTheme(
          const TextTheme(
            headlineLarge: TextStyle(
              color: primaryText,
              fontWeight: FontWeight.w900,
            ),
            headlineMedium: TextStyle(
              color: primaryText,
              fontWeight: FontWeight.w900,
            ),
            headlineSmall: TextStyle(
              color: primaryText,
              fontWeight: FontWeight.w900,
            ),
            titleLarge: TextStyle(
              color: primaryText,
              fontWeight: FontWeight.w900,
            ),
            titleMedium: TextStyle(
              color: primaryText,
              fontWeight: FontWeight.w800,
            ),
            titleSmall: TextStyle(
              color: primaryText,
              fontWeight: FontWeight.w700,
            ),
            bodyLarge: TextStyle(
              color: softText,
              fontWeight: FontWeight.w500,
            ),
            bodyMedium: TextStyle(
              color: softText,
              fontWeight: FontWeight.w500,
            ),
            bodySmall: TextStyle(
              color: mutedText,
              fontWeight: FontWeight.w500,
            ),
            labelLarge: TextStyle(
              color: primaryText,
              fontWeight: FontWeight.w800,
            ),
            labelMedium: TextStyle(
              color: mutedText,
              fontWeight: FontWeight.w700,
            ),
            labelSmall: TextStyle(
              color: mutedText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      home: AuthGate(),
    );
  }
}