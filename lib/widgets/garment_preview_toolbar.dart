import 'package:flutter/material.dart';

/// Place in Scaffold.appBar inside a Navigator route so dropdowns and tooltips
/// can use that route's Overlay.
class GarmentPreviewToolbar extends StatelessWidget implements PreferredSizeWidget {
  const GarmentPreviewToolbar({super.key, required this.profile,
    required this.onChanged, required this.onExit, required this.maleCount, required this.femaleCount});

  final String profile;
  final int maleCount, femaleCount;
  final ValueChanged<String> onChanged;
  final VoidCallback onExit;

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFE1F1ED),
    child: SafeArea(bottom: false, child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        const Expanded(child: Text('Garment preview',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
        DropdownButton<String>(
          value: profile,
          underline: const SizedBox.shrink(),
          items: [
            DropdownMenuItem(value: 'male', child: Text('Male · $maleCount')),
            DropdownMenuItem(value: 'female', child: Text('Female · $femaleCount')),
          ],
          onChanged: (value) { if (value != null) onChanged(value); },
        ),
        IconButton(tooltip: 'Exit preview',
          icon: const Icon(Icons.logout_rounded), onPressed: onExit),
      ]),
    )),
  );
}
