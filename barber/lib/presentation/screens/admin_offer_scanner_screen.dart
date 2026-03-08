import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../providers/auth_providers.dart';
import '../widgets/scanner_overlay.dart';

/// Admin: scan offer activation QR (BC|v1|OFFER|token) to validate and set status = activated.
class AdminOfferScannerScreen extends ConsumerStatefulWidget {
  const AdminOfferScannerScreen({super.key});

  @override
  ConsumerState<AdminOfferScannerScreen> createState() => _AdminOfferScannerScreenState();
}

class _AdminOfferScannerScreenState extends ConsumerState<AdminOfferScannerScreen> {
  static const _scanCooldown = Duration(seconds: 5);
  static const _cameraStartDelay = Duration(milliseconds: 500);

  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  bool _cameraReady = false;
  bool _isSubmitting = false;
  bool _isProcessing = false;
  DateTime? _lastScanAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(_cameraStartDelay, () {
        if (mounted) setState(() => _cameraReady = true);
      });
    });
  }

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
    if (_isProcessing || _isSubmitting || _isInCooldown) return;
    final qrPayload = capture.barcodes.firstOrNull?.rawValue?.trim();
    if (qrPayload == null || qrPayload.isEmpty) return;
    if (!qrPayload.startsWith('BC|v1|OFFER|')) return;

    _isProcessing = true;
    if (mounted) setState(() => _isSubmitting = true);
    try {
      final dio = ref.read(dioClientProvider).dio;
      final response = await dio.post<Map<String, dynamic>>(
        '/api/v1/admin/offers/validate',
        data: {'qrPayload': qrPayload},
      );
      final data = response.data?['data'] as Map<String, dynamic>?;
      final offerName = data?['offerName'] as String? ?? '';
      final clientName = data?['clientName'] as String? ?? '';
      if (!mounted) return;
      _lastScanAt = DateTime.now();
      setState(() {});
      _startCooldownTimer();
      await _showSuccessDialog(context, offerName: offerName, clientName: clientName);
    } catch (e) {
      if (!mounted) return;
      final isRateLimit = e is DioException && e.response?.statusCode == 429;
      String message;
      if (isRateLimit) {
        message = 'Attendez 5 secondes entre chaque scan';
        _lastScanAt = DateTime.now();
        setState(() {});
        _startCooldownTimer();
      } else {
        final code = e is DioException
            ? (e.response?.data as Map<String, dynamic>?)?['error']?['code'] as String?
            : null;
        if (code == 'INVALID_OR_EXPIRED_QR' || code == 'INVALID_QR') {
          message = 'QR déjà utilisé ou invalide';
        } else {
          message = 'QR invalide';
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } finally {
      _isProcessing = false;
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _startCooldownTimer() {
    Future.delayed(_scanCooldown, () {
      if (mounted) setState(() {});
    });
  }

  static Future<void> _showSuccessDialog(
    BuildContext context, {
    required String offerName,
    required String clientName,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1C),
        title: const Text(
          'Offre activée',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              offerName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              clientName,
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_cameraReady)
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          )
        else
          const ColoredBox(
            color: Colors.black,
            child: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
        if (_cameraReady) const ScannerOverlay(instructionText: 'Scannez le QR d\'activation offre'),
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
    );
  }
}
