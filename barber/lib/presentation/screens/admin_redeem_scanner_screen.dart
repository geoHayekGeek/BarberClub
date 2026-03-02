import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../providers/auth_providers.dart';

/// Admin: scan voucher QR (BC|v1|V|...) to validate a reward redemption.
/// On success shows "Récompense validée" and reward name.
class AdminRedeemScannerScreen extends ConsumerStatefulWidget {
  const AdminRedeemScannerScreen({super.key});

  @override
  ConsumerState<AdminRedeemScannerScreen> createState() => _AdminRedeemScannerScreenState();
}

class _AdminRedeemScannerScreenState extends ConsumerState<AdminRedeemScannerScreen> {
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
    final qrPayload = capture.barcodes.firstOrNull?.rawValue?.trim();
    if (qrPayload == null || qrPayload.isEmpty) return;
    if (!qrPayload.startsWith('BC|v1|V|')) return;

    setState(() => _isSubmitting = true);
    try {
      final dio = ref.read(dioClientProvider).dio;
      final response = await dio.post<Map<String, dynamic>>(
        '/api/v1/admin/loyalty/redeem',
        data: {'qrPayload': qrPayload},
      );
      final data = response.data?['data'] as Map<String, dynamic>?;
      final rewardName = data?['rewardName'] as String? ?? '';
      final userName = data?['userName'] as String? ?? '';
      if (mounted) {
        _lastScanAt = DateTime.now();
        setState(() {});
        _startCooldownTimer();
        await _showSuccessDialog(context, rewardName: rewardName, userName: userName);
      }
    } catch (e) {
      if (mounted) {
        final isRateLimit = e is DioException && e.response?.statusCode == 429;
        final message = isRateLimit
            ? 'Attendez 5 secondes entre chaque scan'
            : 'QR invalide ou déjà utilisé';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
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

  static Future<void> _showSuccessDialog(
    BuildContext context, {
    required String rewardName,
    required String userName,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1C),
        title: const Text(
          'Récompense validée',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              rewardName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            if (userName.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                userName,
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
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
        MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 0,
          right: 0,
          child: Center(
            child: Text(
              'Scannez le bon du client',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
            ),
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
      ],
    );
  }
}
