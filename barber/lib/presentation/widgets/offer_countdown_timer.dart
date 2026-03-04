import 'dart:async';
import 'package:flutter/material.dart';

/// Countdown to [endsAt]. Shows "Expire dans Xj Xh Xm" or "Expiré" when past.
class OfferCountdownTimer extends StatelessWidget {
  const OfferCountdownTimer({
    super.key,
    required this.endsAt,
    this.style,
  });

  final DateTime? endsAt;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    if (endsAt == null) return const SizedBox.shrink();
    return _CountdownText(endsAt: endsAt!, style: style);
  }
}

class _CountdownText extends StatefulWidget {
  const _CountdownText({required this.endsAt, this.style});

  final DateTime endsAt;
  final TextStyle? style;

  @override
  State<_CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<_CountdownText> {
  late Duration _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateRemaining());
  }

  void _updateRemaining() {
    final now = DateTime.now();
    if (widget.endsAt.isBefore(now)) {
      _timer?.cancel();
      if (mounted) setState(() => _remaining = Duration.zero);
      return;
    }
    _remaining = widget.endsAt.difference(now);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.style ?? TextStyle(
      fontSize: 12,
      color: Colors.white70,
      fontWeight: FontWeight.w500,
    );
    if (_remaining <= Duration.zero) {
      return Text('Expiré', style: s.copyWith(color: Colors.white54));
    }
    final days = _remaining.inDays;
    final hours = _remaining.inHours % 24;
    final minutes = _remaining.inMinutes % 60;
    String text;
    if (days > 0) {
      text = 'Expire dans ${days}j ${hours}h';
    } else if (hours > 0) {
      text = 'Expire dans ${hours}h ${minutes}min';
    } else {
      text = 'Expire dans ${minutes}min';
    }
    return Text(text, style: s);
  }
}
