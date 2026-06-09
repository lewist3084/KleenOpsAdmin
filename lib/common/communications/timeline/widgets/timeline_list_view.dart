// lib/common/communications/timeline/widgets/timeline_list_view.dart
//
// Renders a unified per-member timeline of TimelineItems. AI conversation
// items reuse the existing AICanvasTile chat-bubble widget; all other types
// render as compact "communication" cards (icon strip + title + AI summary).

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:kleenops_admin/common/utils/snackbar_service.dart';
import 'package:kleenops_admin/features/occupancy/models/agent_task_run.dart';
import 'package:shared_widgets/tiles/ai_canvas_tile.dart';
import 'package:shared_widgets/viewers/image_viewer.dart';
import 'package:shared_widgets/viewers/pdf_viewer.dart';

import '../models/timeline_item.dart';

class TimelineListView extends StatelessWidget {
  const TimelineListView({
    super.key,
    required this.items,
    this.onItemTap,
    this.onItemAcknowledge,
    this.controller,
    this.padding,
  });

  final List<TimelineItem> items;
  final void Function(TimelineItem item)? onItemTap;

  /// Invoked when a tile is swiped to acknowledge. When null tiles are not
  /// swipeable — read-only timeline views simply omit it.
  final void Function(TimelineItem item)? onItemAcknowledge;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return _emptyState(context);
    final rows = groupTimelineRows(items);
    return ListView.builder(
      controller: controller,
      padding: padding ?? const EdgeInsets.symmetric(vertical: 12),
      itemCount: rows.length,
      itemBuilder: (context, i) => buildTimelineRow(
        rows[i],
        onItemTap: onItemTap,
        onItemAcknowledge: onItemAcknowledge,
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timeline, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'No timeline activity yet',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Emails, calls, board posts, and AI conversations will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}

/// One render row in a timeline list. A row is either a single TimelineItem
/// or a bundle of consecutive AI conversation turns that share the same
/// `conversationId` — those collapse into one expandable card so the user
/// sees one entry per chat session instead of N chat bubbles in a row.
sealed class TimelineRow {
  const TimelineRow();

  /// Timestamp used for ordering / display. Bundles take the newest item's
  /// timestamp so they slot into the timeline at the position of the latest
  /// turn.
  DateTime get timestamp;
}

class TimelineSingleRow extends TimelineRow {
  const TimelineSingleRow(this.item);
  final TimelineItem item;

  @override
  DateTime get timestamp => item.timestamp;
}

class TimelineAiBundleRow extends TimelineRow {
  const TimelineAiBundleRow(this.items, this.conversationId);

  /// Turns in the same order the source list provided them (newest-first
  /// when the source is the unified member timeline). The card reverses
  /// these on expand so the bubbles read top-to-bottom chronologically.
  final List<TimelineItem> items;
  final String conversationId;

  @override
  DateTime get timestamp => items.first.timestamp;
}

/// Collapses consecutive `aiConversation` items sharing the same
/// `conversationId` into a single bundle row. Items without a
/// `conversationId` (older docs, or a system error message) stay as
/// standalone rows.
List<TimelineRow> groupTimelineRows(List<TimelineItem> items) {
  final rows = <TimelineRow>[];
  int i = 0;
  while (i < items.length) {
    final item = items[i];
    final convId = item.conversationId;
    final isBundleable =
        item.kind == TimelineItemKind.aiConversation && convId != null;
    if (!isBundleable) {
      rows.add(TimelineSingleRow(item));
      i++;
      continue;
    }
    int j = i + 1;
    while (j < items.length &&
        items[j].kind == TimelineItemKind.aiConversation &&
        items[j].conversationId == convId) {
      j++;
    }
    if (j - i == 1) {
      // A lone turn — render as a chat bubble. Bundling needs ≥ 2 items.
      rows.add(TimelineSingleRow(item));
    } else {
      rows.add(TimelineAiBundleRow(items.sublist(i, j), convId));
    }
    i = j;
  }
  return rows;
}

/// Render a [TimelineRow] to the widget tree. Single rows defer to
/// [TimelineItemTile]; AI-conversation bundles render the expandable
/// [_AiConversationCard].
Widget buildTimelineRow(
  TimelineRow row, {
  void Function(TimelineItem item)? onItemTap,
  void Function(TimelineItem item)? onItemAcknowledge,
}) {
  switch (row) {
    case TimelineSingleRow(:final item):
      return TimelineItemTile(
        key: ValueKey(item.id),
        item: item,
        onTap: onItemTap == null ? null : () => onItemTap(item),
        onAcknowledge: onItemAcknowledge == null
            ? null
            : () => onItemAcknowledge(item),
      );
    case TimelineAiBundleRow():
      return _AiConversationCard(
        key: ValueKey('aiBundle_${row.conversationId}'),
        items: row.items,
      );
  }
}

/// Renders one timeline item. AI conversation items become chat bubbles;
/// all other types render as compact comm cards. Safe to use as a standalone
/// tile in any list (`TimelineListView`, the AI canvas, etc.).
class TimelineItemTile extends StatelessWidget {
  const TimelineItemTile({
    super.key,
    required this.item,
    this.onTap,
    this.onAcknowledge,
  });
  final TimelineItem item;
  final VoidCallback? onTap;

  /// Invoked when the tile is swiped to acknowledge. Null disables the swipe.
  final VoidCallback? onAcknowledge;

  static const Color _ackGreen = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    // AI chat bubbles are the user's own conversation — nothing to open,
    // acknowledge, or dim. Render them as-is.
    if (item.kind == TimelineItemKind.aiConversation) {
      final role = (item.aiRole == 'user')
          ? AICanvasTileRole.user
          : (item.aiRole == 'system')
              ? AICanvasTileRole.system
              : AICanvasTileRole.assistant;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: AICanvasTile(
          message: item.summary.isNotEmpty ? item.summary : item.title,
          role: role,
          timestamp: _formatTimestamp(item.timestamp),
        ),
      );
    }

    final Widget core =
        (item.kind == TimelineItemKind.aiTask && item.agentRun != null)
            ? _AgentTaskCard(item: item, run: item.agentRun!)
            : _CommCard(item: item, onTap: onTap);

    return _decorate(core);
  }

  /// Applies the acknowledged (dimmed + check) treatment, and wraps a still
  /// un-acknowledged tile in a swipe-to-acknowledge gesture.
  Widget _decorate(Widget core) {
    final acked = item.isAcknowledged;

    Widget tile = core;
    if (acked) {
      tile = Stack(
        children: [
          Opacity(opacity: 0.55, child: core),
          Positioned(
            top: 1,
            right: 18,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle,
                  size: 17, color: _ackGreen),
            ),
          ),
        ],
      );
    }

    if (onAcknowledge == null || !item.supportsAcknowledge || acked) {
      return tile;
    }
    return Dismissible(
      key: ValueKey('ack_${item.id}'),
      direction: DismissDirection.horizontal,
      background: _ackBackground(Alignment.centerLeft),
      secondaryBackground: _ackBackground(Alignment.centerRight),
      confirmDismiss: (_) async {
        onAcknowledge!.call();
        // Keep the tile in place — it re-renders dimmed once the
        // acknowledgement stream updates.
        return false;
      },
      child: tile,
    );
  }

  Widget _ackBackground(Alignment alignment) {
    final isLeft = alignment == Alignment.centerLeft;
    final label =
        item.kind == TimelineItemKind.myTask ? 'Mark done' : 'Mark read';
    const icon = Icon(Icons.check_circle, color: Colors.white, size: 22);
    return Container(
      color: _ackGreen,
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLeft) ...[icon, const SizedBox(width: 8)],
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (!isLeft) ...[const SizedBox(width: 8), icon],
        ],
      ),
    );
  }
}

/// Timeline tile for an agent-task run. Collapsed it shows the task name and
/// where the agent currently is; tap to expand the full step checklist so the
/// user can watch each stage and see exactly where a run stops or fails.
class _AgentTaskCard extends StatefulWidget {
  const _AgentTaskCard({required this.item, required this.run});

  final TimelineItem item;
  final AgentTaskRun run;

  @override
  State<_AgentTaskCard> createState() => _AgentTaskCardState();
}

class _AgentTaskCardState extends State<_AgentTaskCard> {
  bool _expanded = false;

  /// True while a download URL for the agent's file is being resolved.
  bool _openingFile = false;

  static const Set<String> _imageExts = {
    'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic', 'heif',
  };
  static const Set<String> _spreadsheetExts = {
    'xls', 'xlsx', 'csv', 'tsv', 'ods',
  };

  @override
  void initState() {
    super.initState();
    // Auto-expand a run that is actively working so progress is visible
    // without a tap; the user can still collapse it.
    _expanded = widget.run.isRunning;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final run = widget.run;
    final accent = TimelineItemKind.aiTask.accentColor;
    final dateLabel =
        DateFormat.yMMMd().add_jm().format(widget.item.timestamp.toLocal());
    final steps = run.steps;
    final fileOutput = run.output?.file;
    // The card expands to reveal the step checklist and/or the file the
    // agent downloaded, so allow expansion whenever either is present.
    final canExpand = steps.isNotEmpty || fileOutput != null;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Rail(icon: TimelineItemKind.aiTask.icon, accent: accent),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 12, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      dateLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Material(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    elevation: 0,
                    child: InkWell(
                      onTap: canExpand
                          ? () => setState(() => _expanded = !_expanded)
                          : null,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: run.hasFailure
                                ? theme.colorScheme.error
                                    .withValues(alpha: 0.4)
                                : Colors.grey.shade200,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _header(theme, run, canExpand),
                            if (run.isRunning)
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(12),
                                ),
                                child: LinearProgressIndicator(
                                  minHeight: 3,
                                  backgroundColor:
                                      accent.withValues(alpha: 0.12),
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(accent),
                                ),
                              ),
                            if (_expanded && steps.isNotEmpty)
                              _stepList(theme, steps),
                            if (_expanded && fileOutput != null)
                              _downloadedFileTile(theme, fileOutput),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(ThemeData theme, AgentTaskRun run, bool canExpand) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1, right: 10),
            child: _statusIcon(theme, run),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.item.summary,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: run.hasFailure
                        ? theme.colorScheme.error
                        : Colors.grey.shade700,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (canExpand)
            Icon(
              _expanded ? Icons.expand_less : Icons.expand_more,
              size: 22,
              color: Colors.grey.shade500,
            ),
        ],
      ),
    );
  }

  Widget _statusIcon(ThemeData theme, AgentTaskRun run) {
    if (run.isRunning) {
      return SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          valueColor: AlwaysStoppedAnimation<Color>(
            TimelineItemKind.aiTask.accentColor,
          ),
        ),
      );
    }
    if (run.hasFailure) {
      return Icon(Icons.error, size: 20, color: theme.colorScheme.error);
    }
    if (run.isReadyForReview) {
      return const Icon(Icons.check_circle,
          size: 20, color: Color(0xFF2E7D32));
    }
    return Icon(TimelineItemKind.aiTask.icon,
        size: 20, color: TimelineItemKind.aiTask.accentColor);
  }

  Widget _stepList(ThemeData theme, List<AgentTaskRunStep> steps) {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < steps.length; i++)
            _AgentStepRow(step: steps[i], isLast: i == steps.length - 1),
        ],
      ),
    );
  }

  /// Tappable row in the expanded card that opens the file the agent
  /// downloaded, so the user can verify exactly what was retrieved — handy
  /// when a run fails to parse it ("the spreadsheet could not be read").
  Widget _downloadedFileTile(ThemeData theme, AgentTaskRunFile file) {
    final accent = TimelineItemKind.aiTask.accentColor;
    final sizeLabel = file.bytes > 0 ? ' · ${_formatBytes(file.bytes)}' : '';
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
        child: InkWell(
          onTap: _openingFile ? null : () => _openDownloadedFile(file),
          borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
            child: Row(
              children: [
                Icon(_iconForFilename(file.filename), size: 20, color: accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View downloaded file',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: accent,
                        ),
                      ),
                      Text(
                        '${file.filename}$sizeLabel',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (_openingFile)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                else
                  Icon(Icons.open_in_new,
                      size: 18, color: Colors.grey.shade500),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Resolve a download URL for the agent-downloaded file and open it.
  /// PDFs and images preview in-app; everything else (spreadsheets, etc.)
  /// opens in the device's default handler — mirrors `DriveActions.openFile`.
  Future<void> _openDownloadedFile(AgentTaskRunFile file) async {
    if (file.bucket.isEmpty || file.path.isEmpty) {
      SnackbarService.instance.show('This run has no stored file to open.');
      return;
    }
    setState(() => _openingFile = true);
    try {
      final url = await FirebaseStorage.instanceFor(bucket: file.bucket)
          .ref(file.path)
          .getDownloadURL();
      if (!mounted) return;

      final ext = file.filename.split('.').last.toLowerCase();
      if (ext == 'pdf') {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => PdfViewer(pdfUrl: url)),
        );
        return;
      }
      if (_imageExts.contains(ext)) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                title: Text(file.filename),
              ),
              body: ImageViewer(imageUrl: url),
            ),
          ),
        );
        return;
      }

      // Spreadsheets and anything else: hand off to the device's default
      // handler. If the export came back as something other than a real
      // spreadsheet (e.g. an SSO error page), this is where that shows.
      final uri = Uri.tryParse(url);
      if (uri == null || !await canLaunchUrl(uri)) {
        SnackbarService.instance.show('Could not open "${file.filename}".');
        return;
      }
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      SnackbarService.instance.show('Could not open the file: $e');
    } finally {
      if (mounted) setState(() => _openingFile = false);
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(0)} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }

  IconData _iconForFilename(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    if (ext == 'pdf') return Icons.picture_as_pdf_outlined;
    if (_spreadsheetExts.contains(ext)) return Icons.table_chart_outlined;
    if (_imageExts.contains(ext)) return Icons.image_outlined;
    return Icons.insert_drive_file_outlined;
  }
}

/// One row in the expanded agent-task step checklist.
class _AgentStepRow extends StatelessWidget {
  const _AgentStepRow({required this.step, required this.isLast});

  final AgentTaskRunStep step;
  final bool isLast;

  static const _green = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = theme.colorScheme.error;
    final muted = Colors.grey.shade400;

    final bool dim = step.isPending;
    final labelColor = dim ? Colors.grey.shade500 : Colors.grey.shade900;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 8 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1, right: 10),
            child: _icon(error, muted),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  step.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: labelColor,
                    fontWeight:
                        step.isRunning ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                if (step.detail != null && step.detail!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      step.detail!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                if (step.error != null && step.error!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      step.error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: error,
                        height: 1.3,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _icon(Color error, Color muted) {
    switch (step.status) {
      case AgentTaskStepStatus.running:
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2.2),
        );
      case AgentTaskStepStatus.done:
        return const Icon(Icons.check_circle, size: 16, color: _green);
      case AgentTaskStepStatus.failed:
        return Icon(Icons.cancel, size: 16, color: error);
      case AgentTaskStepStatus.skipped:
        return Icon(Icons.remove_circle_outline, size: 16, color: muted);
      case AgentTaskStepStatus.pending:
      case AgentTaskStepStatus.unknown:
        return Icon(Icons.radio_button_unchecked, size: 16, color: muted);
    }
  }
}

/// Expandable bundle for a group of AI conversation turns sharing the same
/// `conversationId`. Mirrors the agent-task card pattern: collapsed shows
/// the latest turn as a preview, expanded shows every turn as the same
/// chat-bubble widget the canvas uses.
class _AiConversationCard extends ConsumerStatefulWidget {
  const _AiConversationCard({super.key, required this.items});

  /// Turns in source order (newest-first from the unified timeline). The
  /// card reverses these when rendering the expanded bubble list so the
  /// reader scrolls chronologically top-to-bottom.
  final List<TimelineItem> items;

  @override
  ConsumerState<_AiConversationCard> createState() =>
      _AiConversationCardState();
}

class _AiConversationCardState extends ConsumerState<_AiConversationCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = widget.items;
    final newest = items.first;
    final accent = TimelineItemKind.aiConversation.accentColor;
    final dateLabel =
        DateFormat.yMMMd().add_jm().format(newest.timestamp.toLocal());
    final userTurns = items.where((i) => i.aiRole == 'user').length;
    final summary = newest.summary.trim().isNotEmpty
        ? newest.summary.trim()
        : newest.title.trim();

    final messagesLabel =
        userTurns <= 1 ? '1 message' : '$userTurns messages';
    final headerSubtitle = messagesLabel;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Rail(icon: TimelineItemKind.aiConversation.icon, accent: accent),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 12, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      dateLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Material(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    elevation: 0,
                    child: InkWell(
                      onTap: () => setState(() => _expanded = !_expanded),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding:
                                        const EdgeInsets.only(top: 1, right: 10),
                                    child: Icon(
                                      TimelineItemKind.aiConversation.icon,
                                      size: 20,
                                      color: accent,
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'AI Conversation',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodyLarge
                                              ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          headerSubtitle,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          summary,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                            color: Colors.grey.shade700,
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    _expanded
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                    size: 22,
                                    color: Colors.grey.shade500,
                                  ),
                                ],
                              ),
                            ),
                            if (_expanded)
                              Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(
                                        color: Colors.grey.shade200),
                                  ),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    for (final turn in items.reversed)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        child: AICanvasTile(
                                          message: turn.summary.isNotEmpty
                                              ? turn.summary
                                              : turn.title,
                                          role: turn.aiRole == 'user'
                                              ? AICanvasTileRole.user
                                              : turn.aiRole == 'system'
                                                  ? AICanvasTileRole.system
                                                  : AICanvasTileRole.assistant,
                                          timestamp: DateFormat.jm()
                                              .format(turn.timestamp.toLocal()),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommCard extends StatelessWidget {
  const _CommCard({required this.item, this.onTap});
  final TimelineItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = item.kind.accentColor;
    final dateLabel = DateFormat.yMMMd().add_jm().format(item.timestamp.toLocal());

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Rail(icon: item.kind.icon, accent: accent),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 12, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      dateLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Material(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    elevation: 0,
                    child: InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: _body(theme),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(ThemeData theme) {
    final rawTitle = item.title.trim();
    final sender = item.senderLabel?.trim() ?? '';
    final hasSender = sender.isNotEmpty;

    // For 1:1 threads the conversation title is a generic placeholder, so the
    // sender is the most useful heading; otherwise the title (subject / task
    // name / call type) leads and the sender shows on its own "from" line.
    final titleIsGeneric = rawTitle.isEmpty || rawTitle == 'Conversation';
    final heading = (titleIsGeneric && hasSender) ? sender : rawTitle;
    final showFrom = hasSender && sender != heading;
    final showDivider = heading.isNotEmpty && item.summary.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (heading.isNotEmpty)
          Text(
            heading,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        // Who it's from — shown on every node type that records a sender
        // (text last-sender, email from, call participants, note/board
        // author, completed-by), so the source is always visible.
        if (showFrom) ...[
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.person_outline, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  sender,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (showDivider) Divider(height: 16, color: Colors.grey.shade100),
        if (item.summary.isNotEmpty)
          Text(
            item.summary,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade800,
              height: 1.35,
            ),
          ),
        if (item.subline != null && item.subline!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            item.subline!,
            style: theme.textTheme.bodySmall?.copyWith(
              fontStyle: FontStyle.italic,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ],
    );
  }
}

String _formatTimestamp(DateTime t) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final tDay = DateTime(t.year, t.month, t.day);
  if (tDay == today) return DateFormat.jm().format(t);
  final daysAgo = today.difference(tDay).inDays;
  if (daysAgo == 1) return 'Yesterday';
  if (daysAgo < 7) return DateFormat.E().format(t);
  if (tDay.year == today.year) return DateFormat.MMMd().format(t);
  return DateFormat.yMMMd().format(t);
}

class _Rail extends StatelessWidget {
  const _Rail({required this.icon, required this.accent});
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final lineColor = Colors.grey.shade300;
    return SizedBox(
      width: 44,
      child: Column(
        children: [
          Expanded(child: Container(width: 2, color: lineColor)),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: lineColor, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, size: 16, color: accent),
          ),
          Expanded(child: Container(width: 2, color: lineColor)),
        ],
      ),
    );
  }
}
