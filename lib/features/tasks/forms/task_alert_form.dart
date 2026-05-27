import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kleenops_admin/app/shared_widgets/forms/form_ai_bottom_bar.dart';
import 'package:kleenops_admin/services/ai/ai_context_service.dart';
import 'package:kleenops_admin/services/ai_text_adapter.dart';
import 'package:kleenops_admin/widgets/ai/ai_screen_context.dart';
import 'package:kleenops_admin/widgets/layout/bookended_canvas.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:shared_widgets/fields/markup_image_field.dart';
import 'package:shared_widgets/fields/video_field.dart';
import 'package:shared_widgets/markup/image_markup.dart';
import 'package:kleenops_admin/features/tasks/utils/task_alert_file_media.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';

class TaskAlertForm extends StatefulWidget {
  const TaskAlertForm({
    super.key,
    required this.timelineRef,
    this.successMessage = 'Task alert saved to timeline',
  });

  final DocumentReference<Map<String, dynamic>> timelineRef;
  final String successMessage;

  static Future<bool?> show(
    BuildContext context, {
    required DocumentReference<Map<String, dynamic>> timelineRef,
    String successMessage = 'Task alert saved to timeline',
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TaskAlertForm(
          timelineRef: timelineRef,
          successMessage: successMessage,
        ),
      ),
    );
  }

  @override
  State<TaskAlertForm> createState() => _TaskAlertFormState();
}

class _TaskAlertFormState extends State<TaskAlertForm> {
  final TextEditingController _alertCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  late final String _aiContextKey =
      'tasks_alert_form:${widget.timelineRef.id}';

  List<Map<String, dynamic>> _alertImages = [];
  List<Map<String, dynamic>> _alertVideos = [];
  String? _selectedImageUrl;
  String? _selectedVideoUrl;
  DocumentReference<Map<String, dynamic>>? _taskRef;
  Timestamp? _alertDate;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _alertCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final snap = await widget.timelineRef.get();
      final data = snap.data() ?? {};

      _alertCtrl.text = (data['taskAlertNote'] as String?)?.trim() ?? '';
      _taskRef = data['taskId'] as DocumentReference<Map<String, dynamic>>?;
      _alertDate = data['alertDate'] as Timestamp?;

      final fileMedia = await TaskAlertFileMedia.load(
        companyRef: widget.timelineRef.parent.parent ??
            FirebaseFirestore.instance.collection('company').doc('company'),
        alertRef: widget.timelineRef,
      );
      _alertImages = fileMedia.images;
      _alertVideos = fileMedia.videos;

      _selectedImageUrl = _firstImageUrl(_alertImages);
      _selectedVideoUrl = _firstVideoUrl(_alertVideos);
    } catch (e) {
      if (mounted) {
        SnackbarService.instance.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 5),
            content: Text('Unable to load task alert: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _firstImageUrl(List<Map<String, dynamic>> images) {
    for (final entry in images) {
      final url = _imageUrlFromEntry(entry);
      if (url != null && url.isNotEmpty) return url;
    }
    return null;
  }

  String? _firstVideoUrl(List<Map<String, dynamic>> videos) {
    for (final entry in videos) {
      final url = _videoUrlFromEntry(entry);
      if (url != null && url.isNotEmpty) return url;
    }
    return null;
  }

  String? _imageUrlFromEntry(Map<String, dynamic> entry) {
    final candidates = [
      entry['url'],
      entry['imageUrl'],
      entry['image'],
    ];
    for (final candidate in candidates) {
      if (candidate is String) {
        final trimmed = candidate.trim();
        if (trimmed.isNotEmpty) return trimmed;
      }
    }
    return null;
  }

  String? _videoUrlFromEntry(Map<String, dynamic> entry) {
    final candidates = [
      entry['videoUrl'],
      entry['url'],
      entry['video'],
    ];
    for (final candidate in candidates) {
      if (candidate is String) {
        final trimmed = candidate.trim();
        if (trimmed.isNotEmpty) return trimmed;
      }
    }
    return null;
  }

  List<Map<String, dynamic>> _sanitizeImages(
    List<Map<String, dynamic>> images,
  ) {
    return images
        .where((entry) {
          final url = _imageUrlFromEntry(entry);
          return url != null && url.isNotEmpty;
        })
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
  }

  List<Map<String, dynamic>> _sanitizeVideos(
    List<Map<String, dynamic>> videos,
  ) {
    return videos
        .where((entry) {
          final url = _videoUrlFromEntry(entry);
          return url != null && url.isNotEmpty;
        })
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
  }

  Future<void> _launchImageMarkup() async {
    final currentUrl = _selectedImageUrl?.trim();
    if (currentUrl == null || currentUrl.isEmpty) {
      SnackbarService.instance.showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 5),
          content: Text('No image selected.'),
        ),
      );
      return;
    }

    final updated = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => BasicImageMarkupScreen(imageUrl: currentUrl),
      ),
    );

    if (updated == null || updated.trim().isEmpty) return;
    _replaceImageUrl(currentUrl, updated.trim());
  }

  void _replaceImageUrl(String oldUrl, String newUrl) {
    var replaced = false;
    final updated = _alertImages.map((entry) {
      final url = _imageUrlFromEntry(entry);
      if (url == null || url != oldUrl) return entry;
      final next = Map<String, dynamic>.from(entry);
      next['url'] = newUrl;
      replaced = true;
      return next;
    }).toList();
    if (!replaced) {
      updated.add({
        'url': newUrl,
        'order': updated.length,
        'isMaster': updated.isEmpty,
      });
    }

    setState(() {
      _alertImages = updated;
      _selectedImageUrl = newUrl;
    });
  }

  Future<void> _showInfo(String title, String body) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => DialogAction(
        title: title,
        content: Text(body),
        cancelText: 'Close',
        onCancel: () => Navigator.of(ctx).pop(),
        showActionButton: false,
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final note = _alertCtrl.text.trim();
      final images = _sanitizeImages(_alertImages);
      final videos = _sanitizeVideos(_alertVideos);

      final updates = <String, dynamic>{
        'taskAlertNote': note,
        'updatedAt': FieldValue.serverTimestamp(),
        'taskAlertImages': FieldValue.delete(),
        'taskAlertVideos': FieldValue.delete(),
        'videoMessage': FieldValue.delete(),
        'audioMessage': FieldValue.delete(),
      };

      await widget.timelineRef.update(updates);
      await TaskAlertFileMedia.sync(
        companyRef: widget.timelineRef.parent.parent ??
            FirebaseFirestore.instance.collection('company').doc('company'),
        alertRef: widget.timelineRef,
        images: images,
        videos: videos,
        taskRef: _taskRef,
        alertDate: _alertDate,
      );

      if (mounted) {
        SnackbarService.instance.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 5),
            content: Text(widget.successMessage),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        SnackbarService.instance.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 5),
            content: Text('Error saving task alert: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  AiContextState _buildAiContext() {
    return AiContextState(
      key: _aiContextKey,
      sectionKey: 'tasks',
      screenType: 'tasks_alert_form',
      label: 'Task Alert',
      entityId: widget.timelineRef.id,
      entityPath: widget.timelineRef.path,
      title: 'Tasks AI',
      subtitle: 'Ask about this task alert.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BookendedCanvas(
        child: AiScreenContext(
          context: _buildAiContext(),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ContainerActionWidget(
                        title: 'Alert',
                        onTitleInfoPressed: () => _showInfo(
                          'Alert',
                          'Add notes that should appear with this task alert.',
                        ),
                        actionText: '',
                        content: AITextField(
                          controller: _alertCtrl,
                          labelText: 'Alert',
                          minLines: 3,
                          maxLines: 6,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ContainerActionWidget(
                        title: 'Images',
                        onTitleInfoPressed: () => _showInfo(
                          'Images',
                          'Add or mark up images for the task alert.',
                        ),
                        actionText: '',
                        content: MarkupImageField(
                          imageUrl: _selectedImageUrl,
                          images: _alertImages,
                          onImagesChanged: (images) =>
                              setState(() => _alertImages = images),
                          onImageChanged: (url) =>
                              setState(() => _selectedImageUrl = url),
                          onMarkupTap: _launchImageMarkup,
                          storageFolder: 'taskAlertImages',
                        ),
                      ),
                      const SizedBox(height: 16),
                      ContainerActionWidget(
                        title: 'Videos',
                        onTitleInfoPressed: () => _showInfo(
                          'Videos',
                          'Record or upload videos for the task alert.',
                        ),
                        actionText: '',
                        content: VideoField(
                          videoUrl: _selectedVideoUrl,
                          videos: _alertVideos,
                          onVideosChanged: (videos) =>
                              setState(() => _alertVideos = videos),
                          onVideoChanged: (url) =>
                              setState(() => _selectedVideoUrl = url),
                          storageFolder: 'taskAlertVideos',
                          hintText: 'Record or pick a video',
                        ),
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
        ),
      ),
      bottomNavigationBar: FormAiBottomBar(
        title: 'Task Alert',
        onCancel: () => Navigator.of(context).pop(false),
        onSave: _loading ? null : _save,
        isSaving: _saving,
      ),
    );
  }
}
