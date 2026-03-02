import 'package:flutter/material.dart';

/// Reusable overlay for QR scanner: center square (white border), dark outside, instruction text.
/// Used by both earn and redeem admin scanner screens.
class QrScannerOverlay extends StatelessWidget {
  const QrScannerOverlay({
    super.key,
    required this.instructionText,
  });

  final String instructionText;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: CustomPaint(
        painter: _QrScannerOverlayPainter(instructionText: instructionText),
      ),
    );
  }
}

class _QrScannerOverlayPainter extends CustomPainter {
  _QrScannerOverlayPainter({required this.instructionText});

  final String instructionText;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final side = size.width * 0.7;
    final rect = Rect.fromCenter(center: center, width: side, height: side);

    final darkPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), darkPaint);

    final clearPaint = Paint()
      ..color = Colors.transparent
      ..blendMode = BlendMode.clear;
    canvas.drawRect(rect, clearPaint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRect(rect, borderPaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: instructionText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((size.width - textPainter.width) / 2, rect.top - 40),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
