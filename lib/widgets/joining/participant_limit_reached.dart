import 'package:flutter/material.dart';
import 'package:videosdk/videosdk.dart';

class ParticipantLimitReached extends StatelessWidget {
  final Room meeting;
  const ParticipantLimitReached({Key? key, required this.meeting})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Dark radial background
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

          // Orb gif behind the dialog
          Center(
            child: Image.asset(
              'assets/gif/agent.gif',
              width: 260,
              height: 260,
              fit: BoxFit.contain,
            ),
          ),

          // "Powered by VideoSDK" top label
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Powered by VideoSDK',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ),

          // Popup dialog centered
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + close
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Meeting Capacity Reached',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => meeting.leave(),
                          child: Icon(
                            Icons.close,
                            color: Colors.white.withOpacity(0.5),
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Message
                    Text(
                      'This meeting has reached its maximum limit of 2 participants. Please try joining again later.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.65),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Go Back button
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () => meeting.leave(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Go Back',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
