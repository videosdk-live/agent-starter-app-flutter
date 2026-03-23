import 'package:flutter/material.dart';
import 'package:videosdk/videosdk.dart';

class MeetingOrb extends StatefulWidget {
  final AgentState agentState;
  const MeetingOrb({Key? key, required this.agentState}) : super(key: key);

  @override
  State<MeetingOrb> createState() => _MeetingOrbState();
}

class _MeetingOrbState extends State<MeetingOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  Color get _glowColor {
    switch (widget.agentState) {
      case AgentState.speaking:
        return const Color(0xFF0EA5E9).withOpacity(0.08);
      case AgentState.listening:
        return const Color(0xFF9CA3AF);
      case AgentState.thinking:
        return const Color(0xFF7C3AED).withOpacity(0.08);
      case AgentState.idle:
        return const Color(0xFFE1E2EA).withOpacity(0.05);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowCtrl,
      builder: (_, child) {
        final glowOpacity = widget.agentState == AgentState.idle
            ? 0.0
            : 0.25 + 0.2 * _glowCtrl.value;
        return Container(
          width: 280,
          height: 280,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _glowColor.withOpacity(glowOpacity),
                blurRadius: 60,
                spreadRadius: 10,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Image.asset(
        'assets/gif/agent.gif',
        width: 260,
        height: 260,
        fit: BoxFit.contain,
      ),
    );
  }
}
