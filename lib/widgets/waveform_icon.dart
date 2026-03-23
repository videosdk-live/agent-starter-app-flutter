import 'dart:math' as math;
import 'package:flutter/material.dart';

class WaveformIcon extends StatefulWidget {
  final Color color;
  const WaveformIcon({Key? key, this.color = const Color(0xFF37265E)})
      : super(key: key);

  @override
  State<WaveformIcon> createState() => WaveformIconState();
}

class WaveformIconState extends State<WaveformIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        size: const Size(20, 20), // fits exactly in SizedBox(20×20)
        painter: WaveformPainter(_ctrl.value, widget.color),
      ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  final double t;
  final Color color;
  WaveformPainter(this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0 // slightly thinner to fit 20px width
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const barCount = 5;
    // 5 bars + 4 gaps; bar width = gap width for even spacing
    // total = 5*barW + 4*barW = 9*barW = 20px → barW ≈ 2.2px, gap ≈ 2.2px
    final spacing = size.width / (barCount * 2 - 1);
    const heights = [0.4, 0.72, 1.0, 0.72, 0.4];

    for (int i = 0; i < barCount; i++) {
      final phase = (i / barCount + t) % 1.0;
      final h = size.height *
          heights[i] *
          (0.5 + 0.5 * math.sin(phase * math.pi * 2));
      final x = i * spacing * 2 + spacing / 2;
      final cy = size.height / 2;
      canvas.drawLine(Offset(x, cy - h / 2), Offset(x, cy + h / 2), paint);
    }
  }

  @override
  bool shouldRepaint(WaveformPainter old) => old.t != t || old.color != color;
}
