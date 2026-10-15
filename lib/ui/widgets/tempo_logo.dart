import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Authentic vector emblem for TEMPO 2.0.
/// Visual concept: A minimalist chronometer flow ring merged with an abstract 'T' monogram
/// and dual time-stream arcs symbolizing "Plan everything. Force nothing. Finish what matters."
class TempoEmblemPainter extends CustomPainter {
  final Color primaryColor;
  final Color accentColor;
  final bool isDark;

  const TempoEmblemPainter({
    this.primaryColor = const Color(0xFF2563EB),
    this.accentColor = const Color(0xFF06B6D4),
    this.isDark = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = size.width * 0.11;

    final basePaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final accentPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Draw background subtle ring
    final bgRingPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.5;
    canvas.drawCircle(center, radius - strokeWidth, bgRingPaint);

    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    // 1. Primary outer arc: Left/Top flow (representing structured time budget)
    // From 140 degrees to 340 degrees (200 deg sweep)
    canvas.drawArc(
      rect,
      140 * math.pi / 180,
      190 * math.pi / 180,
      false,
      basePaint,
    );

    // 2. Accent arc: Bottom/Right flow (representing protected free time pool)
    // From 350 degrees to 110 degrees (120 deg sweep)
    canvas.drawArc(
      rect,
      -10 * math.pi / 180,
      120 * math.pi / 180,
      false,
      accentPaint,
    );

    // 3. Central Monogram 'T' Bar & Pillar
    final tStroke = strokeWidth * 0.95;
    final tPaint = Paint()
      ..color = isDark ? Colors.white : const Color(0xFF0F172A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = tStroke
      ..strokeCap = StrokeCap.round;

    // Horizontal top bar of T
    final barY = center.dy - radius * 0.35;
    final barHalfWidth = radius * 0.38;
    canvas.drawLine(
      Offset(center.dx - barHalfWidth, barY),
      Offset(center.dx + barHalfWidth, barY),
      tPaint,
    );

    // Vertical stem of T (flows smoothly downwards into dot)
    final stemBottomY = center.dy + radius * 0.38;
    canvas.drawLine(
      Offset(center.dx, barY),
      Offset(center.dx, stemBottomY),
      tPaint,
    );

    // Dynamic focus pulse dot at center-top
    final dotPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(center.dx, barY), strokeWidth * 0.32, dotPaint);
  }

  @override
  bool shouldRepaint(covariant TempoEmblemPainter oldDelegate) {
    return oldDelegate.primaryColor != primaryColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.isDark != isDark;
  }
}

class TempoLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final bool isDark;
  final String? subtitle;

  const TempoLogo({
    super.key,
    this.size = 32,
    this.showText = true,
    this.isDark = true,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final emblem = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: TempoEmblemPainter(isDark: isDark),
      ),
    );

    if (!showText) return emblem;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        emblem,
        SizedBox(width: size * 0.32),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'TEMPO',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                    fontSize: size * 0.55,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withOpacity(0.18),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFF2563EB).withOpacity(0.4),
                      width: 0.8,
                    ),
                  ),
                  child: const Text(
                    '2.0',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF06B6D4),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: size * 0.28,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.8,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
