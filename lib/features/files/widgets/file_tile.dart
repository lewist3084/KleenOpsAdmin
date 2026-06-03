// A single row in a folder listing, a Recent list, or search results.
// Folders read as accent-coloured (they navigate); files read as neutral.

import 'package:flutter/material.dart';
import 'package:shared_widgets/theme/app_palette.dart';
import 'package:shared_widgets/tiles/standard_tile_small.dart';

import 'package:kleenops_admin/features/files/data/file_model.dart';
import 'package:kleenops_admin/features/files/utils/file_kinds.dart';

class FileTile extends StatelessWidget {
  const FileTile({
    super.key,
    required this.file,
    required this.onTap,
    this.onMenu,
    this.subtitle,
  });

  final FileModel file;
  final VoidCallback onTap;
  final VoidCallback? onMenu;

  /// Overrides the default secondary line (file size). Used by search results
  /// to show the containing drive instead.
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteScope.of(context);
    final kind = fileKindOf(file);

    final String? second = subtitle ??
        (file.isFolder ? null : _nonEmpty(formatBytes(file.sizeBytes)));

    return StandardTileSmallDart.iconText(
      leadingicon: iconForKind(kind),
      leadingiconColor:
          file.isFolder ? palette.primary2 : Colors.grey.shade600,
      text: file.name.isEmpty ? 'Untitled' : file.name,
      secondText: second,
      onTap: onTap,
      trailingIcon1: onMenu == null ? null : Icons.more_vert,
      trailingAction1: onMenu,
    );
  }

  static String? _nonEmpty(String v) => v.isEmpty ? null : v;
}

