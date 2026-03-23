import 'package:flutter/material.dart';
import 'package:agent_starter_flutter/widgets/waveform_icon.dart';

class TalkButton extends StatefulWidget {
  final VoidCallback onTap;
  const TalkButton({Key? key, required this.onTap}) : super(key: key);

  @override
  State<TalkButton> createState() => _TalkButtonState();
}

class _TalkButtonState extends State<TalkButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 0.04,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: 354,
          height: 40, // 40px tall (8px top + 24px content + 8px bottom)
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.15),
                blurRadius: 24,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment:
                MainAxisAlignment.center, // gives ~115px each side
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Wave icon: 20×20
              SizedBox(
                width: 20,
                height: 20,
                child: WaveformIcon(color: Color(0xFF37265E)),
              ),

              SizedBox(width: 2), // 2px gap

              // Text: 100×24
              SizedBox(
                width: 100,
                height: 24,
                child: Center(
                  child: Text(
                    'Talk to agent',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.1,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
