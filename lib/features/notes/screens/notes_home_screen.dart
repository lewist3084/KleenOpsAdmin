import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/features/notes/data/folder_model.dart';
import 'package:kleenops_admin/features/notes/providers/notes_providers.dart';
import 'package:kleenops_admin/services/ai/ai_context_service.dart';
import 'package:kleenops_admin/widgets/layout/bookended_canvas.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';

class NotesHomeScreen extends ConsumerWidget {
  const NotesHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(aiCanvasControllerProvider);

    return Scaffold(
      body: const BookendedCanvas(child: _FolderList()),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: 'Notes',
            onAiPressed: controller.toggle,
          ),
          const HomeNavBarAdapter(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'notesAddFolderFab',
        onPressed: () => _addFolder(context, ref),
        tooltip: 'New Folder',
        child: const Icon(Icons.create_new_folder_outlined),
      ),
    );
  }

  Future<void> _addFolder(BuildContext context, WidgetRef ref) async {
    final name = await _showNameDialog(context, title: 'New Folder');
    if (name == null || name.trim().isEmpty) return;

    final companyRef = ref.read(companyIdProvider).value;
    final userData = ref.read(userDocumentProvider).value;
    if (companyRef == null || userData == null) return;

    final memberRef =
        userData['memberRef'] as DocumentReference<Map<String, dynamic>>?;
    if (memberRef == null) return;

    final existing = ref.read(topLevelFoldersProvider).value ?? [];

    await companyRef.collection('folder').add({
      'name': name.trim(),
      'parentFolderRef': null,
      'position': existing.length,
      'memberId': memberRef.id,
      'memberRef': memberRef,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<String?> _showNameDialog(
    BuildContext context, {
    required String title,
    String initialValue = '',
  }) {
    final controller = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (ctx) => DialogAction(
        title: title,
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Name'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
          textInputAction: TextInputAction.done,
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        ),
        cancelText: 'Cancel',
        onCancel: () => Navigator.pop(ctx),
        actionText: 'Create',
        onAction: () => Navigator.pop(ctx, controller.text),
      ),
    );
  }
}

class _FolderList extends ConsumerWidget {
  const _FolderList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foldersAsync = ref.watch(topLevelFoldersProvider);

    return foldersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (folders) {
        if (folders.isEmpty) {
          return const Center(
            child: Text('No folders yet. Tap + to create one.'),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: folders.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final folder = folders[index];
            return _FolderTile(folder: folder);
          },
        );
      },
    );
  }
}

class _FolderTile extends StatelessWidget {
  const _FolderTile({required this.folder});
  final FolderModel folder;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.folder_outlined),
      title: Text(folder.name),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(
        '${AppRoutePaths.drawerNotesFolder}?folderId=${folder.id}',
      ),
    );
  }
}
