import 'package:flutter/material.dart';

/// Reusable overlay for QR scanner: white scan frame and corner markers only.
/// Full camera feed visible; no dimmed overlay.
class ScannerOverlay extends StatelessWidget {
  const ScannerOverlay({
    super.key,
    this.instructionText,
  });

  /// Optional text shown above the scan frame (e.g. "Scannez le QR code").
  final String? instructionText;

  static const double _frameSize = 260;
  static const double _cornerLength = 24;
  static const double _cornerWidth = 4;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = size.width;
    final height = size.height;
    final frameTop = height * 0.32;
    final frameLeft = (width - _frameSize) / 2;

    return Positioned.fill(
      child: Stack(
        children: [
          if (instructionText != null && instructionText!.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              top: frameTop - 40,
              child: Center(
                child: Text(
                  instructionText!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    shadows: [
                      Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1)),
                      Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2)),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            top: frameTop,
            left: frameLeft,
            child: Container(
              width: _frameSize,
              height: _frameSize,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Positioned(
            top: frameTop,
            left: frameLeft,
            child: SizedBox(
              width: _frameSize,
              height: _frameSize,
              child: CustomPaint(
                painter: _CornerMarkersPainter(
                  cornerLength: _cornerLength,
                  cornerWidth: _cornerWidth,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CornerMarkersPainter extends CustomPainter {
  _CornerMarkersPainter({
    required this.cornerLength,
    required this.cornerWidth,
  });

  final double cornerLength;
  final double cornerWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final w = cornerWidth;
    final L = cornerLength;

    // Top-left
    canvas.drawRect(Rect.fromLTWH(0, 0, L, w), paint);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, L), paint);

    // Top-right
    canvas.drawRect(Rect.fromLTWH(size.width - L, 0, L, w), paint);
    canvas.drawRect(Rect.fromLTWH(size.width - w, 0, w, L), paint);

    // Bottom-left
    canvas.drawRect(Rect.fromLTWH(0, size.height - w, L, w), paint);
    canvas.drawRect(Rect.fromLTWH(0, size.height - L, w, L), paint);

    // Bottom-right
    canvas.drawRect(Rect.fromLTWH(size.width - L, size.height - w, L, w), paint);
    canvas.drawRect(Rect.fromLTWH(size.width - w, size.height - L, w, L), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
