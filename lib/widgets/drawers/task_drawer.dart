// lib/widgets/drawers/task_drawer.dart
// Left-side task drawer for task tile actions.
//
// Three stacked sections:
//  • Contributors  – active + past contributors, shown only when at least one
//    exists. Replaces the old "Active Contributors" entry tile in the Task
//    section so the info is one peek away instead of a drill-down.
//  • Task          – history, notes, alerts, reports, timer.
//  • Communication – Voice / Video / Text / Email. Each entry fans out to
//    every task contributor (active now, or former on a closed-out task)
//    in a single tap, so the caller never picks recipients by hand.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kleenops_admin/theme/palette.dart';

class TaskDrawer extends StatelessWidget {
  const TaskDrawer({
    super.key,
    required this.onHistoryTap,
    this.activeContributors,
    this.pastContributors,
    this.onNoteTap,
    this.onServiceRequestTap,
    this.onVoiceAlertTap,
    this.onCommunicationTap,
    this.onVideoConferenceTap,
    this.onTextTap,
    this.onEmailTap,
    this.onQualityReportTap,
    this.onAlertFlagTap,
    this.onTimerTap,
    this.timerLabel = 'Timer',
  });

  final VoidCallback onHistoryTap;

  /// Currently-active contributors keyed by memberId. Values are
  /// `{name, startTime, ...}` maps. Surfaces in the top "Contributors" section.
  final Map<String, dynamic>? activeContributors;

  /// Past contributors keyed by memberId. Values are
  /// `{name?, startTime, endTime, duration, ...}` maps. Same section as active.
  final Map<String, dynamic>? pastContributors;

  final VoidCallback? onNoteTap;
  final VoidCallback? onServiceRequestTap;
  final VoidCallback? onVoiceAlertTap;

  /// Voice call linking every task contributor at once.
  final VoidCallback? onCommunicationTap;

  /// Video call linking every task contributor at once.
  final VoidCallback? onVideoConferenceTap;

  /// Group text addressed to every task contributor.
  final VoidCallback? onTextTap;

  /// Email addressed to every task contributor.
  final VoidCallback? onEmailTap;

  final VoidCallback? onQualityReportTap;
  final VoidCallback? onAlertFlagTap;
  final VoidCallback? onTimerTap;
  final String timerLabel;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final statusBarH = media.padding.top;
    final bottomInset = media.padding.bottom;
    final palette = AppPaletteScope.of(context);
    final borderColor = palette.primary1;
    const backgroundColor = Colors.white;
    const titleColor = Colors.black;

    Widget gradientDivider() {
      return Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.transparent, Colors.grey.shade300],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
      );
    }

    VoidCallback wrap(VoidCallback cb) {
      return () {
        Navigator.of(context).pop();
        cb();
      };
    }

    Widget sectionHeader(String label) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                ),
              ),
            ),
          ),
          Divider(height: 3, color: Colors.grey.shade300),
        ],
      );
    }

    // One tappable row plus its trailing gradient divider, emitted only
    // when [onTap] is wired.
    List<Widget> entry(IconData icon, String label, VoidCallback? onTap) {
      if (onTap == null) return const <Widget>[];
      return [
        _tile(
          context,
          icon: icon,
          label: label,
          onTap: wrap(onTap),
          iconColor: borderColor,
        ),
        gradientDivider(),
      ];
    }

    final taskTiles = <Widget>[
      ...entry(Icons.history_outlined, 'History', onHistoryTap),
      ...entry(Icons.note_alt, 'Task Notes', onNoteTap),
      ...entry(Icons.warning_amber_outlined, 'Task Alert', onVoiceAlertTap),
      ...entry(Icons.assignment_add, 'Task Request', onServiceRequestTap),
      ...entry(Icons.flag, 'Flag', onAlertFlagTap),
      ...entry(Icons.timer_outlined, timerLabel, onTimerTap),
      ...entry(Icons.content_paste_search, 'Quality Report', onQualityReportTap),
    ];

    // Communication entries each link every task contributor in one tap.
    final commTiles = <Widget>[
      ...entry(Icons.record_voice_over, 'Voice Call', onCommunicationTap),
      ...entry(Icons.video_camera_front, 'Video Call', onVideoConferenceTap),
      ...entry(Icons.chat, 'Text', onTextTap),
      ...entry(Icons.email, 'Email', onEmailTap),
    ];

    final contributorTiles = _buildContributorTiles(borderColor);

    return Drawer(
      shape: RoundedRectangleBorder(
        side: BorderSide(width: 2, color: borderColor),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Column(
          children: [
            SizedBox(height: statusBarH),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (contributorTiles.isNotEmpty) ...[
                      sectionHeader('Contributors'),
                      ...contributorTiles,
                    ],
                    sectionHeader('Task'),
                    ...taskTiles,
                    if (commTiles.isNotEmpty) ...[
                      sectionHeader('Communication'),
                      ...commTiles,
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(height: bottomInset),
          ],
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color iconColor,
  }) {
    const textStyle = TextStyle(color: Colors.black, fontSize: 16);
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(label, style: textStyle),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: onTap,
    );
  }

  /// Builds the read-only contributor rows that lead the drawer. Active
  /// contributors are listed first (with elapsed time since `startTime`);
  /// past contributors follow, skipping anyone currently active so a person
  /// who left and rejoined is not shown twice. Empty list = no section.
  List<Widget> _buildContributorTiles(Color iconColor) {
    final active = activeContributors ?? const <String, dynamic>{};
    final past = pastContributors ?? const <String, dynamic>{};
    if (active.isEmpty && past.isEmpty) return const <Widget>[];

    final now = DateTime.now();
    final tiles = <Widget>[];

    final activeEntries = active.entries.toList()
      ..sort((a, b) {
        final av = (a.value as Map?)?.cast<String, dynamic>() ?? const {};
        final bv = (b.value as Map?)?.cast<String, dynamic>() ?? const {};
        final at = av['startTime'] as Timestamp?;
        final bt = bv['startTime'] as Timestamp?;
        if (at == null && bt == null) return 0;
        if (at == null) return 1;
        if (bt == null) return -1;
        return at.compareTo(bt);
      });

    for (final entry in activeEntries) {
      final v = (entry.value as Map?)?.cast<String, dynamic>() ?? const {};
      final ts = v['startTime'] as Timestamp?;
      final elapsed = ts != null ? now.difference(ts.toDate()) : null;
      tiles.add(_contributorRow(
        icon: Icons.groups,
        iconColor: iconColor,
        name: _displayName(v),
        subtitle: 'Active${elapsed != null ? ' · ${_formatDuration(elapsed)}' : ''}',
      ));
      tiles.add(_gradientDivider());
    }

    final pastEntries = past.entries
        .where((e) => !active.containsKey(e.key))
        .toList()
      ..sort((a, b) {
        final av = (a.value as Map?)?.cast<String, dynamic>() ?? const {};
        final bv = (b.value as Map?)?.cast<String, dynamic>() ?? const {};
        final at = av['endTime'] as Timestamp?;
        final bt = bv['endTime'] as Timestamp?;
        if (at == null && bt == null) return 0;
        if (at == null) return 1;
        if (bt == null) return -1;
        return bt.compareTo(at);
      });

    for (final entry in pastEntries) {
      final v = (entry.value as Map?)?.cast<String, dynamic>() ?? const {};
      final minutes = (v['duration'] as num?)?.toInt();
      tiles.add(_contributorRow(
        icon: Icons.history_outlined,
        iconColor: iconColor,
        name: _displayName(v),
        subtitle: 'Past${minutes != null && minutes > 0 ? ' · ${_formatMinutes(minutes)}' : ''}',
      ));
      tiles.add(_gradientDivider());
    }

    return tiles;
  }

  Widget _contributorRow({
    required IconData icon,
    required Color iconColor,
    required String name,
    required String subtitle,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(name, style: const TextStyle(color: Colors.black, fontSize: 16)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _gradientDivider() {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.transparent, Colors.grey.shade300],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
    );
  }

  String _displayName(Map<String, dynamic> v) {
    final raw = v['name'];
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    return 'Unknown';
  }

  String _formatDuration(Duration d) =>
      _formatMinutes(d.inMinutes < 0 ? 0 : d.inMinutes);

  String _formatMinutes(int total) {
    final h = total ~/ 60;
    final m = total % 60;
    if (h <= 0) return '${m}m';
    return '${h}h ${m}m';
  }

  static void show(
    BuildContext context, {
    required VoidCallback onHistoryTap,
    Map<String, dynamic>? activeContributors,
    Map<String, dynamic>? pastContributors,
    VoidCallback? onNoteTap,
    VoidCallback? onServiceRequestTap,
    VoidCallback? onVoiceAlertTap,
    VoidCallback? onCommunicationTap,
    VoidCallback? onVideoConferenceTap,
    VoidCallback? onTextTap,
    VoidCallback? onEmailTap,
    VoidCallback? onQualityReportTap,
    VoidCallback? onAlertFlagTap,
    VoidCallback? onTimerTap,
    String timerLabel = 'Timer',
  }) {
    showGeneralDialog(
      context: context,
      barrierLabel: 'Task Drawer',
      barrierDismissible: true,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, animation, secondaryAnimation, child) {
        final offsetAnimation = Tween<Offset>(
          begin: const Offset(-1, 0),
          end: Offset.zero,
        ).animate(animation);
        return SlideTransition(
          position: offsetAnimation,
          child: Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 304,
              child: Material(
                color: Colors.transparent,
                child: TaskDrawer(
                  onHistoryTap: onHistoryTap,
                  activeContributors: activeContributors,
                  pastContributors: pastContributors,
                  onNoteTap: onNoteTap,
                  onServiceRequestTap: onServiceRequestTap,
                  onVoiceAlertTap: onVoiceAlertTap,
                  onCommunicationTap: onCommunicationTap,
                  onVideoConferenceTap: onVideoConferenceTap,
                  onTextTap: onTextTap,
                  onEmailTap: onEmailTap,
                  onQualityReportTap: onQualityReportTap,
                  onAlertFlagTap: onAlertFlagTap,
                  onTimerTap: onTimerTap,
                  timerLabel: timerLabel,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
