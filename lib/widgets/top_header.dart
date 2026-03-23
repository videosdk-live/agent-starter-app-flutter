import 'package:flutter/material.dart';
import 'package:videosdk/videosdk.dart';
import 'package:agent_starter_flutter/widgets/agent_state_pill.dart';

class TopHeader extends StatelessWidget {
  final AgentState state;
  final VoidCallback onSpeakerTap; // ← NEW
  const TopHeader({
    Key? key,
    required this.state,
    required this.onSpeakerTap, // ← NEW
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        // ← was Column
        alignment: Alignment.center,
        children: [
          Column(
            children: [
              Text(
                'Powered by VideoSDK',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 6),
              AgentStatePill(state: state),
            ],
          ),
          // Speaker button — top-right
          Positioned(
            right: 0,
            top: 0,
            child: GestureDetector(
              onTap: onSpeakerTap,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.volume_up_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
