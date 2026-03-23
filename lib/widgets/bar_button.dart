import 'package:flutter/material.dart';
import 'package:agent_starter_flutter/widgets/speaker_animation.dart';

class BarButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isOff;
  final bool showChevron;
  final bool showDots;
  final bool showPermissionWarning;

  final bool isMenuOpen;
  final bool showSpeakerIndicator; // ← NEW
  final bool isSpeaking; // ← NEW
  final void Function(BuildContext chevronContext)? onChevronTap;

  const BarButton({
    Key? key,
    required this.icon,
    required this.onTap,
    this.isOff = false,
    this.showChevron = false,
    this.showDots = false,
    this.showPermissionWarning = false,
    this.isMenuOpen = false,
    this.showSpeakerIndicator = false, // ← NEW
    this.isSpeaking = false, // ← NEW
    this.onChevronTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final iconColor = isOff ? const Color(0xFFEF4444) : Colors.white;
    final bgColor =
        isOff ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.07);

    // Width grows when speaker indicator is shown
    final double w = showChevron
        ? 56.0
        : showSpeakerIndicator
            ? 64.0 // icon(18) + gap(6) + indicator(24) + padding
            : 32.0;
    const double h = 32.0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon tap zone
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTap,
                  child: SizedBox(
                    height: h,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Mic icon
                        Padding(
                          padding: EdgeInsets.only(
                            left: showSpeakerIndicator ? 10.0 : 0,
                          ),
                          child: Icon(icon, color: iconColor, size: 18),
                        ),

                        // Speaker indicator — inline after icon
                        if (showSpeakerIndicator) ...[
                          const SizedBox(width: 6),
                          SpeakerIndicator(
                            key: ValueKey(isSpeaking),
                            isSpeaking: isSpeaking,
                          ),
                          const SizedBox(width: 6),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // Chevron tap zone
              if (showChevron)
                Builder(
                  builder: (chevronCtx) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChevronTap?.call(chevronCtx),
                    child: SizedBox(
                      width: 20,
                      height: h,
                      child: Center(
                        child: Icon(
                          isMenuOpen
                              ? Icons.keyboard_arrow_up_outlined
                              : Icons.keyboard_arrow_down_outlined,
                          color: Colors.white.withOpacity(0.55),
                          size: 14,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Yellow warning badge
        if (showPermissionWarning)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(
                color: Color(0xFFFACC15),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Text(
                '!',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
