import 'package:flutter/material.dart';

/// Premium flat button with dark metallic finish
class AppPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Colors.grey.withOpacity(0.45),
            width: 1,
          ),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF2A2A2A),
              Color(0xFF1F1F1F),
            ],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Extremely subtle brushed texture
            Positioned.fill(
              child: Opacity(
                opacity: 0.02,
                child: CustomPaint(
                  painter: _BrushedPainter(),
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.8,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward,
                  color: Colors.white,
                  size: 17,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Painter for extremely subtle brushed texture
class _BrushedPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.15)
      ..strokeWidth = 1;

    for (double i = 0; i < size.width; i += 10) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
