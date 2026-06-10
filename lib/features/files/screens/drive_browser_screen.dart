// Folder browser for a single drive. Pushed from the Files dashboard once a
// drive (or a search result) is opened. Folder navigation is in-place: tapping
// a folder pushes onto a breadcrumb stack; the system back button and the
// breadcrumb both walk back out before the screen itself pops.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/search/search_control_strip_adapter.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/features/files/data/drive_model.dart';
import 'package:kleenops_admin/features/files/data/file_model.dart';
import 'package:kleenops_admin/features/files/providers/drive_providers.dart';
import 'package:kleenops_admin/features/files/utils/drive_actions.dart';
import 'package:kleenops_admin/features/files/utils/file_kinds.dart';
import 'package:kleenops_admin/features/files/widgets/drive_filter_bar.dart';
import 'package:kleenops_admin/features/files/widgets/file_tile.dart';
import 'package:kleenops_admin/repositories/file_repository.dart';
import 'package:kleenops_admin/services/ai/ai_context_service.dart';
import 'package:kleenops_admin/widgets/layout/bookended_canvas.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/containers/container_header.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:shared_widgets/lists/standardViewGroup.dart';

class DriveBrowserScreen extends ConsumerStatefulWidget {
  const DriveBrowserScreen({
    super.key,
    required this.drive,
    this.initialFolderStack = const [],
  });

  final DriveModel drive;

  /// Pre-seeds the breadcrumb so the browser can open directly inside a folder
  /// (used when a search result is tapped).
  final List<FileModel> initialFolderStack;

  @override
  ConsumerState<DriveBrowserScreen> createState() => _DriveBrowserScreenState();
}

class _DriveBrowserScreenState extends ConsumerState<DriveBrowserScreen> {
  late List<FileModel> _folderStack;
  // Local, mutable copy of the drive so an in-place name/description edit
  // (via the FAB) updates the header without re-reading the doc.
  late DriveModel _drive;
  final TextEditingController _searchCtl = TextEditingController();
  bool _searchActive = false;
  bool _filterActive = false;
  bool _trashActive = false;
  // True while OS files are being dragged over the listing — drives the
  // drop-zone highlight.
  bool _dragging = false;
  String _search = '';
  FileKind? _filter;

  @override
  void initState() {
    super.initState();
    _drive = _drive;
    _folderStack = List<FileModel>.of(widget.initialFolderStack);
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  DocumentReference<Map<String, dynamic>>? get _currentFolderRef =>
      _folderStack.isEmpty ? null : _folderStack.last.ref;

  /// Ancestor ids of the current folder â€” i.e. the stack minus its last entry.
  List<String> get _parentAncestorIds => _folderStack.length <= 1
      ? const []
      : _folderStack
          .sublist(0, _folderStack.length - 1)
          .map((f) => f.id)
          .toList();

  @override
  Widget build(BuildContext context) {
    final companyRef = ref.watch(companyIdProvider).maybeWhen(
          data: (v) => v,
          orElse: () => null,
        );
    final controller = ref.read(aiCanvasControllerProvider);

    return PopScope(
      canPop: _folderStack.isEmpty && !(_searchActive && _search.isNotEmpty),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        setState(() {
          if (_searchActive && _search.isNotEmpty) {
            _search = '';
            _searchCtl.clear();
            _searchActive = false;
          } else if (_folderStack.isNotEmpty) {
            _folderStack.removeLast();
          }
        });
      },
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        body: BookendedCanvas(
          child: companyRef == null
              ? const Center(child: CircularProgressIndicator())
              : _content(companyRef),
        ),
        // No add FAB while viewing the Trash.
        // The FAB edits the drive's name + description. Adding files/folders is
        // on the "Add" link inside the listing (or drag-and-drop). Hidden in
        // the Trash view.
        floatingActionButton: companyRef == null || _trashActive
            ? null
            : FloatingActionButton(
                heroTag: 'driveBrowserFab',
                tooltip: 'Edit drive',
                onPressed: _editDrive,
                child: const Icon(Icons.edit_outlined),
              ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DetailsAppBar(
              title: _trashActive ? '${_drive.name} Â· Trash' : _drive.name,
              onAiPressed: controller.toggle,
              menuSections: MenuDrawerSections(
                actions: [
                  ContentMenuItem(
                    icon: _trashActive
                        ? Icons.folder_outlined
                        : Icons.delete_outline,
                    label: _trashActive ? 'Back to files' : 'Trash',
                    onTap: () => setState(() => _trashActive = !_trashActive),
                  ),
                ],
              ),
              showSearchToggle: !_trashActive,
              searchActive: _searchActive,
              onSearchToggle: _toggleSearch,
              showFilterToggle: !_trashActive,
              filterActive: _filterActive,
              onFilterToggle: _toggleFilter,
            ),
            const HomeNavBarAdapter(),
          ],
        ),
      ),
    );
  }

  Widget _content(DocumentReference<Map<String, dynamic>> companyRef) {
    final searching = !_trashActive && _searchActive && _search.trim().isNotEmpty;
    final controller = ref.read(aiCanvasControllerProvider);
    return Column(
      children: [
        // Breadcrumb only appears once you've drilled past the drive root; at
        // the root the ContainerHeader already names the drive.
        if (!_trashActive && _folderStack.isNotEmpty) _breadcrumb(),
        if (!_trashActive && _searchActive)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: SearchControlStrip(
              controller: _searchCtl,
              hintText: 'Search ${_drive.name}',
              onChanged: (t) => setState(() => _search = t),
            ),
          ),
        if (!_trashActive && _filterActive)
          DriveFilterBar(
            selected: _filter,
            onChanged: (k) => setState(() => _filter = k),
          ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 96),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ContainerHeader(
                  showImage: false,
                  hideWhenLandscape: false,
                  titleHeader: _trashActive ? 'Trash' : 'Name',
                  title: _drive.name,
                  descriptionHeader: 'Description',
                  description: _trashActive
                      ? 'Deleted items in ${_drive.name}. Restore the ones '
                          'you need; delete the rest forever.'
                      : _drive.descriptionOrDefault,
                  textIcon: _trashActive ? Icons.delete_outline : _driveIcon,
                ),
                // The whole listing is a drop zone: dragging files from the OS
                // onto it uploads them into the current folder. Adding is also
                // available via the "Add" link below the list. Both are off in
                // the Trash view.
                _dropZone(
                  companyRef,
                  child: ContainerActionWidget(
                    actionText: _trashActive ? '' : 'Add',
                    onAction:
                        _trashActive ? null : () => _showAddSheet(companyRef.id),
                    onAiAction: _trashActive ? null : controller.toggle,
                    content: _trashActive
                        ? _trashListing(companyRef)
                        : searching
                            ? _searchResults(companyRef)
                            : _folderListing(companyRef),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Trash view â€” soft-deleted items with Restore / Delete-forever on tap.
  Widget _trashListing(DocumentReference<Map<String, dynamic>> companyRef) {
    final repo = ref.read(fileRepositoryProvider);
    return StreamBuilder<List<FileModel>>(
      stream: repo.watchTrashedItems(
        companyId: companyRef.id,
        driveRef: _drive.ref,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _inlineMessage('Could not load Trash.\n${snapshot.error}');
        }
        if (!snapshot.hasData) return _inlineLoading();
        final items = snapshot.data!;
        if (items.isEmpty) {
          return _inlineMessage('Trash is empty.');
        }
        return StandardViewGroup.buildViewFromItems<FileModel>(
          items: items,
          groupBy: (_) => null,
          disableGrouping: true,
          enableReorder: false,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (item) => FileTile(
            file: item,
            onTap: () =>
                DriveActions.showTrashItemMenu(context, ref, item: item),
            onMenu: () =>
                DriveActions.showTrashItemMenu(context, ref, item: item),
          ),
        );
      },
    );
  }

  IconData get _driveIcon {
    if (_drive.isCompanyDrive) return Icons.business_rounded;
    switch (_drive.type) {
      case DriveType.personal:
        return Icons.person_rounded;
      case DriveType.shared:
        return Icons.group_rounded;
      case DriveType.public:
        return Icons.public_rounded;
    }
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ Breadcrumb â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _breadcrumb() {
    final crumbs = <String>[
      _drive.name,
      ..._folderStack.map((f) => f.name),
    ];
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            for (int i = 0; i < crumbs.length; i++) ...[
              if (i > 0)
                Icon(Icons.chevron_right,
                    size: 16, color: Colors.grey.shade400),
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: i == crumbs.length - 1 ? null : () => _jumpToCrumb(i),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  child: Row(
                    children: [
                      if (i == 0) ...[
                        Icon(Icons.home_outlined,
                            size: 15, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        crumbs[i],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: i == crumbs.length - 1
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: i == crumbs.length - 1
                              ? Colors.black87
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _jumpToCrumb(int index) {
    setState(() {
      if (index == 0) {
        _folderStack.clear();
      } else {
        _folderStack = _folderStack.sublist(0, index);
      }
    });
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ Folder listing â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _folderListing(DocumentReference<Map<String, dynamic>> companyRef) {
    final repo = ref.read(fileRepositoryProvider);
    return StreamBuilder<List<FileModel>>(
      stream: repo.watchFolderContents(
        companyId: companyRef.id,
        driveRef: _drive.ref,
        parentFolderRef: _currentFolderRef,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _inlineMessage('Could not load files.\n${snapshot.error}');
        }
        if (!snapshot.hasData) return _inlineLoading();
        final items = _applyTypeFilter(snapshot.data!);
        if (items.isEmpty) {
          return _inlineMessage(
            _filter == null
                ? 'This folder is empty.\nDrag files here, or tap Add below.'
                : 'Nothing here matches that filter.',
          );
        }
        return _flatList(
          items,
          companyId: companyRef.id,
          onFolderTap: (item) => setState(() => _folderStack.add(item)),
        );
      },
    );
  }

  /// Shared flat (non-scrolling) list of files/folders rendered through
  /// [StandardViewGroup] so it carries the universal list look while nesting
  /// inside the scroll view + ContainerActionWidget.
  Widget _flatList(
    List<FileModel> items, {
    required String companyId,
    required void Function(FileModel folder) onFolderTap,
  }) {
    return StandardViewGroup.buildViewFromItems<FileModel>(
      items: items,
      groupBy: (_) => null,
      disableGrouping: true,
      enableReorder: false,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (item) => FileTile(
        file: item,
        onTap: () {
          if (item.isFolder) {
            onFolderTap(item);
          } else {
            DriveActions.openFile(context, item);
          }
        },
        onMenu: () => DriveActions.showItemMenu(
          context,
          ref,
          companyId: companyId,
          drive: _drive,
          item: item,
        ),
      ),
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ Drive-wide search â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _searchResults(DocumentReference<Map<String, dynamic>> companyRef) {
    final itemsAsync = ref.watch(driveSearchItemsProvider);
    return itemsAsync.when(
      loading: () => _inlineLoading(),
      error: (e, _) => _inlineMessage('Search failed.\n$e'),
      data: (all) {
        final q = _search.trim().toLowerCase();
        final driveItems =
            all.where((f) => f.driveRef?.id == _drive.id).toList();
        final matches = _applyTypeFilter(driveItems)
            .where((f) => f.name.toLowerCase().contains(q))
            .toList()
          ..sort((a, b) {
            if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });
        if (matches.isEmpty) {
          return _inlineMessage('No items match "${_search.trim()}".');
        }
        return _flatList(
          matches,
          companyId: companyRef.id,
          onFolderTap: (item) => setState(() {
            _folderStack = _resolveStack(item, driveItems);
            _search = '';
            _searchCtl.clear();
            _searchActive = false;
          }),
        );
      },
    );
  }

  /// Rebuilds the breadcrumb stack for [folder] from its `ancestorIds`.
  List<FileModel> _resolveStack(
    FileModel folder,
    List<FileModel> driveItems,
  ) {
    final byId = {for (final f in driveItems) f.id: f};
    final stack = <FileModel>[];
    for (final id in folder.ancestorIds) {
      final m = byId[id];
      if (m != null) stack.add(m);
    }
    stack.add(folder);
    return stack;
  }

  List<FileModel> _applyTypeFilter(List<FileModel> items) {
    if (_filter == null) return items;
    return items.where((f) => fileKindOf(f) == _filter).toList();
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ Add sheet â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _showAddSheet(String companyId) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('New folder'),
              onTap: () => Navigator.pop(context, 'folder'),
            ),
            ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: const Text('Upload file'),
              onTap: () => Navigator.pop(context, 'file'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'folder') {
      await DriveActions.createFolder(
        context,
        ref,
        companyId: companyId,
        drive: _drive,
        parentFolderRef: _currentFolderRef,
        parentAncestorIds: _parentAncestorIds,
      );
    } else if (choice == 'file') {
      await DriveActions.uploadFile(
        context,
        ref,
        companyId: companyId,
        drive: _drive,
        parentFolderRef: _currentFolderRef,
        parentAncestorIds: _parentAncestorIds,
      );
    }
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ Toggles + helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  // ─────────────── Edit drive (FAB) ───────────────

  Future<void> _editDrive() async {
    final updated = await DriveActions.editDrive(context, ref, _drive);
    if (updated != null && mounted) {
      setState(() => _drive = updated);
    }
  }

  // ─────────────── Drag-and-drop drop zone ───────────────

  /// Wraps the listing so OS files dragged onto it upload into the current
  /// folder. Shows a highlighted border + hint while a drag hovers. Disabled
  /// in the Trash view.
  Widget _dropZone(
    DocumentReference<Map<String, dynamic>> companyRef, {
    required Widget child,
  }) {
    final accent = Theme.of(context).colorScheme.primary;
    return DropTarget(
      enable: !_trashActive,
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (detail) async {
        setState(() => _dragging = false);
        await DriveActions.uploadDroppedFiles(
          context,
          ref,
          companyId: companyRef.id,
          drive: _drive,
          files: detail.files,
          parentFolderRef: _currentFolderRef,
          parentAncestorIds: _parentAncestorIds,
        );
      },
      child: Stack(
        children: [
          child,
          if (_dragging)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.06),
                    border: Border.all(color: accent, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.file_download_outlined, color: accent),
                      const SizedBox(width: 8),
                      Text(
                        'Drop files to upload',
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _toggleSearch() {
    setState(() {
      _searchActive = !_searchActive;
      if (!_searchActive) {
        _search = '';
        _searchCtl.clear();
      }
    });
  }

  void _toggleFilter() {
    setState(() {
      _filterActive = !_filterActive;
      if (!_filterActive) _filter = null;
    });
  }

  /// Bounded-height empty / error message. Plain Padding + centered Text (no
  /// unbounded [Center]) so it lays out safely inside the scroll view's Column.
  Widget _inlineMessage(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey.shade600, height: 1.4),
      ),
    );
  }

  /// Bounded-height loading indicator for use inside the scroll view.
  Widget _inlineLoading() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Center(
        heightFactor: 1,
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

