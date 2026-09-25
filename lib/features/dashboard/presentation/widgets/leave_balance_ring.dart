import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:hrm_app/features/dashboard/domain/entities/dashboard_snapshot.dart';

Color leaveBalanceColor(int index) =>
    const [Color(0xff315b8c), Color(0xff5d87b4), Color(0xffafc4dc)][index % 3];

class LeaveBalanceRing extends StatelessWidget {
  const LeaveBalanceRing({
    super.key,
    required this.balances,
    required this.selected,
  });
  final List<LeaveBalance> balances;
  final int selected;
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _RingPainter(
      balances,
      selected,
      Theme.of(context).colorScheme.surfaceContainerHigh,
    ),
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.balances, this.selected, this.track);
  final List<LeaveBalance> balances;
  final int selected;
  final Color track;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.max(0.0, size.shortestSide / 2 - 12);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, paint..color = track);
    final values = balances
        .map((b) => (b.total - b.used).clamp(0, b.total))
        .toList();
    final sum = values.fold<int>(0, (a, b) => a + b);
    if (sum == 0) return;
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = 2 * math.pi * values[i] / sum;
      if (sweep > 0) {
        paint
          ..color = leaveBalanceColor(balances[i].colorIndex)
          ..strokeWidth = i == selected ? 14 : 11;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          start,
          sweep,
          false,
          paint,
        );
      }
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.balances != balances ||
      oldDelegate.selected != selected ||
      oldDelegate.track != track;
}
