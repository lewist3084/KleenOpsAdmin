// The Files drive tree. Each drive, folder and file is a single
// [StandardTileSmallDart] row. Drives and folders carry an expansion arrow on
// the right that drills into their contents inline â€” the same shape as the
// accounting account tree (parent â†’ children, expand/collapse, indent per
// level). Tapping a drive row opens its dedicated browser screen; tapping a
// folder row expands it; tapping a file opens it. The â‹® menu exposes
// rename / move / delete, and "Move" is how an item is re-parented into another
// folder (the file-tree equivalent of making a sub-account of a parent).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kleenops_admin/features/files/data/drive_model.dart';
import 'package:kleenops_admin/features/files/data/file_model.dart';
import 'package:kleenops_admin/features/files/utils/drive_actions.dart';
import 'package:kleenops_admin/features/files/utils/file_kinds.dart';
import 'package:kleenops_admin/repositories/file_repository.dart';
import 'package:shared_widgets/theme/app_palette.dart';
import 'package:shared_widgets/tiles/standard_tile_small.dart';

/// Left indent applied per nesting level, matching the account tree.
const double _kIndentPerLevel = 16.0;

/// A drive row plus its (lazily streamed) contents. Drop one per accessible
/// drive into the dashboard list.
class DriveTreeNode extends ConsumerStatefulWidget {
  const DriveTreeNode({
    super.key,
    required this.companyId,
    required this.drive,
    required this.onOpen,
    this.onMenu,
  });

  final String companyId;
  final DriveModel drive;

  /// Tapping the drive row opens its browser screen.
  final VoidCallback onOpen;

  /// Drive â‹® menu (rename / delete / manage access). Null for system drives.
  final VoidCallback? onMenu;

  @override
  ConsumerState<DriveTreeNode> createState() => _DriveTreeNodeState();
}

class _DriveTreeNodeState extends ConsumerState<DriveTreeNode> {
  bool _expanded = false;

  IconData get _icon {
    if (widget.drive.isCompanyDrive) return Icons.business_rounded;
    switch (widget.drive.type) {
      case DriveType.personal:
        return Icons.person_rounded;
      case DriveType.shared:
        return Icons.group_rounded;
      case DriveType.public:
        return Icons.public_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteScope.of(context);
    final row = StandardTileSmallDart(
      label: widget.drive.name.isEmpty ? 'Untitled drive' : widget.drive.name,
      secondaryText: widget.drive.typeLabel,
      leadingIcon: _icon,
      leadingIconColor: palette.primary2,
      leadingIconSize: 20,
      tileColor: Colors.white,
      onTap: widget.onOpen,
      trailingIcon1: widget.onMenu == null ? null : Icons.more_vert,
      onTrailing1Tap: widget.onMenu,
      trailingIcon2: _expanded ? Icons.expand_less : Icons.expand_more,
      onTrailing2Tap: () => setState(() => _expanded = !_expanded),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row,
        if (_expanded)
          _FolderChildren(
            companyId: widget.companyId,
            drive: widget.drive,
            parentFolderRef: null,
            depth: 1,
          ),
      ],
    );
  }
}

/// A folder or file row inside the tree. Folders expand inline; files are
/// leaves that open on tap.
class _FileTreeNode extends ConsumerStatefulWidget {
  const _FileTreeNode({
    required this.companyId,
    required this.drive,
    required this.item,
    required this.depth,
  });

  final String companyId;
  final DriveModel drive;
  final FileModel item;
  final int depth;

  @override
  ConsumerState<_FileTreeNode> createState() => _FileTreeNodeState();
}

class _FileTreeNodeState extends ConsumerState<_FileTreeNode> {
  bool _expanded = false;

  void _menu() {
    DriveActions.showItemMenu(
      context,
      ref,
      companyId: widget.companyId,
      drive: widget.drive,
      item: widget.item,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteScope.of(context);
    final item = widget.item;
    final isFolder = item.isFolder;
    final kind = fileKindOf(item);

    final String? secondary =
        isFolder ? null : _nonEmpty(formatBytes(item.sizeBytes));

    final row = Padding(
      padding: EdgeInsets.only(left: widget.depth * _kIndentPerLevel),
      child: StandardTileSmallDart(
        label: item.name.isEmpty ? 'Untitled' : item.name,
        secondaryText: secondary,
        leadingIcon: isFolder ? Icons.folder_rounded : iconForKind(kind),
        leadingIconColor:
            isFolder ? palette.primary2 : Colors.grey.shade600,
        leadingIconSize: 20,
        tileColor: Colors.white,
        onTap: isFolder
            ? () => setState(() => _expanded = !_expanded)
            : () => DriveActions.openFile(context, item),
        trailingIcon1: Icons.more_vert,
        onTrailing1Tap: _menu,
        trailingIcon2: isFolder
            ? (_expanded ? Icons.expand_less : Icons.expand_more)
            : null,
        onTrailing2Tap:
            isFolder ? () => setState(() => _expanded = !_expanded) : null,
      ),
    );

    if (!isFolder) return row;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row,
        if (_expanded)
          _FolderChildren(
            companyId: widget.companyId,
            drive: widget.drive,
            parentFolderRef: item.ref,
            depth: widget.depth + 1,
          ),
      ],
    );
  }
}

/// Streams the direct children of [parentFolderRef] (or the drive root when
/// null) and renders each as a tree node. Attached only while its parent row is
/// expanded, so listeners are created lazily as the user drills in.
class _FolderChildren extends ConsumerWidget {
  const _FolderChildren({
    required this.companyId,
    required this.drive,
    required this.parentFolderRef,
    required this.depth,
  });

  final String companyId;
  final DriveModel drive;
  final DocumentReference<Map<String, dynamic>>? parentFolderRef;
  final int depth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(fileRepositoryProvider);
    return StreamBuilder<List<FileModel>>(
      stream: repo.watchFolderContents(
        companyId: companyId,
        driveRef: drive.ref,
        parentFolderRef: parentFolderRef,
      ),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return _hint(context, 'Loadingâ€¦');
        }
        final items = snap.data ?? const <FileModel>[];
        if (items.isEmpty) {
          return _hint(context, 'Empty');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final item in items)
              _FileTreeNode(
                companyId: companyId,
                drive: drive,
                item: item,
                depth: depth,
              ),
          ],
        );
      },
    );
  }

  Widget _hint(BuildContext context, String text) {
    return Padding(
      padding: EdgeInsets.fromLTRB(depth * _kIndentPerLevel + 16, 6, 16, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade500,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

String? _nonEmpty(String v) => v.isEmpty ? null : v;

