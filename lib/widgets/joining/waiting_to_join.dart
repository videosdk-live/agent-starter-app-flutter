import 'dart:math' as dart_math;

import 'package:flutter/material.dart';
import 'package:agent_starter_flutter/widgets/agent_state_pill.dart';

class WaitingToJoin extends StatelessWidget {
  const WaitingToJoin({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topSafeArea = MediaQuery.of(context).padding.top;
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;

    // Mirrors bigViewTop from _buildVideoMeetingUI exactly
    const headerHeight = 62.0;
    const gapBelowHeader = 18.0;
    const horizontalPadding = 16.0;
    const bottomBarHeight = 80.0;

    final contentTop = topSafeArea + 8 + headerHeight + gapBelowHeader;
    final bottomReserved = bottomBarHeight + bottomSafeArea;

    // Orb area = space between contentTop and bottom bar
    final orbAreaHeight = size.height - contentTop - bottomReserved;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Radial background ──────────────────────────────────────
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.1,
                  colors: [Color(0xFF000000), Color(0xFF000000)],
                ),
              ),
            ),
          ),

          // ── Top vignette ───────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 200,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.4),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Bottom vignette ────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 280,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.85),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Header — pinned at exact same top as _TopHeader ────────
          Positioned(
            top: topSafeArea + 8,
            left: horizontalPadding,
            right: horizontalPadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Powered by VideoSDK',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.38),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 6),
                const ConnectingPill(),
              ],
            ),
          ),

          // ── Orb/GIF — centered in the exact same region as bigFeed ─
          Positioned(
            top: contentTop,
            left: horizontalPadding,
            right: horizontalPadding,
            height: orbAreaHeight,
            child: Center(
              child: SizedBox(
                width: 260,
                height: 260,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Opacity(
                      opacity: 0.35, // ← dims the GIF
                      child: Image.asset(
                        'assets/gif/agent.gif',
                        width: 260,
                        height: 260,
                        fit: BoxFit.contain,
                      ),
                    ),

                    // Spinner overlay — same style as iOS spinner in your screenshot
                    const _SpinnerOverlay(),
                  ],
                ),
              ),
            ),
          ),
          // ── Bottom placeholder — same height as _buildBottomBar ────
          // Keeps visual weight identical to the meeting screen
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: bottomReserved,
            child: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _SpinnerOverlay extends StatefulWidget {
  const _SpinnerOverlay();

  @override
  State<_SpinnerOverlay> createState() => _SpinnerOverlayState();
}

class _SpinnerOverlayState extends State<_SpinnerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
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
        size: const Size(24, 24),
        painter: _IosSpinnerPainter(_ctrl.value),
      ),
    );
  }
}

class _IosSpinnerPainter extends CustomPainter {
  final double progress; // 0.0 – 1.0
  _IosSpinnerPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    const spokeCount = 12;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final innerR = size.width * 0.22;
    final outerR = size.width * 0.46;

    for (int i = 0; i < spokeCount; i++) {
      // Spoke i is "brightest" when progress aligns with it
      final age = (progress - i / spokeCount) % 1.0;
      final opacity = (1.0 - age).clamp(0.15, 1.0);

      final paint = Paint()
        ..color = Colors.white.withOpacity(opacity)
        ..strokeWidth = size.width * 0.09
        ..strokeCap = StrokeCap.round;

      final angle = (i / spokeCount) * 2 * 3.141592653589793;
      canvas.drawLine(
        Offset(cx + innerR * cos(angle), cy + innerR * sin(angle)),
        Offset(cx + outerR * cos(angle), cy + outerR * sin(angle)),
        paint,
      );
    }
  }

  double cos(double a) => dart_math.cos(a);
  double sin(double a) => dart_math.sin(a);

  @override
  bool shouldRepaint(_IosSpinnerPainter old) => old.progress != progress;
}
