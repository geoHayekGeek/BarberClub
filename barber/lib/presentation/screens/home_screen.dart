import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/home_header.dart';
import '../widgets/home_center_content.dart';

/// Home screen (Accueil) - Premium barber experience
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Fullscreen background image with gradient overlay
          _BackgroundWithOverlay(),
          // Header (transparent overlay)
          const HomeHeader(),
          // Center content
          const HomeCenterContent(),
        ],
      ),
    );
  }
}

/// Background image with dark gradient overlay
class _BackgroundWithOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background image
        // TODO: Replace with actual backend image URL when available
        Image.asset(
          'assets/images/barber_background.jpg',
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            // Placeholder gradient if image not found
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF1A1A1A),
                    const Color(0xFF121212),
                  ],
                ),
              ),
            );
          },
        ),
        // Dark gradient overlay (top → bottom)
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.35), // Top
                Colors.black.withOpacity(0.75), // Bottom
              ],
            ),
          ),
        ),
      ],
    );
  }
}
