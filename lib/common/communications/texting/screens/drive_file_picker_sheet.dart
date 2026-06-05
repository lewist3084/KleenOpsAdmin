// Modal bottom sheet that lets the text composer pick an existing file from
// any drive the current member can access. Flat searchable list of files
// (folders excluded) sorted newest-first â€” folder navigation is intentionally
// omitted; users find files by name.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kleenops_admin/features/files/data/file_model.dart';
import 'package:kleenops_admin/features/files/providers/drive_providers.dart';
import 'package:kleenops_admin/features/files/widgets/file_tile.dart';

/// Show a modal sheet, returning the picked file (or null if cancelled).
Future<FileModel?> showDriveFilePickerSheet(BuildContext context) {
  return showModalBottomSheet<FileModel>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const _DriveFilePickerSheet(),
  );
}

class _DriveFilePickerSheet extends ConsumerStatefulWidget {
  const _DriveFilePickerSheet();

  @override
  ConsumerState<_DriveFilePickerSheet> createState() =>
      _DriveFilePickerSheetState();
}

class _DriveFilePickerSheetState extends ConsumerState<_DriveFilePickerSheet> {
  final TextEditingController _searchCtl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(driveItemsProvider);
    final drives = ref.watch(accessibleDrivesProvider);
    final driveNameById = {for (final d in drives) d.id: d.name};

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Attach from your files',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _searchCtl,
                autofocus: false,
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  hintText: 'Search files',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: (t) => setState(() => _query = t),
              ),
            ),
            Expanded(
              child: itemsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _message('Could not load files.\n$e'),
                data: (all) => _list(all, driveNameById),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(List<FileModel> all, Map<String, String> driveNameById) {
    final q = _query.trim().toLowerCase();
    final files = all
        .where((f) => !f.isFolder && (f.downloadUrl?.isNotEmpty ?? false))
        .where((f) => q.isEmpty || f.name.toLowerCase().contains(q))
        .toList()
      ..sort((a, b) {
        final at = a.createdAt;
        final bt = b.createdAt;
        if (at == null && bt == null) return 0;
        if (at == null) return 1;
        if (bt == null) return -1;
        return bt.compareTo(at);
      });
    if (files.isEmpty) {
      return _message(
        q.isEmpty
            ? 'You donâ€™t have any files yet.'
            : 'No files match "$q".',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
      itemCount: files.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: Colors.grey.shade200),
      itemBuilder: (context, i) {
        final f = files[i];
        return FileTile(
          file: f,
          subtitle: driveNameById[f.driveRef?.id],
          onTap: () => Navigator.of(context).pop(f),
        );
      },
    );
  }

  Widget _message(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600, height: 1.4),
        ),
      ),
    );
  }
}

