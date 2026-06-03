// Horizontal row of file-type filter chips, shared by the Files dashboard and
// the drive folder browser.

import 'package:flutter/material.dart';
import 'package:shared_widgets/theme/app_palette.dart';

import 'package:kleenops_admin/features/files/utils/file_kinds.dart';

class DriveFilterBar extends StatelessWidget {
  const DriveFilterBar({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  /// `null` selects the "All" chip.
  final FileKind? selected;
  final ValueChanged<FileKind?> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteScope.of(context);
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: kDriveFilterKinds.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final kind = kDriveFilterKinds[i];
          final isSelected = kind == selected;
          return ChoiceChip(
            label: Text(driveFilterLabel(kind)),
            selected: isSelected,
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
            labelStyle: TextStyle(
              fontSize: 13,
              color: isSelected ? palette.primary1 : Colors.grey.shade700,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
            backgroundColor: Colors.white,
            selectedColor: palette.primary2,
            side: BorderSide(
              color: isSelected ? palette.primary2 : Colors.grey.shade300,
            ),
            onSelected: (_) => onChanged(kind),
          );
        },
      ),
    );
  }
}

