import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:shared_widgets/theme/app_palette.dart';

/// Converts a completed transcription into content docs inside a notes folder,
/// creates a timeline entry linking the call, and stores callMeta on each doc.
class TranscriptionToNotesService {
  TranscriptionToNotesService._();
  static final instance = TranscriptionToNotesService._();

  /// Show a post-call dialog asking whether to save the transcript to Notes.
  ///
  /// Returns `true` if the transcript was saved, `false` if dismissed.
  Future<bool> promptSaveTranscript(
    BuildContext context, {
    required DocumentReference<Map<String, dynamic>> companyRef,
    required DocumentReference<Map<String, dynamic>> memberRef,
    required String fullText,
    required String callType, // 'phone', 'intercom_openChannel', 'intercom_ptt', 'intercom_voice', 'videoCall'
    required List<String> participantIds,
    List<String>? participantNames,
    DateTime? startTime,
    DateTime? endTime,
    String? source,
    String? sourceContext,
  }) async {
    if (fullText.trim().isEmpty) return false;

    final result = await showDialog<_SaveChoice>(
      context: context,
      builder: (ctx) => _SaveTranscriptDialog(companyRef: companyRef, memberRef: memberRef),
    );

    if (result == null || !context.mounted) return false;

    await saveTranscript(
      companyRef: companyRef,
      memberRef: memberRef,
      folderRef: result.folderRef,
      fullText: fullText,
      callType: callType,
      participantIds: participantIds,
      participantNames: participantNames,
      startTime: startTime,
      endTime: endTime,
      source: source,
      sourceContext: sourceContext,
    );

    return true;
  }

  /// Save transcript text to a folder as content docs + timeline entry.
  Future<void> saveTranscript({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required DocumentReference<Map<String, dynamic>> memberRef,
    required DocumentReference<Map<String, dynamic>> folderRef,
    required String fullText,
    required String callType,
    required List<String> participantIds,
    List<String>? participantNames,
    DateTime? startTime,
    DateTime? endTime,
    String? source,
    String? sourceContext,
  }) async {
    final paragraphs = _splitIntoParagraphs(fullText);
    if (paragraphs.isEmpty) return;

    final contentSource = _sourceFromCallType(callType);
    final duration = (startTime != null && endTime != null)
        ? endTime.difference(startTime).inSeconds
        : null;

    // 1. Create timeline entry
    final timelineRef = await companyRef.collection('timeline').add({
      'timelineCategory': 'callTranscription',
      'callType': callType,
      'folderRef': folderRef,
      'participants': participantIds,
      'participantNames': participantNames ?? [],
      'startTime': startTime != null ? Timestamp.fromDate(startTime) : null,
      'endTime': endTime != null ? Timestamp.fromDate(endTime) : null,
      'duration': duration,
      'source': source,
      'sourceContext': sourceContext,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2. Get current max position in folder
    final existingContent = await companyRef
        .collection('content')
        .where('folderRef', isEqualTo: folderRef)
        .orderBy('position', descending: true)
        .limit(1)
        .get();
    int nextPosition = existingContent.docs.isNotEmpty
        ? ((existingContent.docs.first.data()['position'] as num?)?.toInt() ?? 0) + 1
        : 1;

    // 3. Batch-write content docs
    final callMeta = {
      'callType': callType,
      'participants': participantIds,
      if (participantNames != null) 'participantNames': participantNames,
      if (duration != null) 'duration': duration,
    };

    final contentRefs = <DocumentReference<Map<String, dynamic>>>[];
    final batch = FirebaseFirestore.instance.batch();

    for (final para in paragraphs) {
      final contentRef = companyRef.collection('content').doc();
      contentRefs.add(contentRef);

      batch.set(contentRef, {
        'folderRef': folderRef,
        'text': para,
        'position': nextPosition++,
        'source': contentSource,
        'timelineRef': timelineRef,
        'callMeta': callMeta,
        'memberRef': memberRef,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();

    // 4. Update timeline entry with content refs
    await timelineRef.update({
      'contentRefs': contentRefs,
    });
  }

  /// Split transcript text into paragraphs.
  ///
  /// Uses double-newlines as paragraph boundaries. If no double-newlines exist,
  /// falls back to splitting every ~500 characters at sentence boundaries.
  List<String> _splitIntoParagraphs(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return [];

    // Try double-newline split first
    final parts = trimmed
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    if (parts.length > 1) return parts;

    // Single block — split at sentence boundaries around 500 chars
    if (trimmed.length <= 600) return [trimmed];

    final result = <String>[];
    final sentences = trimmed.split(RegExp(r'(?<=[.!?])\s+'));
    final buffer = StringBuffer();

    for (final sentence in sentences) {
      if (buffer.length + sentence.length > 500 && buffer.isNotEmpty) {
        result.add(buffer.toString().trim());
        buffer.clear();
      }
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write(sentence);
    }

    if (buffer.isNotEmpty) {
      result.add(buffer.toString().trim());
    }

    return result.isEmpty ? [trimmed] : result;
  }

  String _sourceFromCallType(String callType) {
    switch (callType) {
      case 'phone':
        return 'phone_transcription';
      case 'videoCall':
        return 'video_transcription';
      default:
        return 'intercom_transcription';
    }
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Post-call save dialog
// ──────────────────────────────────────────────────────────────────────────────

class _SaveChoice {
  final DocumentReference<Map<String, dynamic>> folderRef;
  _SaveChoice({required this.folderRef});
}

class _SaveTranscriptDialog extends StatefulWidget {
  const _SaveTranscriptDialog({
    required this.companyRef,
    required this.memberRef,
  });

  final DocumentReference<Map<String, dynamic>> companyRef;
  final DocumentReference<Map<String, dynamic>> memberRef;

  @override
  State<_SaveTranscriptDialog> createState() => _SaveTranscriptDialogState();
}

class _SaveTranscriptDialogState extends State<_SaveTranscriptDialog> {
  DocumentReference<Map<String, dynamic>>? _selectedFolder;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _folders = [];
  bool _loading = true;
  bool _creatingNew = false;
  final _newFolderController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  @override
  void dispose() {
    _newFolderController.dispose();
    super.dispose();
  }

  Future<void> _loadFolders() async {
    final snap = await widget.companyRef
        .collection('folder')
        .where('memberId', isEqualTo: widget.memberRef.id)
        .orderBy('name')
        .get();

    if (!mounted) return;
    setState(() {
      _folders = snap.docs;
      _loading = false;
    });
  }

  Future<void> _createFolder() async {
    final name = _newFolderController.text.trim();
    if (name.isEmpty) return;

    setState(() => _creatingNew = true);

    final ref = await widget.companyRef.collection('folder').add({
      'name': name,
      'parentFolderRef': null,
      'position': _folders.length,
      'memberId': widget.memberRef.id,
      'memberRef': widget.memberRef,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    Navigator.of(context).pop(_SaveChoice(folderRef: ref));
  }

  @override
  Widget build(BuildContext context) {
    return DialogAction(
      title: 'Save Transcript',
      content: SizedBox(
        width: 300,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Choose a folder:'),
                  const SizedBox(height: 8),
                  if (_folders.isNotEmpty)
                    ...List.generate(_folders.length, (i) {
                      final doc = _folders[i];
                      final name = (doc.data()['name'] as String?) ?? '';
                      final selected =
                          _selectedFolder?.path == doc.reference.path;
                      return ListTile(
                        leading: Icon(
                          selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: selected
                              ? AppPaletteScope.of(context).primary2
                              : null,
                        ),
                        title: Text(name),
                        dense: true,
                        onTap: () => setState(
                            () => _selectedFolder = doc.reference),
                      );
                    }),
                  const Divider(),
                  const Text('Or create a new folder:'),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newFolderController,
                          decoration: const InputDecoration(
                            hintText: 'Folder name',
                            isDense: true,
                          ),
                          textInputAction: TextInputAction.done,
                          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _creatingNew
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: _createFolder,
                            ),
                    ],
                  ),
                ],
              ),
      ),
      cancelText: 'Discard',
      onCancel: () => Navigator.of(context).pop(),
      actionText: 'Save',
      onAction: _selectedFolder == null
          ? null
          : () => Navigator.of(context)
              .pop(_SaveChoice(folderRef: _selectedFolder!)),
    );
  }
}
