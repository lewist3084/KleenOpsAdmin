import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/features/notes/data/content_model.dart';
import 'package:kleenops_admin/services/ai/ai_context_service.dart';
import 'package:shared_widgets/theme/app_palette.dart';

class NotesContentDetailScreen extends ConsumerStatefulWidget {
  const NotesContentDetailScreen({super.key, required this.contentId});
  final String contentId;

  @override
  ConsumerState<NotesContentDetailScreen> createState() =>
      _NotesContentDetailScreenState();
}

class _NotesContentDetailScreenState
    extends ConsumerState<NotesContentDetailScreen> {
  late TextEditingController _textController;
  bool _editing = false;
  ContentModel? _content;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  DocumentReference<Map<String, dynamic>>? _contentRef() {
    final companyRef = ref.read(companyIdProvider).value;
    if (companyRef == null) return null;
    return companyRef.collection('content').doc(widget.contentId);
  }

  @override
  Widget build(BuildContext context) {
    final companyRef = ref.watch(companyIdProvider).value;
    final aiController = ref.read(aiCanvasControllerProvider);

    final contentRef = companyRef?.collection('content').doc(widget.contentId);

    return Scaffold(
      body: SafeArea(
        child: contentRef == null
            ? const Center(child: CircularProgressIndicator())
            : _ContentBody(
                contentRef: contentRef,
                editing: _editing,
                textController: _textController,
                onContentLoaded: (c) => _content = c,
              ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: 'Content',
            onAiPressed: aiController.toggle,
          ),
          const HomeNavBarAdapter(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'notesContentEditFab',
        onPressed: () => _toggleEdit(),
        tooltip: _editing ? 'Save' : 'Edit',
        child: Icon(_editing ? Icons.check : Icons.edit),
      ),
    );
  }

  Future<void> _toggleEdit() async {
    if (_editing) {
      // Save
      final ref = _contentRef();
      if (ref != null) {
        await ref.update({'text': _textController.text});
      }
      setState(() => _editing = false);
    } else {
      if (_content != null) {
        _textController.text = _content!.text;
      }
      setState(() => _editing = true);
    }
  }
}

class _ContentBody extends StatelessWidget {
  const _ContentBody({
    required this.contentRef,
    required this.editing,
    required this.textController,
    required this.onContentLoaded,
  });

  final DocumentReference<Map<String, dynamic>> contentRef;
  final bool editing;
  final TextEditingController textController;
  final ValueChanged<ContentModel> onContentLoaded;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: contentRef.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) {
          return const Center(child: CircularProgressIndicator());
        }

        final content = ContentModel.fromSnapshot(snap.data!);
        onContentLoaded(content);

        final dateStr = content.createdAt != null
            ? DateFormat.yMMMd().add_jm().format(content.createdAt!)
            : '';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Source badge + date
              Row(
                children: [
                  if (content.source != 'manual')
                    Chip(
                      avatar: const Icon(Icons.mic, size: 16),
                      label: Text(content.sourceBadge),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (content.source != 'manual') const SizedBox(width: 8),
                  Text(dateStr,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 16),

              // Timeline link
              if (content.timelineRef != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.timeline, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Linked to timeline entry',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppPaletteScope.of(context).primary2,
                            ),
                      ),
                    ],
                  ),
                ),

              // Call metadata
              if (content.callMeta != null) ...[
                _CallMetaCard(meta: content.callMeta!),
                const SizedBox(height: 16),
              ],

              // Text body
              if (editing)
                TextField(
                  controller: textController,
                  maxLines: null,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Enter note text...',
                  ),
                  textInputAction: TextInputAction.newline,
                  onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                )
              else
                SelectableText(
                  content.text,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CallMetaCard extends StatelessWidget {
  const _CallMetaCard({required this.meta});
  final Map<String, dynamic> meta;

  @override
  Widget build(BuildContext context) {
    final callType = meta['callType'] as String? ?? '';
    final participants =
        (meta['participants'] as List<dynamic>?)?.cast<String>() ?? [];
    final duration = meta['duration'] as num?;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Call Info',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            if (callType.isNotEmpty) Text('Type: $callType'),
            if (participants.isNotEmpty)
              Text('Participants: ${participants.join(', ')}'),
            if (duration != null) Text('Duration: ${duration}s'),
          ],
        ),
      ),
    );
  }
}
