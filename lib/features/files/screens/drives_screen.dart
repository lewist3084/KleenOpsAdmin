// Files dashboard â€” the landing screen reached from the menu drawer's Files
// icon. Shows the drives the user can reach as cards (My Drive first, then the
// Company Drive, then shared/public drives, then a "New drive" tile) followed
// by a Recent files list. Search spans every accessible drive; the filter
// narrows by file type. Opening a drive pushes the folder browser.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/search/search_control_strip_adapter.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/features/files/data/drive_model.dart';
import 'package:kleenops_admin/features/files/data/file_model.dart';
import 'package:kleenops_admin/features/files/providers/drive_providers.dart';
import 'package:kleenops_admin/features/files/screens/drive_browser_screen.dart';
import 'package:kleenops_admin/features/files/utils/drive_actions.dart';
import 'package:kleenops_admin/features/files/utils/file_kinds.dart';
import 'package:kleenops_admin/features/files/widgets/drive_access_dialog.dart';
import 'package:kleenops_admin/features/files/widgets/drive_filter_bar.dart';
import 'package:kleenops_admin/features/files/widgets/file_tile.dart';
import 'package:kleenops_admin/features/files/widgets/file_tree_view.dart';
import 'package:kleenops_admin/repositories/file_repository.dart';
import 'package:kleenops_admin/services/ai/ai_context_service.dart';
import 'package:kleenops_admin/widgets/layout/bookended_canvas.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';

class DrivesScreen extends ConsumerStatefulWidget {
  const DrivesScreen({super.key});

  @override
  ConsumerState<DrivesScreen> createState() => _DrivesScreenState();
}

class _DrivesScreenState extends ConsumerState<DrivesScreen> {
  final TextEditingController _searchCtl = TextEditingController();
  bool _searchActive = false;
  bool _filterActive = false;
  String _search = '';
  FileKind? _filter;
  bool _drivesEnsured = false;

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final companyRef = ref.watch(companyIdProvider).maybeWhen(
          data: (v) => v,
          orElse: () => null,
        );
    final userData = ref.watch(userDocumentProvider).maybeWhen(
          data: (d) => d,
          orElse: () => const <String, dynamic>{},
        );
    final controller = ref.read(aiCanvasControllerProvider);

    _maybeEnsureDrives(companyRef, userData);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: BookendedCanvas(
        child: companyRef == null
            ? const Center(child: CircularProgressIndicator())
            : _content(companyRef),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: 'Files',
            onAiPressed: controller.toggle,
            menuSections:
                const MenuDrawerSections(actions: <ContentMenuItem>[]),
            showSearchToggle: true,
            searchActive: _searchActive,
            onSearchToggle: _toggleSearch,
            showFilterToggle: true,
            filterActive: _filterActive,
            onFilterToggle: _toggleFilter,
          ),
          const HomeNavBarAdapter(),
        ],
      ),
    );
  }

  Widget _content(DocumentReference<Map<String, dynamic>> companyRef) {
    final searching = _searchActive && _search.trim().isNotEmpty;
    return Column(
      children: [
        if (_searchActive)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: SearchControlStrip(
              controller: _searchCtl,
              hintText: 'Search all files',
              onChanged: (t) => setState(() => _search = t),
            ),
          ),
        if (_filterActive)
          DriveFilterBar(
            selected: _filter,
            onChanged: (k) => setState(() => _filter = k),
          ),
        Expanded(
          child: searching ? _searchResults() : _dashboard(companyRef),
        ),
      ],
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ Dashboard â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _dashboard(DocumentReference<Map<String, dynamic>> companyRef) {
    final drives = _sortedDrives(ref.watch(accessibleDrivesProvider));
    final recentAsync = ref.watch(recentFilesProvider);
    final controller = ref.read(aiCanvasControllerProvider);

    // Drives section â€” wrapped in a ContainerActionWidget; the bottom "Add"
    // button creates a new drive (replaces the old "New drive" tile/card).
    final drivesContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final d in drives) ...[
          DriveTreeNode(
            companyId: companyRef.id,
            drive: d,
            onOpen: () => _openDrive(d),
            onMenu: d.isSystem ? null : () => _showDriveMenu(companyRef.id, d),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
        ],
      ],
    );

    final children = <Widget>[
      ContainerActionWidget(
        title: 'Drives',
        content: drivesContent,
        isEmpty: drives.isEmpty,
        showEmptyDisclaimer: true,
        emptyDisclaimer: 'No drives yet. Tap Add to create one.',
        actionText: 'Add',
        onAction: () => _createDrive(companyRef.id),
        onAiAction: controller.toggle,
      ),
    ];

    // Manager-only: every other member's personal drive, for offboarding â€”
    // open a departed member's My Drive to review, reassign, or delete files.
    if (ref.watch(isFileManagerProvider)) {
      final accessibleIds = drives.map((d) => d.id).toSet();
      final memberDrives = ref
          .watch(allPersonalDrivesProvider)
          .maybeWhen(data: (v) => v, orElse: () => const <DriveModel>[])
          .where((d) => !accessibleIds.contains(d.id))
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (memberDrives.isNotEmpty) {
        children
          ..add(const SizedBox(height: 12))
          ..add(
            ContainerActionWidget(
              title: 'Member drives',
              actionText: '',
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final d in memberDrives) ...[
                    DriveTreeNode(
                      companyId: companyRef.id,
                      drive: d,
                      onOpen: () => _openDrive(d),
                    ),
                    Divider(height: 1, color: Colors.grey.shade200),
                  ],
                ],
              ),
            ),
          );
      }
    }

    // Recent files â€” its own separate ContainerActionWidget.
    final recent = recentAsync.maybeWhen(
      data: (r) => _applyTypeFilter(r),
      orElse: () => const <FileModel>[],
    );
    if (recent.isNotEmpty) {
      children
        ..add(const SizedBox(height: 12))
        ..add(
          ContainerActionWidget(
            title: 'Recent',
            // Bottom add/AI row suppressed â€” Recent is read-only.
            actionText: '',
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final f in recent.take(12))
                  FileTile(
                    file: f,
                    subtitle: _driveNameOf(f, drives),
                    onTap: () => DriveActions.openFile(context, f),
                    onMenu: () => _openItemMenu(companyRef.id, f, drives),
                  ),
              ],
            ),
          ),
        );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 96),
      children: children,
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ Global search â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _searchResults() {
    final drives = ref.watch(accessibleDrivesProvider);
    final itemsAsync = ref.watch(driveSearchItemsProvider);
    return itemsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _message('Search failed.\n$e'),
      data: (all) {
        final q = _search.trim().toLowerCase();
        final matches = _applyTypeFilter(all)
            .where((f) => f.name.toLowerCase().contains(q))
            .toList()
          ..sort((a, b) {
            if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });
        if (matches.isEmpty) {
          return _message('No files match "${_search.trim()}".');
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
          itemCount: matches.length,
          separatorBuilder: (_, __) =>
              Divider(height: 1, color: Colors.grey.shade200),
          itemBuilder: (context, i) {
            final f = matches[i];
            return FileTile(
              file: f,
              subtitle: _driveNameOf(f, drives),
              onTap: () => _openSearchItem(f, all, drives),
              onMenu: () => _openItemMenu(/*companyId*/ null, f, drives),
            );
          },
        );
      },
    );
  }

  void _openSearchItem(
    FileModel f,
    List<FileModel> all,
    List<DriveModel> drives,
  ) {
    if (!f.isFolder) {
      DriveActions.openFile(context, f);
      return;
    }
    final drive = _driveById(drives, f.driveRef?.id);
    if (drive == null) return;
    final driveItems =
        all.where((x) => x.driveRef?.id == drive.id).toList();
    final byId = {for (final x in driveItems) x.id: x};
    final stack = <FileModel>[];
    for (final id in f.ancestorIds) {
      final m = byId[id];
      if (m != null) stack.add(m);
    }
    stack.add(f);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            DriveBrowserScreen(drive: drive, initialFolderStack: stack),
      ),
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ Drive actions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _openDrive(DriveModel drive) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DriveBrowserScreen(drive: drive),
      ),
    );
  }

  Future<void> _createDrive(String companyId) async {
    final drive =
        await DriveActions.createSharedDrive(context, ref, companyId: companyId);
    if (drive == null || !mounted) return;
    // Jump straight into picking who can access the new drive.
    await showDialog<bool>(
      context: context,
      builder: (_) => DriveAccessDialog(companyId: companyId, drive: drive),
    );
  }

  Future<void> _showDriveMenu(String companyId, DriveModel drive) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (drive.type == DriveType.shared)
              ListTile(
                leading: const Icon(Icons.group_add_outlined),
                title: const Text('Manage access'),
                onTap: () => Navigator.pop(context, 'access'),
              ),
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('Rename drive'),
              onTap: () => Navigator.pop(context, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete drive'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'access') {
      await showDialog<bool>(
        context: context,
        builder: (_) => DriveAccessDialog(companyId: companyId, drive: drive),
      );
    } else if (choice == 'rename') {
      await DriveActions.renameDrive(context, ref, drive);
    } else if (choice == 'delete') {
      await DriveActions.confirmDeleteDrive(
        context,
        ref,
        companyId: companyId,
        drive: drive,
      );
    }
  }

  Future<void> _openItemMenu(
    String? companyId,
    FileModel item,
    List<DriveModel> drives,
  ) async {
    final drive = _driveById(drives, item.driveRef?.id);
    final id = companyId ?? ref.read(companyIdProvider).value?.id;
    if (drive == null || id == null) return;
    await DriveActions.showItemMenu(
      context,
      ref,
      companyId: id,
      drive: drive,
      item: item,
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ Drive bootstrap â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _maybeEnsureDrives(
    DocumentReference<Map<String, dynamic>>? companyRef,
    Map<String, dynamic> userData,
  ) {
    if (_drivesEnsured || companyRef == null || userData.isEmpty) return;
    final memberRef = userData['memberRef'];
    if (memberRef is! DocumentReference) return;
    _drivesEnsured = true;

    final repo = ref.read(fileRepositoryProvider);
    final userRef = ref.read(userDocRefProvider);
    () async {
      try {
        await repo.ensurePersonalDrive(
          companyId: companyRef.id,
          memberId: memberRef.id,
          displayName: _displayName(userData),
          createdBy: userRef,
        );
      } catch (_) {/* personal drive simply won't show â€” non-fatal */}
      try {
        await repo.ensureCompanyDrive(
          companyId: companyRef.id,
          createdBy: userRef,
        );
      } catch (_) {/* company drive simply won't show â€” non-fatal */}
    }();
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  List<DriveModel> _sortedDrives(List<DriveModel> drives) {
    int rank(DriveModel d) {
      if (d.type == DriveType.personal) return 0;
      if (d.isCompanyDrive) return 1;
      if (d.type == DriveType.shared) return 2;
      return 3;
    }

    final copy = [...drives];
    copy.sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      if (r != 0) return r;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return copy;
  }

  List<FileModel> _applyTypeFilter(List<FileModel> items) {
    if (_filter == null) return items;
    return items.where((f) => fileKindOf(f) == _filter).toList();
  }

  DriveModel? _driveById(List<DriveModel> drives, String? id) {
    if (id == null) return null;
    for (final d in drives) {
      if (d.id == id) return d;
    }
    return null;
  }

  String? _driveNameOf(FileModel f, List<DriveModel> drives) {
    final d = _driveById(drives, f.driveRef?.id);
    return d?.name;
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

  static String _displayName(Map<String, dynamic> userData) {
    final first = (userData['firstName'] as String?)?.trim() ?? '';
    if (first.isNotEmpty) return first;
    final name = (userData['name'] as String?)?.trim() ?? '';
    if (name.isNotEmpty) return name;
    final email = (userData['email'] as String?)?.trim() ?? '';
    if (email.contains('@')) return email.split('@').first;
    return 'My';
  }
}

