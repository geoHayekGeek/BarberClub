import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final token = barcode?.rawValue?.trim();
    if (token == null || token.isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      final dio = ref.read(dioClientProvider).dio;
      await dio.post(
        '/api/v1/admin/loyalty/scan',
        data: {'token': token},
      );
      if (mounted) {
        _lastScanAt = DateTime.now();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Point ajouté'),
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
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
        ],
      ),
    );
  }
}
