import 'package:flutter/material.dart';

class GlowingBorder extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final ShapeBorder shape;
  final double strokeWidth;
  final Color color;
  final double glowSigma;

  const GlowingBorder({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(8),
    this.shape = const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
    this.strokeWidth = 2.0,
    this.color = const Color(0xFFFF00FF),
    this.glowSigma = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GlowingBorderPainter(
        shape: shape,
        strokeWidth: strokeWidth,
        color: color,
        glowSigma: glowSigma,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _GlowingBorderPainter extends CustomPainter {
  final ShapeBorder shape;
  final double strokeWidth;
  final Color color;
  final double glowSigma;

  _GlowingBorderPainter({
    required this.shape,
    required this.strokeWidth,
    required this.color,
    required this.glowSigma,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Path outerPath = shape.getOuterPath(rect);

    // Outer glow
    final Paint glowPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..maskFilter = MaskFilter.blur(BlurStyle.outer, glowSigma);
    canvas.drawPath(outerPath, glowPaint);

    // Crisp border on top
    final Paint strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawPath(outerPath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _GlowingBorderPainter oldDelegate) {
    return oldDelegate.shape != shape ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.color != color ||
        oldDelegate.glowSigma != glowSigma;
  }
}
