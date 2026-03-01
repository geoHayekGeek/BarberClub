import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../providers/auth_providers.dart';

/// Admin QR scanner body. Disabled while scan request is in progress.
/// Success: "Point ajouté". Error: "QR invalide".
class AdminScannerScreen extends ConsumerStatefulWidget {
  const AdminScannerScreen({super.key});

  @override
  ConsumerState<AdminScannerScreen> createState() => _AdminScannerScreenState();
}

class _AdminScannerScreenState extends ConsumerState<AdminScannerScreen> {
  static const _scanCooldown = Duration(seconds: 5);

  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  bool _isSubmitting = false;
  DateTime? _lastScanAt;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isInCooldown {
    if (_lastScanAt == null) return false;
    return DateTime.now().difference(_lastScanAt!) < _scanCooldown;
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isSubmitting || _isInCooldown) return;
    final barcode = capture.barcodes.firstOrNull;
    final qrPayload = barcode?.rawValue?.trim();
    if (qrPayload == null || qrPayload.isEmpty) return;

    final serviceId = GoRouterState.of(context).uri.queryParameters['serviceId'];

    setState(() => _isSubmitting = true);
    try {
      final dio = ref.read(dioClientProvider).dio;

      if (serviceId != null && serviceId.isNotEmpty) {
        final response = await dio.post(
          '/api/v1/admin/loyalty/earn',
          data: {'qrPayload': qrPayload, 'serviceId': serviceId},
        );
        final data = response.data as Map<String, dynamic>;
        final res = data['data'] as Map<String, dynamic>?;
        final points = (res?['pointsEarned'] as num?)?.toInt() ?? 0;
        if (mounted) {
          _lastScanAt = DateTime.now();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('+$points points ajoutés'),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {});
          _startCooldownTimer();
        }
        return;
      }

      String endpoint;
      String successMessage;
      if (qrPayload.startsWith('BC|v1|V|')) {
        endpoint = '/api/v1/admin/loyalty/redeem';
        successMessage = 'Bon validé';
      } else if (qrPayload.startsWith('BC|v1|C|')) {
        endpoint = '/api/v1/admin/loyalty/redeem';
        successMessage = 'Coupe offerte validée';
      } else {
        endpoint = '/api/v1/admin/loyalty/scan';
        successMessage = 'Point ajouté';
      }

      await dio.post(
        endpoint,
        data: {'qrPayload': qrPayload},
      );

      if (mounted) {
        _lastScanAt = DateTime.now();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {});
        _startCooldownTimer();
      }
    } catch (e) {
      if (mounted) {
        final isRateLimit = e is DioException && e.response?.statusCode == 429;
        final message = isRateLimit ? 'Attendez 5 secondes entre chaque scan' : 'QR invalide';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
        if (isRateLimit) {
          _lastScanAt = DateTime.now();
          setState(() {});
          _startCooldownTimer();
        }
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _startCooldownTimer() {
    Future.delayed(_scanCooldown, () {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final serviceId = GoRouterState.of(context).uri.queryParameters['serviceId'];
    final hasServiceSelected = serviceId != null && serviceId.isNotEmpty;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (hasServiceSelected) {
          context.go('/admin');
          return;
        }
        if (Platform.isAndroid) {
          SystemNavigator.pop();
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: _ScannerOverlayPainter(),
            ),
          ),
          if (_isSubmitting)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          if (_isInCooldown && !_isSubmitting)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 16),
                    Text(
                      'Attendez 5 secondes...',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          if (hasServiceSelected)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => context.go('/admin'),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.7,
      height: size.width * 0.7,
    );

    canvas.drawRect(rect, paint);

    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'Scannez le QR code',
        style: TextStyle(
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
      Offset(
        (size.width - textPainter.width) / 2,
        rect.top - 40,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
