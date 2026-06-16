import 'dart:async';
import 'package:flutter/material.dart';

/// Live countdown to the server phase deadline (ticks every second).
class PhaseCountdown extends StatefulWidget {
  final int? deadlineMs;
  final bool prominent;

  const PhaseCountdown({
    super.key,
    required this.deadlineMs,
    this.prominent = false,
  });

  @override
  State<PhaseCountdown> createState() => _PhaseCountdownState();
}

class _PhaseCountdownState extends State<PhaseCountdown> {
  Timer? _tick;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _sync();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _sync());
  }

  @override
  void didUpdateWidget(PhaseCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deadlineMs != widget.deadlineMs) _sync();
  }

  void _sync() {
    final deadline = widget.deadlineMs;
    if (deadline == null) {
      if (_secondsLeft != 0) setState(() => _secondsLeft = 0);
      return;
    }
    final left = ((deadline - DateTime.now().millisecondsSinceEpoch) / 1000).ceil();
    final clamped = left < 0 ? 0 : left;
    if (clamped != _secondsLeft) setState(() => _secondsLeft = clamped);
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  static String _format(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Color _color(BuildContext context) {
    if (_secondsLeft <= 10) return Colors.red.shade700;
    if (_secondsLeft <= 30) return Colors.orange.shade800;
    return Theme.of(context).colorScheme.primary;
  }

  Color _background(BuildContext context) {
    if (_secondsLeft <= 10) return Colors.red.shade50;
    if (_secondsLeft <= 30) return Colors.orange.shade50;
    return Theme.of(context).colorScheme.surface;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.deadlineMs == null) return const SizedBox.shrink();

    final color = _color(context);
    final bg = _background(context);
    final time = _format(_secondsLeft);

    if (widget.prominent) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Icon(Icons.timer_outlined, size: 20, color: color),
            const SizedBox(width: 8),
            Text(
              'Time left',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const Spacer(),
            Text(
              time,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            time,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
