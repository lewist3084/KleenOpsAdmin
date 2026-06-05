// lib/common/communications/messageboard/screens/message_board_form_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:kleenops_admin/app/shared_widgets/forms/form_ai_bottom_bar.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/services/ai_text_adapter.dart';
import 'package:kleenops_admin/widgets/layout/bookended_canvas.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/dialogs/dialog_select.dart';
import 'package:shared_widgets/fields/ai_text.dart' as shared;
import 'package:shared_widgets/theme/app_palette.dart';
import 'package:shared_widgets/fields/file_uploader.dart';
import 'package:shared_widgets/lists/standardView.dart';
import 'package:shared_widgets/tiles/selectable_row_tile.dart';
import '../models/message_board_post.dart';
import '../services/message_board_service.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';

class MessageBoardFormScreen extends ConsumerStatefulWidget {
  final DocumentReference<Map<String, dynamic>>? postRef;
  final MessageBoardPost? initialData;

  const MessageBoardFormScreen({
    super.key,
    this.postRef,
    this.initialData,
  });

  bool get isEditing => postRef != null;

  @override
  ConsumerState<MessageBoardFormScreen> createState() =>
      _MessageBoardFormScreenState();
}

class _MessageBoardFormScreenState
    extends ConsumerState<MessageBoardFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _linkController = TextEditingController();

  String _selectedNoteColor = MessageBoardPost.noteColors.first;
  bool _isPinned = false;

  // File uploader state
  String? _imageUrl;
  String? _videoUrl;
  List<Map<String, dynamic>> _images = const [];
  List<Map<String, dynamic>> _videos = const [];
  List<Map<String, dynamic>> _documents = const [];
  FileUploaderType? _initialUploaderType;

  List<DocumentReference> _selectedTeams = [];
  final Map<String, String> _teamLabelCache = {};
  DateTime? _expiresAt;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _loadExistingData();
    }
  }

  void _loadExistingData() {
    final data = widget.initialData!;
    _titleController.text = data.title;
    _contentController.text = data.content ?? '';
    _selectedNoteColor = data.noteColor ?? MessageBoardPost.noteColors.first;
    _isPinned = data.isPinned;
    _linkController.text = data.linkUrl ?? '';
    _selectedTeams = data.teamRefs;
    _expiresAt = data.expiresAt;

    switch (data.type) {
      case MessageBoardPostType.image:
        if (data.fileUrl != null) {
          _imageUrl = data.fileUrl;
          _images = [
            {'url': data.fileUrl, 'order': 0},
          ];
          _initialUploaderType = FileUploaderType.image;
        }
        break;
      case MessageBoardPostType.video:
        if (data.fileUrl != null) {
          _videoUrl = data.fileUrl;
          _videos = [
            {'url': data.fileUrl, 'order': 0},
          ];
          _initialUploaderType = FileUploaderType.video;
        }
        break;
      case MessageBoardPostType.document:
        if (data.fileUrl != null) {
          _documents = [
            {
              'url': data.fileUrl,
              'name': data.fileName ?? 'Document',
              'order': 0,
            },
          ];
          _initialUploaderType = FileUploaderType.document;
        }
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final companyAsync = ref.watch(companyIdProvider);
    final userAsync = ref.watch(userDocumentProvider);

    return companyAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Error: $e')),
      ),
      data: (companyRef) {
        if (companyRef == null) {
          return const Scaffold(
            body: Center(child: Text('No company selected.')),
          );
        }
        return userAsync.when(
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Scaffold(
            body: Center(child: Text('Error: $e')),
          ),
          data: (userData) => _buildForm(context, companyRef, userData),
        );
      },
    );
  }

  Widget _buildForm(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> companyRef,
    Map<String, dynamic> userData,
  ) {
    final teamAccess = (userData['teamAccess'] as List<dynamic>? ?? [])
        .whereType<DocumentReference>()
        .toList();

    final title = widget.isEditing ? 'Edit Post' : 'New Post';
    final imageStorageFolder = 'company/${companyRef.id}/messageboard/images';
    final videoStorageFolder = 'company/${companyRef.id}/messageboard/videos';
    final documentStorageFolder = 'company/${companyRef.id}/messageboard/files';

    return Scaffold(
      appBar: null,
      body: BookendedCanvas(
        child: Column(
          children: [
            if (_saving) const LinearProgressIndicator(),
            Expanded(
              child: Form(
                key: _formKey,
                child: StandardView<Widget>(
                  items: [
                    // --- Media ---
                    ContainerActionWidget(
                      title: 'Media',
                      actionText: '',
                      content: FileUploaderField(
                        allowImages: true,
                        allowVideos: true,
                        allowDocuments: true,
                        initialType: _initialUploaderType,
                        imageUrl: _imageUrl,
                        images: _images,
                        onImagesChanged: (entries) {
                          setState(() {
                            _images = entries
                                .map((e) => Map<String, dynamic>.from(e))
                                .toList();
                          });
                        },
                        onImageChanged: (url) {
                          setState(() {
                            final trimmed = url.trim();
                            _imageUrl = trimmed.isEmpty ? null : trimmed;
                          });
                        },
                        imageStorageFolder: imageStorageFolder,
                        videoUrl: _videoUrl,
                        videos: _videos,
                        onVideosChanged: (entries) {
                          setState(() {
                            _videos = entries
                                .map((e) => Map<String, dynamic>.from(e))
                                .toList();
                          });
                        },
                        onVideoChanged: (url) {
                          setState(() {
                            final trimmed = url.trim();
                            _videoUrl = trimmed.isEmpty ? null : trimmed;
                          });
                        },
                        onVideoDurationChanged: (_) {},
                        videoStorageFolder: videoStorageFolder,
                        documents: _documents,
                        onDocumentsChanged: (entries) {
                          setState(() {
                            _documents = entries
                                .map((e) => Map<String, dynamic>.from(e))
                                .toList();
                          });
                        },
                        documentStorageFolder: documentStorageFolder,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // --- Details ---
                    ContainerActionWidget(
                      title: 'Details',
                      actionText: '',
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AITextField(
                            labelText: 'Title',
                            controller: _titleController,
                            height: shared.StreamingSpeechFieldHeight.singleLine,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Title is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          AITextField(
                            labelText: 'Description',
                            controller: _contentController,
                            height: shared.StreamingSpeechFieldHeight.expanded,
                            maxLines: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // --- Link ---
                    ContainerActionWidget(
                      title: 'Link',
                      actionText: '',
                      content: AITextField(
                        labelText: 'URL (optional)',
                        controller: _linkController,
                        height: shared.StreamingSpeechFieldHeight.singleLine,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // --- Share with Teams ---
                    ContainerActionWidget(
                      title: 'Share with Teams',
                      actionText: '',
                      content: _buildTeamField(companyRef, teamAccess),
                    ),
                    const SizedBox(height: 16),

                    // --- Options ---
                    ContainerActionWidget(
                      title: 'Options',
                      actionText: '',
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildNoteColorPicker(),
                          const SizedBox(height: 16),
                          SelectableRowTile<bool>(
                            value: true,
                            selected: _isPinned,
                            onTap: _saving
                                ? null
                                : () => setState(
                                      () => _isPinned = !_isPinned,
                                    ),
                            label: 'Pin to Top',
                            contentPadding: EdgeInsets.zero,
                          ),
                          const SizedBox(height: 16),
                          _buildExpirationPicker(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 80),
                  ],
                  groupBy: (_) => null,
                  itemBuilder: (child) => child,
                  disableGrouping: true,
                  padding: EdgeInsets.zero,
                  shrinkWrap: false,
                  physics: const ClampingScrollPhysics(),
                  showDividersInFlat: false,
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: FormAiBottomBar(
        title: title,
        onCancel: () {
          if (_saving) return;
          Navigator.of(context).maybePop();
        },
        onSave: _saving ? null : _save,
        isSaving: _saving,
      ),
    );
  }

  Widget _buildTeamField(
    DocumentReference<Map<String, dynamic>> companyRef,
    List<DocumentReference> availableTeams,
  ) {
    return GestureDetector(
      onTap: () => _openTeamSelector(context, companyRef, availableTeams),
      child: InputDecorator(
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        child: _selectedTeams.isEmpty
            ? Text(
                'Tap to select teams',
                style: TextStyle(color: Colors.grey.shade600),
              )
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selectedTeams.map((ref) {
                  return FutureBuilder<String>(
                    future: _getTeamLabel(ref),
                    builder: (_, snap) {
                      final label = snap.data ?? ref.id;
                      return Chip(
                        label: Text(label, style: const TextStyle(fontSize: 13)),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () {
                          setState(() {
                            _selectedTeams
                                .removeWhere((r) => r.path == ref.path);
                          });
                        },
                      );
                    },
                  );
                }).toList(),
              ),
      ),
    );
  }

  Widget _buildExpirationPicker() {
    final label = _expiresAt != null
        ? 'Expires ${DateFormat.yMMMd().format(_expiresAt!)}'
        : 'No expiration';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Expiration',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ExpirationChip(
              label: '1 week',
              selected: false,
              onTap: () => setState(() =>
                  _expiresAt = DateTime.now().add(const Duration(days: 7))),
            ),
            _ExpirationChip(
              label: '2 weeks',
              selected: false,
              onTap: () => setState(() =>
                  _expiresAt = DateTime.now().add(const Duration(days: 14))),
            ),
            _ExpirationChip(
              label: '30 days',
              selected: false,
              onTap: () => setState(() =>
                  _expiresAt = DateTime.now().add(const Duration(days: 30))),
            ),
            _ExpirationChip(
              label: '90 days',
              selected: false,
              onTap: () => setState(() =>
                  _expiresAt = DateTime.now().add(const Duration(days: 90))),
            ),
            _ExpirationChip(
              label: 'Custom...',
              selected: false,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate:
                      _expiresAt ?? DateTime.now().add(const Duration(days: 7)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _expiresAt = picked);
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              _expiresAt != null ? Icons.timer : Icons.timer_off,
              size: 14,
              color: Colors.grey.shade600,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
            if (_expiresAt != null)
              GestureDetector(
                onTap: () => setState(() => _expiresAt = null),
                child: Text(
                  'Clear',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppPaletteScope.of(context).primary2,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildNoteColorPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Note Color',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: MessageBoardPost.noteColors.map((colorHex) {
            final color =
                Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
            final isSelected = _selectedNoteColor == colorHex;
            return GestureDetector(
              onTap: () => setState(() => _selectedNoteColor = colorHex),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? AppPaletteScope.of(context).primary2
                        : Colors.grey.shade300,
                    width: isSelected ? 3 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: isSelected
                    ? Icon(
                        Icons.check,
                        color: color.computeLuminance() > 0.5
                            ? Colors.black
                            : Colors.white,
                        size: 18,
                      )
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _openTeamSelector(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> companyRef,
    List<DocumentReference> availableTeams,
  ) async {
    if (availableTeams.isEmpty) {
      SnackbarService.instance.showSnackBar(
        const SnackBar(duration: Duration(seconds: 5), content: Text('No teams available.')),
      );
      return;
    }

    // Load team labels
    final entries = <_TeamEntry>[];
    for (final ref in availableTeams) {
      final label = await _getTeamLabel(ref);
      entries.add(_TeamEntry(ref: ref, label: label));
    }
    entries.sort(
        (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => DialogSelect<_TeamEntry>(
        title: 'Share with Teams',
        items: entries,
        itemLabel: (entry) => entry.label,
        tileType: DialogSelectTileType.checkbox,
        initialSelections: entries
            .where((entry) =>
                _selectedTeams.any((r) => r.path == entry.ref.path))
            .toList(),
        itemSearchString: (entry) => entry.label,
        onCancel: () => Navigator.pop(ctx),
        onSubmit: (result) {
          Navigator.pop(ctx);
          setState(() {
            _selectedTeams =
                result.values.map((e) => e.ref).toList();
          });
        },
      ),
    );
  }

  Future<String> _getTeamLabel(DocumentReference ref) async {
    final cached = _teamLabelCache[ref.path];
    if (cached != null) return cached;

    try {
      final snap = await ref.get();
      final data = snap.data() as Map<String, dynamic>? ?? {};
      final label =
          (data['name'] as String?) ?? (data['team'] as String?) ?? ref.id;
      _teamLabelCache[ref.path] = label;
      return label;
    } catch (_) {
      _teamLabelCache[ref.path] = ref.id;
      return ref.id;
    }
  }

  /// Infer post type from the current form state.
  MessageBoardPostType _inferPostType() {
    if (_images.isNotEmpty || (_imageUrl ?? '').isNotEmpty) {
      return MessageBoardPostType.image;
    }
    if (_videos.isNotEmpty || (_videoUrl ?? '').isNotEmpty) {
      return MessageBoardPostType.video;
    }
    if (_documents.isNotEmpty) {
      return MessageBoardPostType.document;
    }
    if (_linkController.text.trim().isNotEmpty) {
      return MessageBoardPostType.link;
    }
    return MessageBoardPostType.note;
  }

  /// Resolve primary file URL from the uploaded media.
  String? _resolveFileUrl() {
    if (_images.isNotEmpty) {
      return (_images.first['url'] as String?) ??
          (_images.first['downloadUrl'] as String?);
    }
    if (_videos.isNotEmpty) {
      return (_videos.first['videoUrl'] as String?) ??
          (_videos.first['url'] as String?);
    }
    if (_documents.isNotEmpty) {
      return (_documents.first['url'] as String?) ??
          (_documents.first['downloadUrl'] as String?);
    }
    if ((_imageUrl ?? '').isNotEmpty) return _imageUrl;
    if ((_videoUrl ?? '').isNotEmpty) return _videoUrl;
    return null;
  }

  /// Resolve thumbnail URL from the uploaded media.
  String? _resolveThumbnailUrl() {
    if (_images.isNotEmpty) {
      return _images.first['thumbnailUrl'] as String?;
    }
    if (_videos.isNotEmpty) {
      return (_videos.first['videoThumbnail'] as String?) ??
          (_videos.first['thumbnailUrl'] as String?) ??
          (_videos.first['thumbnail'] as String?) ??
          (_videos.first['thumbUrl'] as String?);
    }
    return null;
  }

  /// Resolve file name for document uploads.
  String? _resolveFileName() {
    if (_documents.isNotEmpty) {
      return (_documents.first['name'] as String?) ??
          (_documents.first['fileName'] as String?);
    }
    return null;
  }

  /// Resolve mime type from the uploaded media.
  String? _resolveMimeType() {
    final entry = _images.isNotEmpty
        ? _images.first
        : _videos.isNotEmpty
            ? _videos.first
            : _documents.isNotEmpty
                ? _documents.first
                : null;
    if (entry == null) return null;

    final mimeType = entry['mimeType'] as String?;
    if (mimeType != null) return mimeType;

    // Infer from file extension
    final ext =
        (entry['fileExtension'] as String?)?.toLowerCase() ?? '';
    switch (ext) {
      case '.pdf':
        return 'application/pdf';
      case '.doc':
      case '.docx':
        return 'application/msword';
      case '.xls':
      case '.xlsx':
        return 'application/vnd.ms-excel';
      case '.ppt':
      case '.pptx':
        return 'application/vnd.ms-powerpoint';
      case '.png':
        return 'image/png';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.gif':
        return 'image/gif';
      case '.mp4':
        return 'video/mp4';
      case '.mov':
        return 'video/quicktime';
      default:
        return null;
    }
  }

  /// Resolve file size in bytes from the uploaded media.
  int? _resolveFileSizeBytes() {
    final entry = _images.isNotEmpty
        ? _images.first
        : _videos.isNotEmpty
            ? _videos.first
            : _documents.isNotEmpty
                ? _documents.first
                : null;
    if (entry == null) return null;
    return entry['sizeBytes'] as int?;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedTeams.isEmpty) {
      SnackbarService.instance.showSnackBar(
        const SnackBar(duration: Duration(seconds: 5), content: Text('Select at least one team.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final userData = await ref.read(userDocumentProvider.future);
      final companyRef =
          userData['companyId'] as DocumentReference<Map<String, dynamic>>?;
      final memberRef =
          userData['memberRef'] as DocumentReference<Map<String, dynamic>>?;
      final memberName = (userData['name'] as String?) ??
          (userData['displayName'] as String?) ??
          '';

      if (companyRef == null || memberRef == null) {
        throw Exception('Missing company or member reference.');
      }

      final service = MessageBoardService(
        companyRef: companyRef,
        memberRef: memberRef,
        memberName: memberName,
      );

      // Get team names
      final teamNames = <String>[];
      for (final ref in _selectedTeams) {
        teamNames.add(await _getTeamLabel(ref));
      }

      final teamRefs = _selectedTeams
          .map((r) => r.withConverter<Map<String, dynamic>>(
                fromFirestore: (s, _) => s.data() ?? {},
                toFirestore: (m, _) => m,
              ))
          .toList();

      final type = _inferPostType();
      final fileUrl = _resolveFileUrl();
      final thumbnailUrl = _resolveThumbnailUrl();
      final mimeType = _resolveMimeType();
      final fileSizeBytes = _resolveFileSizeBytes();
      final linkUrl = _linkController.text.trim().isNotEmpty
          ? _linkController.text.trim()
          : null;

      if (widget.isEditing) {
        await service.updatePost(
          postId: widget.postRef!.id,
          title: _titleController.text.trim(),
          content: _contentController.text.trim().isEmpty
              ? null
              : _contentController.text.trim(),
          isPinned: _isPinned,
          noteColor: _selectedNoteColor,
          fileUrl: fileUrl,
          thumbnailUrl: thumbnailUrl,
          fileName: _resolveFileName(),
          mimeType: mimeType,
          fileSizeBytes: fileSizeBytes,
          linkUrl: linkUrl,
          teamRefs: teamRefs,
          teamNames: teamNames,
          expiresAt: _expiresAt,
        );

        if (!mounted) return;
        SnackbarService.instance.showSnackBar(
          const SnackBar(duration: Duration(seconds: 5), content: Text('Post updated.')),
        );
      } else {
        await service.createPost(
          title: _titleController.text.trim(),
          content: _contentController.text.trim().isEmpty
              ? null
              : _contentController.text.trim(),
          type: type,
          isPinned: _isPinned,
          noteColor: _selectedNoteColor,
          fileUrl: fileUrl,
          thumbnailUrl: thumbnailUrl,
          fileName: _resolveFileName(),
          mimeType: mimeType,
          fileSizeBytes: fileSizeBytes,
          linkUrl: linkUrl,
          teamRefs: teamRefs,
          teamNames: teamNames,
          expiresAt: _expiresAt,
        );

        if (!mounted) return;
        SnackbarService.instance.showSnackBar(
          const SnackBar(duration: Duration(seconds: 5), content: Text('Post created.')),
        );
      }

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      SnackbarService.instance.showSnackBar(
        SnackBar(duration: const Duration(seconds: 5), content: Text('Failed to save post: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _TeamEntry {
  final DocumentReference ref;
  final String label;

  _TeamEntry({required this.ref, required this.label});
}

class _ExpirationChip extends StatelessWidget {
  const _ExpirationChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: onTap,
      backgroundColor: selected
          ? Theme.of(context).colorScheme.primaryContainer
          : null,
    );
  }
}

