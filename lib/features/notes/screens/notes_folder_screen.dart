import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/features/notes/data/content_model.dart';
import 'package:kleenops_admin/features/notes/providers/notes_providers.dart';
import 'package:kleenops_admin/services/ai/ai_context_service.dart';
import 'package:kleenops_admin/widgets/layout/bookended_canvas.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:shared_widgets/tabs/lazy_tab_view.dart';
import 'package:shared_widgets/tabs/standard_tab.dart';

class NotesFolderScreen extends ConsumerStatefulWidget {
  const NotesFolderScreen({super.key, required this.folderId});
  final String folderId;

  @override
  ConsumerState<NotesFolderScreen> createState() => _NotesFolderScreenState();
}

class _NotesFolderScreenState extends ConsumerState<NotesFolderScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  DocumentReference<Map<String, dynamic>>? _folderRef(
    DocumentReference<Map<String, dynamic>>? companyRef,
  ) {
    if (companyRef == null) return null;
    return companyRef.collection('folder').doc(widget.folderId);
  }

  @override
  Widget build(BuildContext context) {
    final companyRef = ref.watch(companyIdProvider).value;
    final folderRef = _folderRef(companyRef);
    final aiController = ref.read(aiCanvasControllerProvider);

    return Scaffold(
      body: BookendedCanvas(
        child: folderRef == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _FolderHeader(folderRef: folderRef),
                  Container(
                    color: Colors.white,
                    child: StandardTabBar(
                      controller: _tabController,
                      isScrollable: true,
                      dividerColor: Colors.grey[300],
                      indicatorWeight: 3,
                      labelColor: Colors.black,
                      unselectedLabelColor: Colors.grey[600],
                      tabs: const [
                        Tab(text: 'Folders'),
                        Tab(text: 'Content'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: LazyTabView(
                      controller: _tabController,
                      children: [
                        _ChildFoldersList(parentRef: folderRef),
                        _ContentList(folderRef: folderRef),
                      ],
                    ),
                  ),
                ],
              ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: 'Folder',
            onAiPressed: aiController.toggle,
          ),
          const HomeNavBarAdapter(),
        ],
      ),
      floatingActionButton: _buildFab(companyRef, folderRef),
    );
  }

  Widget? _buildFab(
    DocumentReference<Map<String, dynamic>>? companyRef,
    DocumentReference<Map<String, dynamic>>? folderRef,
  ) {
    if (folderRef == null) return null;

    return FloatingActionButton(
      heroTag: 'notesFolderFab',
      onPressed: () async {
        if (_tabController.index == 0) {
          await _addChildFolder(companyRef!, folderRef);
        } else {
          await _addContent(companyRef!, folderRef);
        }
      },
      tooltip: 'Add',
      child: const Icon(Icons.add),
    );
  }

  Future<void> _addChildFolder(
    DocumentReference<Map<String, dynamic>> companyRef,
    DocumentReference<Map<String, dynamic>> folderRef,
  ) async {
    final name = await _showNameDialog(context, title: 'New Sub-Folder');
    if (name == null || name.trim().isEmpty) return;

    final userData = ref.read(userDocumentProvider).value;
    if (userData == null) return;
    final memberRef =
        userData['memberRef'] as DocumentReference<Map<String, dynamic>>?;
    if (memberRef == null) return;

    final existing = ref.read(childFoldersProvider(folderRef)).value ?? [];

    await companyRef.collection('folder').add({
      'name': name.trim(),
      'parentFolderRef': folderRef,
      'position': existing.length,
      'memberId': memberRef.id,
      'memberRef': memberRef,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _addContent(
    DocumentReference<Map<String, dynamic>> companyRef,
    DocumentReference<Map<String, dynamic>> folderRef,
  ) async {
    final text = await _showNameDialog(context, title: 'New Note');
    if (text == null || text.trim().isEmpty) return;

    final userData = ref.read(userDocumentProvider).value;
    if (userData == null) return;
    final memberRef =
        userData['memberRef'] as DocumentReference<Map<String, dynamic>>?;

    final existing = ref.read(folderContentProvider(folderRef)).value ?? [];

    await companyRef.collection('content').add({
      'folderRef': folderRef,
      'text': text.trim(),
      'position': existing.length + 1,
      'source': 'manual',
      'memberRef': memberRef,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<String?> _showNameDialog(
    BuildContext context, {
    required String title,
  }) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => DialogAction(
        title: title,
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: null,
          decoration: const InputDecoration(hintText: 'Enter text'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
          textInputAction: TextInputAction.newline,
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        ),
        cancelText: 'Cancel',
        onCancel: () => Navigator.pop(ctx),
        actionText: 'Save',
        onAction: () => Navigator.pop(ctx, controller.text),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Header showing folder name
// ──────────────────────────────────────────────────────────────────────────────

class _FolderHeader extends StatefulWidget {
  const _FolderHeader({required this.folderRef});
  final DocumentReference<Map<String, dynamic>> folderRef;

  @override
  State<_FolderHeader> createState() => _FolderHeaderState();
}

class _FolderHeaderState extends State<_FolderHeader> {
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _folderStream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _folderStream ??= widget.folderRef.snapshots(),
      builder: (context, snap) {
        final name = snap.data?.data()?['name'] ?? '';
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          child: Text(
            name,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Child folders tab
// ──────────────────────────────────────────────────────────────────────────────

class _ChildFoldersList extends ConsumerWidget {
  const _ChildFoldersList({required this.parentRef});
  final DocumentReference<Map<String, dynamic>> parentRef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foldersAsync = ref.watch(childFoldersProvider(parentRef));

    return foldersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (folders) {
        if (folders.isEmpty) {
          return const Center(child: Text('No sub-folders.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: folders.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final folder = folders[index];
            return ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(folder.name),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(
                '${AppRoutePaths.drawerNotesFolder}?folderId=${folder.id}',
              ),
            );
          },
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Content docs tab
// ──────────────────────────────────────────────────────────────────────────────

class _ContentList extends ConsumerWidget {
  const _ContentList({required this.folderRef});
  final DocumentReference<Map<String, dynamic>> folderRef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentAsync = ref.watch(folderContentProvider(folderRef));

    return contentAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('No content yet.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final content = items[index];
            return _ContentTile(content: content);
          },
        );
      },
    );
  }
}

class _ContentTile extends StatelessWidget {
  const _ContentTile({required this.content});
  final ContentModel content;

  @override
  Widget build(BuildContext context) {
    final preview = content.text.length > 120
        ? '${content.text.substring(0, 120)}...'
        : content.text;
    final dateStr = content.createdAt != null
        ? DateFormat.yMMMd().format(content.createdAt!)
        : '';

    return ListTile(
      leading: Icon(
        content.source == 'manual'
            ? Icons.note_outlined
            : Icons.mic_outlined,
      ),
      title: Text(
        preview,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Row(
        children: [
          if (content.source != 'manual') ...[
            Chip(
              label: Text(content.sourceBadge,
                  style: const TextStyle(fontSize: 10)),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
            ),
            const SizedBox(width: 8),
          ],
          Text(dateStr, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      onTap: () => context.push(
        '${AppRoutePaths.drawerNotesContent}?contentId=${content.id}',
      ),
    );
  }
}
