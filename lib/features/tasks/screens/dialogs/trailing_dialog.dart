// lib/features/tasks/screens/trailing_dialog.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:kleenops_admin/widgets/viewers/image_viewer.dart';
import 'package:kleenops_admin/widgets/viewers/video_viewer.dart';

class TrailingDialog {
  static List<String> _extractImageUrls(List<Map<String, dynamic>>? images) {
    if (images == null) return [];
    final urls = <String>[];
    for (final entry in images) {
      final candidates = [
        entry['url'],
        entry['imageUrl'],
        entry['image'],
      ];
      for (final candidate in candidates) {
        if (candidate is String) {
          final trimmed = candidate.trim();
          if (trimmed.isNotEmpty) {
            urls.add(trimmed);
            break;
          }
        }
      }
    }
    return urls;
  }

  static List<String> _extractVideoUrls(List<Map<String, dynamic>>? videos) {
    if (videos == null) return [];
    final urls = <String>[];
    for (final entry in videos) {
      final candidates = [
        entry['videoUrl'],
        entry['url'],
        entry['video'],
      ];
      for (final candidate in candidates) {
        if (candidate is String) {
          final trimmed = candidate.trim();
          if (trimmed.isNotEmpty) {
            urls.add(trimmed);
            break;
          }
        }
      }
    }
    return urls;
  }

  /// Show a confirmation dialog to start or join a task.
  static Future<bool> showJoinTaskDialog({
    required BuildContext context,
    required bool isOnlyUser,
    String? alertNote,
    List<Map<String, dynamic>>? alertImages,
    List<Map<String, dynamic>>? alertVideos,
  }) async {
    final noteText = alertNote?.trim();
    final imageUrls = _extractImageUrls(alertImages);
    final videoUrls = _extractVideoUrls(alertVideos);

    if ((noteText != null && noteText.isNotEmpty) ||
        imageUrls.isNotEmpty ||
        videoUrls.isNotEmpty) {
      await showDialog(
        context: context,
        builder: (ctx) => DialogAction(
          title: 'Task Alert',
          cancelText: 'Continue',
          onAction: () {},
          actionText: '',
          showActionButton: false,
          onCancel: () => Navigator.of(ctx).pop(),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (noteText != null && noteText.isNotEmpty) Text(noteText),
                if (imageUrls.isNotEmpty) ...[
                  if (noteText != null && noteText.isNotEmpty)
                    const SizedBox(height: 16),
                  const Text(
                    'Images',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  for (final url in imageUrls) ...[
                    GestureDetector(
                      onTap: () => Navigator.of(ctx).push(
                        MaterialPageRoute(
                          builder: (_) => ImageViewer(imageUrl: url),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: url,
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            height: 160,
                            color: Colors.grey[200],
                            child: const Icon(Icons.broken_image),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
                if (videoUrls.isNotEmpty) ...[
                  if ((noteText != null && noteText.isNotEmpty) ||
                      imageUrls.isNotEmpty)
                    const SizedBox(height: 16),
                  const Text(
                    'Videos',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  for (var i = 0; i < videoUrls.length; i++) ...[
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.videocam),
                      title: Text('Video ${i + 1}'),
                      onTap: () => Navigator.of(ctx).push(
                        MaterialPageRoute(
                          builder: (_) => VideoViewer(videoUrl: videoUrls[i]),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      );
    }
    final title = isOnlyUser ? 'Start Task?' : 'Join Task?';
    final actionText = isOnlyUser ? 'Start' : 'Join';
    bool confirmed = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        return DialogAction(
          title: title,
          content: const Text(
            'Are you sure you want to proceed?',
          ),
          cancelText: 'Cancel',
          actionText: actionText,
          onCancel: () => Navigator.of(ctx).pop(),
          onAction: () {
            confirmed = true;
            Navigator.of(ctx).pop();
          },
        );
      },
    );

    return confirmed;
  }

  /// Show a confirmation dialog to exit a task.
  static Future<bool> showExitTaskDialog({
    required BuildContext context,
  }) async {
    bool confirmed = false;
    await showDialog(
      context: context,
      builder: (ctx) {
        return DialogAction(
          title: 'Exit Task?',
          content: const Text(
            'Are you sure you want to exit this task?',
          ),
          cancelText: 'Cancel',
          actionText: 'Exit',
          onCancel: () => Navigator.of(ctx).pop(),
          onAction: () {
            confirmed = true;
            Navigator.of(ctx).pop();
          },
        );
      },
    );
    return confirmed;
  }

  /// Show a dialog to ask if the task is complete (for the last person).
  static Future<bool?> showTaskCompletionDialog({
    required BuildContext context,
  }) async {
    /// return `true` if user says "Yes, complete"
    /// return `false` if user says "No, not complete"
    /// return `null` if user cancels or closes the dialog
    bool? isComplete;

    await showDialog(
      context: context,
      builder: (ctx) {
        return DialogAction(
          title: 'Task Complete?',
          content: const Text(
            'You are the last one in this task. Mark task complete?',
          ),
          cancelText: 'No',
          actionText: 'Yes',
          onCancel: () {
            isComplete = false;
            Navigator.of(ctx).pop();
          },
          onAction: () {
            isComplete = true;
            Navigator.of(ctx).pop();
          },
        );
      },
    );

    return isComplete;
  }

  /// Show a dialog to gather a required note from the user.
  static Future<String?> showTaskNoteDialog({
    required BuildContext context,
  }) async {
    final TextEditingController noteController = TextEditingController();
    final FocusNode noteFocusNode = FocusNode();
    String? finalNote;
    String? errorText;

    await showDialog(
      context: context,
      barrierDismissible: false, // user must enter a note
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            void handleSubmit() {
              final text = noteController.text.trim();
              if (text.isEmpty) {
                setState(() => errorText = 'A note is required to exit.');
                noteFocusNode.requestFocus();
                return;
              }

              FocusScope.of(ctx).unfocus();
              finalNote = text;
              Navigator.of(ctx).pop();
            }

            return DialogAction(
              title: 'Add Note',
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Please add a note about why the task is not complete.'),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 160,
                    child: TextField(
                      controller: noteController,
                      focusNode: noteFocusNode,
                      autofocus: true,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      maxLines: null,
                      expands: true,
                      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                      decoration: InputDecoration(
                        labelText: 'Note',
                        border: const OutlineInputBorder(),
                        errorText: errorText,
                      ),
                    ),
                  ),
                ],
              ),
              cancelText: 'Cancel',
              actionText: 'Save',
              onCancel: handleSubmit,
              onAction: handleSubmit,
            );
          },
        );
      },
    );

    noteController.dispose();
    noteFocusNode.dispose();

    return finalNote;
  }
}
