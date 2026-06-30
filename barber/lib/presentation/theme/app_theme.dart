import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
      color: Colors.transparent,
      child: child,
    );
  }
}

/// Premium dark theme for Barber Club
class AppTheme {
  static const String titleFontFamily = 'Orbitron';

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFD4AF37), // Gold
        secondary: Color(0xFFF5E6D3), // Beige
        surface: Color(0xFF1A1A1A),
        error: Color(0xFFCF6679),
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
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Colors.white,
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
          backgroundColor: const Color(0xFFD4AF37), // Garde l'or pour les gros boutons d'action principale
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: titleFontFamily,
          ),
        ),
      ),
      
      // --- MODIFICATION GLOBALE ICI ---
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          // On remplace Color(0xFFD4AF37) par Colors.white pour un style neutre premium
          foregroundColor: Colors.white, 
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(
            fontFamily: titleFontFamily,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      // --------------------------------

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white, // Assure que les boutons aux contours soient blancs aussi
          textStyle: const TextStyle(
            fontFamily: titleFontFamily,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ).copyWith(
        displayLarge: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 3, fontFamily: titleFontFamily),
        displayMedium: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 3, fontFamily: titleFontFamily),
        displaySmall: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 2, fontFamily: titleFontFamily),
        headlineLarge: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 2, fontFamily: titleFontFamily),
        headlineMedium: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, letterSpacing: 2, fontFamily: titleFontFamily),
        headlineSmall: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, letterSpacing: 2, fontFamily: titleFontFamily),
        titleLarge: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, letterSpacing: 2, fontFamily: titleFontFamily),
        titleMedium: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontFamily: titleFontFamily),
        titleSmall: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontFamily: titleFontFamily),
        bodyLarge: const TextStyle(color: Colors.white, fontWeight: FontWeight.w400,fontFamily: titleFontFamily),
        bodyMedium: const TextStyle(color: Colors.white, fontWeight: FontWeight.w400),
        bodySmall: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w400),
        labelLarge: const TextStyle(color: Colors.white, fontWeight: FontWeight.w400,fontFamily: titleFontFamily),
        labelMedium: const TextStyle(color: Colors.white, fontWeight: FontWeight.w400),
        labelSmall: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w400),
      ),
    );
  }
}