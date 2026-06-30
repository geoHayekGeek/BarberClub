import 'package:flutter/material.dart';

class AppSnackBar {
  static const Duration defaultDuration = Duration(seconds: 4);
  static const EdgeInsets defaultMargin = EdgeInsets.fromLTRB(16, 0, 16, 20);

  static String normalize(
    String? message, {
    String fallback = 'Une erreur est survenue. Veuillez reessayer.',
  }) {
    final normalized = message?.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
    return normalized.isEmpty ? fallback : normalized;
  }

  static SnackBar build(
    String? message, {
    Color backgroundColor = const Color(0xFF1A1A1A),
    Color foregroundColor = Colors.white,
    IconData icon = Icons.info_outline_rounded,
    Duration duration = defaultDuration,
    String fallback = 'Une erreur est survenue. Veuillez reessayer.',
  }) {
    final normalized = normalize(message, fallback: fallback);

    return SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: defaultMargin,
      elevation: 0,
      backgroundColor: backgroundColor,
      duration: duration,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      content: Row(
        children: [
          Icon(icon, color: foregroundColor, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              normalized,
              style: TextStyle(
                color: foregroundColor,
                fontSize: 13.5,
                height: 1.3,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void show(
    BuildContext context,
    String? message, {
    Color backgroundColor = const Color(0xFF1A1A1A),
    Color foregroundColor = Colors.white,
    IconData icon = Icons.info_outline_rounded,
    Duration duration = defaultDuration,
    String fallback = 'Une erreur est survenue. Veuillez reessayer.',
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      build(
        message,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        icon: icon,
        duration: duration,
        fallback: fallback,
      ),
    );
  }
}
