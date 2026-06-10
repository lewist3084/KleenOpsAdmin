// lib/features/directory/screens/directory_entity_detail_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:shared_widgets/containers/container_header.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:shared_widgets/tabs/lazy_tab_view.dart';
import 'package:shared_widgets/tabs/standard_tab.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';

import '../models/organization.dart';
import '../../../common/communications/email/screens/email_detail_screen.dart';
import '../../../common/communications/texting/screens/text_conversation_detail_screen.dart';
import '../../../common/communications/timeline/models/timeline_item.dart';
import '../../../common/communications/timeline/providers/timeline_providers.dart';
import '../../../common/communications/timeline/widgets/timeline_list_view.dart';
import '../providers/directory_providers.dart';

/// Detail for an external organization or contact: Communication timeline
/// (email threads) + Notes. [entityKind] is 'organization' or 'contact'.
class DirectoryEntityDetailScreen extends ConsumerWidget {
  const DirectoryEntityDetailScreen({
    super.key,
    required this.entityKind,
    required this.entityId,
  });

  final String entityKind;
  final String entityId;

  bool get _isOrg => entityKind == 'organization';
  String get _collection => _isOrg ? 'organization' : 'externalContact';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final String name;
    final String description;
    final List<Widget> headerExtras = [];
    Organization? org;
    if (_isOrg) {
      org = ref.watch(organizationByIdProvider(entityId)).value;
      name = org?.name ?? 'Organization';
      // Prefer the editable description; otherwise show a public identifier.
      description = (org?.description?.trim().isNotEmpty == true)
          ? org!.description!.trim()
          : (org?.websites.isNotEmpty == true
              ? org!.websites.first
              : (org?.domains.join(', ') ?? ''));
    } else {
      final c = ref.watch(externalContactByIdProvider(entityId)).value;
      name = c?.name ?? 'Contact';
      description = c?.emails.join(', ') ?? '';
      if (c?.organizationId != null) {
        headerExtras.add(Padding(
          padding: const EdgeInsets.only(top: 4),
          child: _OrgChip(orgId: c!.organizationId!),
        ));
      }
      if (c?.ref != null) {
        final shared = c!.shared;
        headerExtras.add(Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            icon: Icon(shared ? Icons.public : Icons.lock_outline,
                size: 18,
                color: shared ? theme.colorScheme.primary : Colors.grey),
            label: Text(shared ? 'Shared with company' : 'Private to you'),
            onPressed: () =>
                ref.read(directoryServiceProvider).setShared(c.ref!, !shared),
          ),
        ));
      }
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      floatingActionButton: (_isOrg && org != null)
          ? FloatingActionButton(
              onPressed: () => _editOrg(context, ref, org!),
              tooltip: 'Edit company',
              child: const Icon(Icons.edit),
            )
          : null,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(title: name),
          const HomeNavBarAdapter(),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ContainerHeader(
              showImage: false,
              titleHeader: _isOrg ? 'Company' : 'Contact',
              title: name,
              descriptionHeader: description.isEmpty ? '' : 'About',
              description: description,
              trailingChildren: headerExtras.isEmpty ? null : headerExtras,
            ),
            Expanded(
              child: DefaultTabController(
                length: _isOrg ? 3 : 2,
                child: Column(
                  children: [
                    StandardTabBar(
                      tabs: [
                        const Tab(text: 'Communication'),
                        if (_isOrg) const Tab(text: 'People'),
                        const Tab(text: 'Notes'),
                      ],
                    ),
                    Expanded(
                      child: Builder(
                        builder: (context) => LazyTabView(
                          controller: DefaultTabController.of(context),
                          children: [
                            _CommunicationTab(
                                entityKind: entityKind, entityId: entityId),
                            if (_isOrg) _OrgPeopleTab(orgId: entityId),
                            _NotesTab(collection: _collection, id: entityId),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Edit FAB action: a focused name + description editor written straight to
  /// the top-level organization doc.
  Future<void> _editOrg(
      BuildContext context, WidgetRef ref, Organization org) async {
    final nameCtrl = TextEditingController(text: org.name);
    final descCtrl = TextEditingController(text: org.description ?? '');
    final messenger = ScaffoldMessenger.of(context);
    final saved = await showDialog<bool>(
      context: context,
      builder: (c) => DialogAction(
        title: 'Edit company',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                  labelText: 'Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'What is this company?',
                  border: OutlineInputBorder()),
            ),
          ],
        ),
        cancelText: 'Cancel',
        onCancel: () => Navigator.pop(c, false),
        actionText: 'Save',
        onAction: () => Navigator.pop(c, true),
      ),
    );
    if (saved != true) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty || org.ref == null) return;
    await org.ref!.set({
      'name': name,
      'nameLower': name.toLowerCase(),
      'description': descCtrl.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (!context.mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('Company updated.')),
    );
  }
}

/// Unified communications feed for a directory entity (organization /
/// external contact / vendor): emails, texts, and calls tagged with the
/// entity, rendered in the same node-rail style as the member and task tabs.
class _CommunicationTab extends ConsumerWidget {
  const _CommunicationTab({required this.entityKind, required this.entityId});

  final String entityKind;
  final String entityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyRef = ref.watch(companyIdProvider).value;
    if (companyRef == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final async = ref.watch(directoryEntityCommunicationsProvider((
      companyId: companyRef.id,
      kind: entityKind,
      entityId: entityId,
    )));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Unable to load communications: $e'),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.forum_outlined,
                    size: 56, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text('No communications yet',
                    style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          );
        }
        return TimelineListView(
          items: items,
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 24),
          onItemTap: (item) => _openItem(context, item),
        );
      },
    );
  }

  Future<void> _openItem(BuildContext context, TimelineItem item) async {
    final ref = item.sourceRef;
    if (ref == null) return;
    if (item.kind == TimelineItemKind.textMessage) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TextConversationDetailScreen(conversationRef: ref),
        ),
      );
      return;
    }
    if (item.kind == TimelineItemKind.email) {
      // Admin's email viewer resolves the message by id from the member's
      // `email` collection (where the directory feed's email items live).
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EmailDetailScreen(emailId: ref.id),
        ),
      );
    }
    // Call summaries have no dedicated detail screen — read-only on the feed.
  }
}

/// Tappable organization chip on a contact's header → opens the org.
class _OrgChip extends ConsumerWidget {
  const _OrgChip({required this.orgId});
  final String orgId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final org = ref.watch(organizationByIdProvider(orgId)).value;
    if (org == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => DirectoryEntityDetailScreen(
            entityKind: 'organization', entityId: orgId),
      )),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.business, size: 12, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            Text(org.name,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary)),
          ],
        ),
      ),
    );
  }
}

/// People linked to an organization (its external contacts).
class _OrgPeopleTab extends ConsumerWidget {
  const _OrgPeopleTab({required this.orgId});
  final String orgId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(contactsForOrgProvider(orgId));
    if (contacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('No people linked yet',
                style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: contacts.length,
      itemBuilder: (context, i) {
        final c = contacts[i];
        final theme = Theme.of(context);
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.teal.withValues(alpha: 0.15),
            child: const Icon(Icons.person_outline,
                color: Colors.teal, size: 20),
          ),
          title: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: c.emails.isEmpty
              ? null
              : Text(c.emails.first,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: c.isSuggested
              ? Text('Suggested',
                  style: TextStyle(
                      fontSize: 11, color: theme.colorScheme.primary))
              : const Icon(Icons.chevron_right, color: Colors.grey),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => DirectoryEntityDetailScreen(
                entityKind: 'contact', entityId: c.id),
          )),
        );
      },
    );
  }
}

class _NotesTab extends ConsumerStatefulWidget {
  const _NotesTab({required this.collection, required this.id});

  final String collection;
  final String id;

  @override
  ConsumerState<_NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends ConsumerState<_NotesTab> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _addNote() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final companyRef = ref.read(companyIdProvider).value;
    if (companyRef == null) return;
    setState(() => _saving = true);
    try {
      final userData = await ref.read(userDocumentProvider.future);
      final uid = ref.read(authStateChangesProvider).value?.uid ?? '';
      final byName = (userData['name'] as String?)?.trim().isNotEmpty == true
          ? (userData['name'] as String).trim()
          : (userData['displayName'] as String?)?.trim() ?? 'Someone';
      // Orgs live in the top-level registry; contacts stay company-scoped.
      final entityRef = widget.collection == 'organization'
          ? companyRef.firestore.collection('organization').doc(widget.id)
          : companyRef.collection(widget.collection).doc(widget.id);
      await ref
          .read(directoryServiceProvider)
          .addNote(entityRef, text: text, byUid: uid, byName: byName);
      _controller.clear();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notesAsync = ref.watch(
      entityNotesProvider((collection: widget.collection, id: widget.id)),
    );

    return Column(
      children: [
        Expanded(
          child: notesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (notes) {
              if (notes.isEmpty) {
                return Center(
                  child: Text('No notes yet',
                      style: TextStyle(color: Colors.grey.shade600)),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: notes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final n = notes[i];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(n.text),
                        const SizedBox(height: 6),
                        Text(
                          '${n.byName} · ${DateFormat.yMMMd().add_jm().format(n.timestamp)}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Add a note…',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send),
                  onPressed: _saving ? null : _addNote,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
