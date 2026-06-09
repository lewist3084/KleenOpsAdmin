// lib/common/communications/email/screens/email_company_files_picker_screen.dart
//
// Multi-select picker over the mailbox company's `company/{cid}/file/`. Mirrors
// the kleenops app's picker (ChangeNotifier selection, ListenableBuilder leaves
// so toggling a file doesn't rebuild the StreamBuilder + StandardView) and
// returns `List<EmailAttachment>` via Navigator.pop.
//
// ADMIN ADAPTATIONS (backend only): the company comes from
// `mailboxCompanyRefProvider` (the company that owns the mailbox being viewed),
// not the overlord's own `companyIdProvider`. The overlord is not a member of
// the tenant company, so the kleenops per-user access filter is dropped — the
// overlord acts as the mailbox owner and sees that company's files. Snackbars
// go through ScaffoldMessenger.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/search/search_control_strip_adapter.dart';
import 'package:kleenops_admin/services/ai/ai_context_service.dart';
import 'package:path/path.dart' as p;
import 'package:shared_widgets/lists/standardView.dart';
import 'package:shared_widgets/tiles/standard_tile_small.dart';
import 'package:shared_widgets/theme/app_palette.dart';

import '../models/email_attachment.dart';
import '../providers/email_providers.dart';

class _FileItem {
  const _FileItem({
    required this.id,
    required this.name,
    required this.sourceFileName,
    required this.downloadUrl,
    required this.storagePath,
    required this.sizeBytes,
  });

  final String id;
  final String name;
  final String? sourceFileName;
  final String downloadUrl;
  final String storagePath;
  final int? sizeBytes;

  String get effectiveFileName {
    final source = sourceFileName?.trim();
    if (source != null && source.isNotEmpty) return source;
    final n = name.trim();
    return n.isNotEmpty ? n : 'file';
  }

  String? get mimeType {
    final ext = p.extension(effectiveFileName).toLowerCase();
    return _mimeFromExtension(ext);
  }

  EmailAttachment toAttachment() {
    final mime = mimeType;
    return EmailAttachment(
      id: id,
      fileName: effectiveFileName,
      mimeType: mime,
      sizeBytes: sizeBytes,
      url: downloadUrl,
      storagePath: storagePath,
      type: EmailAttachment.typeFromMime(mime),
    );
  }
}

String? _mimeFromExtension(String ext) {
  switch (ext) {
    case '.pdf':
      return 'application/pdf';
    case '.png':
      return 'image/png';
    case '.jpg':
    case '.jpeg':
      return 'image/jpeg';
    case '.gif':
      return 'image/gif';
    case '.webp':
      return 'image/webp';
    case '.heic':
      return 'image/heic';
    case '.mp4':
      return 'video/mp4';
    case '.mov':
      return 'video/quicktime';
    case '.mp3':
      return 'audio/mpeg';
    case '.wav':
      return 'audio/wav';
    case '.txt':
      return 'text/plain';
    case '.csv':
      return 'text/csv';
    case '.doc':
      return 'application/msword';
    case '.docx':
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    case '.xls':
      return 'application/vnd.ms-excel';
    case '.xlsx':
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    case '.ppt':
      return 'application/vnd.ms-powerpoint';
    case '.pptx':
      return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    case '.zip':
      return 'application/zip';
    case '.json':
      return 'application/json';
    case '.html':
    case '.htm':
      return 'text/html';
    default:
      return null;
  }
}

class _SelectedFiles extends ChangeNotifier {
  final Map<String, _FileItem> _values = {};

  int get length => _values.length;
  bool get isEmpty => _values.isEmpty;
  bool get isNotEmpty => _values.isNotEmpty;
  bool contains(String id) => _values.containsKey(id);
  List<_FileItem> toList() => _values.values.toList();

  void toggle(_FileItem f) {
    if (_values.containsKey(f.id)) {
      _values.remove(f.id);
    } else {
      _values[f.id] = f;
    }
    notifyListeners();
  }

  void clear() {
    if (_values.isEmpty) return;
    _values.clear();
    notifyListeners();
  }
}

class EmailCompanyFilesPickerScreen extends ConsumerStatefulWidget {
  const EmailCompanyFilesPickerScreen({super.key, this.maxTotalBytes});

  /// Soft cap on total selected size. When exceeded, additional taps
  /// show a snackbar and the file is not added to the selection.
  final int? maxTotalBytes;

  @override
  ConsumerState<EmailCompanyFilesPickerScreen> createState() =>
      _EmailCompanyFilesPickerScreenState();
}

class _EmailCompanyFilesPickerScreenState
    extends ConsumerState<EmailCompanyFilesPickerScreen> {
  final TextEditingController _searchController = TextEditingController();
  final _SelectedFiles _selected = _SelectedFiles();
  String _searchQuery = '';
  bool _searchVisible = false;

  void _toggleSearch() => setState(() => _searchVisible = !_searchVisible);

  @override
  void dispose() {
    _searchController.dispose();
    _selected.dispose();
    super.dispose();
  }

  int get _totalBytes =>
      _selected.toList().fold<int>(0, (acc, f) => acc + (f.sizeBytes ?? 0));

  void _attemptToggle(_FileItem f) {
    final cap = widget.maxTotalBytes;
    if (cap != null && !_selected.contains(f.id)) {
      final additional = f.sizeBytes ?? 0;
      if (_totalBytes + additional > cap) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 5),
            content: Text(
              'Adding "${f.effectiveFileName}" would exceed the '
              '${(cap / (1024 * 1024)).toStringAsFixed(0)} MB attachment cap.',
            ),
          ),
        );
        return;
      }
    }
    _selected.toggle(f);
  }

  @override
  Widget build(BuildContext context) {
    final companyRef = ref.watch(mailboxCompanyRefProvider);
    final controller = ref.read(aiCanvasControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: companyRef == null
            ? const Center(child: Text('No company selected.'))
            : Column(
                children: [
                  if (_searchVisible)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: SearchControlStrip(
                        controller: _searchController,
                        hintText: 'Search files',
                        onChanged: (value) =>
                            setState(() => _searchQuery = value.toLowerCase()),
                      ),
                    ),
                  ListenableBuilder(
                    listenable: _selected,
                    builder: (context, _) => _selected.isEmpty
                        ? const SizedBox.shrink()
                        : _SelectedBar(selection: _selected),
                  ),
                  Expanded(
                    child: _FilesList(
                      companyRef: companyRef,
                      searchQuery: _searchQuery,
                      selection: _selected,
                      onToggle: _attemptToggle,
                    ),
                  ),
                ],
              ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: 'Attach from Files',
            onAiPressed: controller.toggle,
            showSearchToggle: true,
            searchActive: _searchVisible,
            onSearchToggle: _toggleSearch,
          ),
          const HomeNavBarAdapter(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'emailAttachFilesConfirmFab',
        onPressed: () => Navigator.of(context).pop(
          _selected.toList().map((f) => f.toAttachment()).toList(),
        ),
        icon: const Icon(Icons.check),
        label: ListenableBuilder(
          listenable: _selected,
          builder: (_, __) => Text(
            _selected.isEmpty ? 'Done' : 'Done (${_selected.length})',
          ),
        ),
      ),
    );
  }
}

class _SelectedBar extends StatelessWidget {
  const _SelectedBar({required this.selection});

  final _SelectedFiles selection;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: palette.primary2.withValues(alpha: 0.1),
      child: Row(
        children: [
          Icon(Icons.attach_file, size: 20, color: palette.primary2),
          const SizedBox(width: 8),
          Text(
            '${selection.length} selected',
            style: TextStyle(
              color: palette.primary2,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: selection.clear,
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

class _FilesList extends ConsumerWidget {
  const _FilesList({
    required this.companyRef,
    required this.searchQuery,
    required this.selection,
    required this.onToggle,
  });

  final DocumentReference<Map<String, dynamic>> companyRef;
  final String searchQuery;
  final _SelectedFiles selection;
  final ValueChanged<_FileItem> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = companyRef.collection('file').orderBy('name');

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];

        final files = <_FileItem>[];
        for (final doc in docs) {
          final data = doc.data();
          final downloadUrl = (data['downloadUrl'] as String?)?.trim();
          final storagePath = (data['storagePath'] as String?)?.trim();
          if (downloadUrl == null ||
              downloadUrl.isEmpty ||
              storagePath == null ||
              storagePath.isEmpty) {
            continue;
          }
          final name =
              ((data['name'] as String?)?.trim().isNotEmpty ?? false)
                  ? (data['name'] as String).trim()
                  : 'Unnamed file';
          if (searchQuery.isNotEmpty &&
              !name.toLowerCase().contains(searchQuery)) {
            continue;
          }
          files.add(_FileItem(
            id: doc.id,
            name: name,
            sourceFileName: data['sourceFileName'] as String?,
            downloadUrl: downloadUrl,
            storagePath: storagePath,
            sizeBytes:
                (data['sizeBytes'] is int) ? data['sizeBytes'] as int : null,
          ));
        }

        files.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

        if (files.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.folder_open, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  searchQuery.isEmpty
                      ? 'No accessible files'
                      : 'No files matching "$searchQuery"',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        return StandardView<_FileItem>(
          items: files,
          groupBy: (_) => null,
          indentGroupedItems: false,
          shrinkWrap: false,
          physics: const AlwaysScrollableScrollPhysics(),
          showDividersInFlat: true,
          enableReorder: false,
          itemBuilder: (file) => _FileTile(
            file: file,
            selection: selection,
            onToggle: onToggle,
          ),
        );
      },
    );
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile({
    required this.file,
    required this.selection,
    required this.onToggle,
  });

  final _FileItem file;
  final _SelectedFiles selection;
  final ValueChanged<_FileItem> onToggle;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteScope.of(context);
    return ListenableBuilder(
      listenable: selection,
      builder: (context, _) {
        final isSelected = selection.contains(file.id);
        final sizeLabel = file.sizeBytes == null
            ? null
            : _humanReadableSize(file.sizeBytes!);
        return StandardTileSmallDart(
          label: file.name,
          labelStyle: const TextStyle(fontSize: 14, color: Colors.black),
          secondaryText: sizeLabel,
          leadingIcon: Icons.insert_drive_file_outlined,
          leadingIconColor: palette.primary2,
          trailingIcon1:
              isSelected ? Icons.check_box : Icons.check_box_outline_blank,
          trailingIconColor: palette.primary2,
          onTrailing1Tap: () => onToggle(file),
          onTap: () => onToggle(file),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          tileColor: isSelected
              ? palette.primary2.withValues(alpha: 0.05)
              : Colors.white,
        );
      },
    );
  }
}

String _humanReadableSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}
