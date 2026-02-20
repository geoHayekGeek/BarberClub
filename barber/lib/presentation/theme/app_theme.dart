import 'package:flutter/material.dart';

/// Uses [GlowingOverscrollIndicator] to avoid "Build scheduled during frame"
/// from [StretchingOverscrollIndicator] when scroll ends during layout.
class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return GlowingOverscrollIndicator(
      axisDirection: details.direction,
      color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
      child: child,
    );
  }
}

/// Premium dark theme for Barber Club
class AppTheme {
  static const String fontFamily = 'Orbitron';

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: fontFamily,
      colorScheme: ColorScheme.dark(
        primary: const Color(0xFFD4AF37), // Gold
        secondary: const Color(0xFFF5E6D3), // Beige
        surface: const Color(0xFF1A1A1A),
        error: const Color(0xFFCF6679),
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: Colors.white,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1A1A1A),
        elevation: 0,
        centerTitle: true,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCF6679)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCF6679), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFD4AF37),
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFFD4AF37),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      textTheme: ThemeData.dark().textTheme.apply(
        fontFamily: fontFamily,
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ).copyWith(
        displayLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 3, fontFamily: fontFamily),
        displayMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 3, fontFamily: fontFamily),
        displaySmall: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 2, fontFamily: fontFamily),
        headlineLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 2, fontFamily: fontFamily),
        headlineMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, letterSpacing: 2, fontFamily: fontFamily),
        headlineSmall: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, letterSpacing: 2, fontFamily: fontFamily),
        titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, letterSpacing: 2, fontFamily: fontFamily),
        titleMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontFamily: fontFamily),
        titleSmall: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontFamily: fontFamily),
        bodyLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w400, fontFamily: fontFamily),
        bodyMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w400, fontFamily: fontFamily),
        bodySmall: TextStyle(color: Colors.white70, fontWeight: FontWeight.w400, fontFamily: fontFamily),
        labelLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w400, fontFamily: fontFamily),
        labelMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w400, fontFamily: fontFamily),
        labelSmall: TextStyle(color: Colors.white70, fontWeight: FontWeight.w400, fontFamily: fontFamily),
      ),
    );
  }
}
