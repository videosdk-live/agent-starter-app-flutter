import 'package:flutter/material.dart';

class HolographicOrb extends StatelessWidget {
  final bool isConnecting;
  const HolographicOrb({Key? key, this.isConnecting = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            'assets/gif/agent.gif',
            width: 260,
            height: 260,
            fit: BoxFit.contain,
          ),
          if (isConnecting)
            Positioned.fill(
              child: ClipOval(
                child: Container(
                  color: Colors.black.withOpacity(0.45),
                  child: const Center(
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
