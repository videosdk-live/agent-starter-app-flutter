import 'package:flutter/material.dart';
import 'package:videosdk/videosdk.dart';

class AgentStatePill extends StatelessWidget {
  final AgentState state;
  const AgentStatePill({Key? key, required this.state}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final config = _pillConfig(state);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: Container(
        key: ValueKey(state),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: config.bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: config.borderColor, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: config.dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              config.label,
              style: TextStyle(
                color: config.textColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  _PillConfig _pillConfig(AgentState s) {
    switch (s) {
      case AgentState.speaking:
        return _PillConfig(
          label: 'Speaking',
          dotColor: const Color(0xFF38BDF8),
          borderColor: const Color(0xFF0EA5E9).withOpacity(0.6),
          bgColor: const Color(0xFF0EA5E9).withOpacity(0.08),
          textColor: const Color(0xFF7DD3FC),
        );
      case AgentState.idle:
        return _PillConfig(
          label: 'Idle',
          dotColor: const Color(0xFFE1E2EA),
          borderColor: const Color(0xFFE1E2EA).withOpacity(0.10),
          bgColor: const Color(0xFFE1E2EA).withOpacity(0.05),
          textColor: const Color(0xFFE1E2EA),
        );
      case AgentState.thinking:
        return _PillConfig(
          label: 'Thinking',
          dotColor: const Color(0xFFA78BFA),
          borderColor: const Color(0xFF7C3AED).withOpacity(0.6),
          bgColor: const Color(0xFF7C3AED).withOpacity(0.08),
          textColor: const Color(0xFFC4B5FD),
        );
      case AgentState.listening:
        return _PillConfig(
          label: 'Listening',
          dotColor: const Color(0xFF9CA3AF),
          borderColor: const Color(0xFF6B7280).withOpacity(0.5),
          bgColor: Colors.transparent,
          textColor: const Color(0xFF9CA3AF),
        );
    }
  }
}

AgentState parseAgentState(dynamic raw) {
  final s = raw?.toString().toLowerCase() ?? '';
  if (s.contains('listen')) return AgentState.listening;
  if (s.contains('speak')) return AgentState.speaking;
  if (s.contains('think') || s.contains('process')) return AgentState.thinking;
  return AgentState.idle;
}

class _PillConfig {
  final String label;
  final Color dotColor, borderColor, bgColor, textColor;
  _PillConfig({
    required this.label,
    required this.dotColor,
    required this.borderColor,
    required this.bgColor,
    required this.textColor,
  });
}

class ConnectingPill extends StatelessWidget {
  const ConnectingPill({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFB45309).withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFB45309).withOpacity(0.6),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Color(0xFFFBBF24),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'Connecting...',
            style: TextStyle(
              color: Color(0xFFFDE68A),
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
