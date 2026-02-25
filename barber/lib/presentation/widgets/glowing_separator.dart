import 'package:flutter/material.dart';

class GlowingSeparator extends StatelessWidget {
  const GlowingSeparator({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // This creates the perfect physical black gap between the images 
      // so the light has room to bleed up and down.
      height: 5, 
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // --- LAYER 1: THE CENTRAL ILLUMINATION ---
          // FractionallySizedBox(
          //   widthFactor: 0.42, 
          //   child: Container(
          //     clipBehavior: Clip.hardEdge,
          //     height: 1, // Invisible core, used purely to cast the giant shadow
          //     decoration: BoxDecoration( 
          //       borderRadius: BorderRadius.circular(10), // Makes the shadow's edges rounded
          //       boxShadow: [
          //         BoxShadow(
          //           color: Colors.white.withOpacity(0.4),
          //           blurRadius: 8,
          //           spreadRadius: 8,
          //         ),
          //         BoxShadow(
          //           color: Colors.white.withOpacity(0.15),
          //           blurRadius: 16,
          //           spreadRadius: 15,
          //         ),
          //       ],
          //     ),
          //   ),
          // ),
          
          // --- LAYER 2: THE SHARP LASER CORE ---
          Container(
            height: 3.0, 
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(50),
              // NEW: Makes the actual physical line rounded (pill-shaped)
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.0), // Fades out completely at extreme left
                  Colors.white,                  // Solid white core starts
                  Colors.white,                  // Solid white core ends
                  Colors.white.withOpacity(0.0), // Fades out completely at extreme right
                ],
                // CHANGED: Pulled the stops inward so the fade takes longer. 
                // This creates the visual "pointy" taper at the edges.
                stops: const [0.0, 0.05, 0.95, 1.0], 
              ),
              boxShadow: [
                // Tight inner brightness so the line itself looks hot
                BoxShadow(
                  color: Colors.white.withOpacity(0.9),
                  blurRadius: 4,
                  spreadRadius: 0,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}