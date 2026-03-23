import 'dart:math' as math;

import 'package:flutter/material.dart';

class SpeakerIndicator extends StatefulWidget {
  final bool isSpeaking;
  const SpeakerIndicator({Key? key, required this.isSpeaking})
      : super(key: key);

  @override
  State<SpeakerIndicator> createState() => _SpeakerIndicatorState();
}

class _SpeakerIndicatorState extends State<SpeakerIndicator>
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
    return SizedBox(
      width: 18,
      height: 16,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: _WaveformBarPainter(
            t: _ctrl.value,
            isSpeaking: widget.isSpeaking,
          ),
        ),
      ),
    );
  }
}

// Single painter handles both states:
// isSpeaking = true  → tall animated bars (like "Talk to agent")
// isSpeaking = false → short flat bars, barely animated (idle)
class _WaveformBarPainter extends CustomPainter {
  final double t;
  final bool isSpeaking;

  _WaveformBarPainter({required this.t, required this.isSpeaking});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(isSpeaking ? 1.0 : 0.4)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const barCount = 3;
    final barSpacing = size.width / (barCount * 2 - 1);
    // Middle bar tallest
    const heightProfile = [0.6, 1.0, 0.6];

    for (int i = 0; i < barCount; i++) {
      double h;
      if (isSpeaking) {
        final phase = (i / barCount + t) % 1.0;
        h = size.height *
            heightProfile[i] *
            (0.5 + 0.5 * math.sin(phase * math.pi * 2));
      } else {
        // Completely static short bars
        h = size.height * 0.25 * heightProfile[i];
      }

      final x = i * barSpacing * 2 + barSpacing / 2;
      final cy = size.height / 2;
      canvas.drawLine(
        Offset(x, cy - h / 2),
        Offset(x, cy + h / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformBarPainter old) =>
      old.t != t || old.isSpeaking != isSpeaking;
}
