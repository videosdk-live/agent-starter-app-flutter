// ─────────────────────────────────────────────
//  Device Picker Popup
// ─────────────────────────────────────────────
import 'package:flutter/material.dart';

Future<void> showDevicePickerMenu({
  required BuildContext anchorContext,
  required List<String> deviceNames,
  required String? selectedDeviceName,
  required ValueChanged<int> onSelect,
}) async {
  if (deviceNames.isEmpty) return;

  final box = anchorContext.findRenderObject() as RenderBox?;
  if (box == null) return;
  final screenSize = MediaQuery.of(anchorContext).size;
  final offset = box.localToGlobal(Offset.zero);
  final size = box.size;

  await showMenu(
    context: anchorContext,
    color: const Color(0xFF2C2C2E),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    position: RelativeRect.fromLTRB(
      offset.dx,
      offset.dy - (deviceNames.length * 52.0 + 16),
      screenSize.width - (offset.dx + size.width),
      screenSize.height - offset.dy,
    ),
    items: List.generate(deviceNames.length, (i) {
      final isSelected = deviceNames[i] == selectedDeviceName;
      return PopupMenuItem<int>(
        value: i,
        onTap: () => onSelect(i),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: isSelected
                  ? const Icon(Icons.check_outlined,
                      color: Colors.white, size: 16)
                  : const SizedBox.shrink(),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                deviceNames[i],
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }),
  );
}
