// lib/features/engagement/widgets/engagement_funnel_view.dart
//
// Reusable onboarding-funnel visualization, extracted from the old dashboard
// `_OnboardingFunnelPanel` so the Mobile and Web engagement tabs can each
// render the funnel scoped to their platform. Pure presentation: hand it a
// [FunnelSlice] (overall, platform, or cohort) and it draws the staged drop-off
// bars + biggest-drop callout + section breakdown + per-screen dwell table.

import 'package:flutter/material.dart';
import 'package:kleenops_admin/services/admin_firebase_service.dart';

class EngagementFunnelView extends StatelessWidget {
  const EngagementFunnelView({
    super.key,
    required this.slice,
    this.showSectionBreakdown = true,
    this.showScreenTime = true,
  });

  /// The slice to render — `funnel.sliceFor('web' | 'mobile')` or the overall.
  final FunnelSlice slice;
  final bool showSectionBreakdown;
  final bool showScreenTime;

  /// Ordered (stageKey, label) rows shown in the funnel. Keys match the
  /// snake_case event names from the client AnalyticsService.
  static const _funnelRows = <List<String>>[
    ['registration_fork_viewed', 'Registration fork viewed'],
    ['registration_fork_picked', 'Picked a fork option'],
    ['business_type_viewed', 'Business type viewed'],
    ['business_type_picked', 'Picked a business type'],
    ['cleaning_setup_viewed', 'Cleaning setup viewed'],
    ['cleaning_setup_company_named', 'Named the company'],
    ['welcome_carousel_viewed', 'Welcome carousel viewed'],
    ['welcome_carousel_completed', 'Welcome carousel completed'],
    ['setup_dashboard_viewed', 'Setup dashboard viewed'],
    ['setup_section_opened', 'Opened a setup section'],
    ['setup_section_completed', 'Completed a setup section'],
    ['setup_review_reached', 'Reached review & pay'],
    ['setup_paid', 'Paid'],
    ['onboarding_complete', 'Onboarding complete'],
  ];

  /// Ordered stage keys (in funnel order) — shared by callers that compute
  /// conversion / biggest-drop over the same stages (cohort + experiment cards).
  static List<String> get funnelStageKeys =>
      _funnelRows.map((p) => p[0]).toList();

  /// Human label for a stage key, or the key itself if unknown.
  static String labelFor(String stageKey) {
    for (final p in _funnelRows) {
      if (p[0] == stageKey) return p[1];
    }
    return stageKey;
  }

  @override
  Widget build(BuildContext context) {
    final rows = _funnelRows
        .map((pair) => _FunnelRowData(
              label: pair[1],
              count: slice.stageCounts[pair[0]] ?? 0,
            ))
        .toList();

    final totalEvents = rows.fold<int>(0, (s, r) => s + r.count);
    if (totalEvents == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        child: Text(
          'No funnel events for this platform yet. Once users move through the '
          'registration + setup flow here, the staged drop-off appears.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
      );
    }

    final maxCount = rows.fold<int>(0, (m, r) => r.count > m ? r.count : m);
    final firstCount = rows.isNotEmpty ? rows.first.count : 0;

    // Biggest absolute drop between consecutive stages — flags where users
    // abandon the flow.
    int biggestDropIndex = -1;
    int biggestDrop = 0;
    for (var i = 1; i < rows.length; i++) {
      final drop = rows[i - 1].count - rows[i].count;
      if (drop > biggestDrop) {
        biggestDrop = drop;
        biggestDropIndex = i;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < rows.length; i++)
          _FunnelRow(
            label: rows[i].label,
            count: rows[i].count,
            relativeToMax: maxCount == 0 ? 0 : rows[i].count / maxCount,
            percentOfTop: firstCount == 0 ? 0 : rows[i].count / firstCount,
            isBiggestDrop: i == biggestDropIndex && biggestDrop > 0,
          ),
        if (showSectionBreakdown) ...[
          const SizedBox(height: 16),
          _SectionBreakdown(title: 'Section opens', data: slice.sectionOpened),
          const SizedBox(height: 8),
          _SectionBreakdown(
              title: 'Section completions', data: slice.sectionCompleted),
        ],
        if (showScreenTime) ...[
          const SizedBox(height: 16),
          _ScreenTimeMiniTable(
            averageMs: slice.screenTimeAverageMs,
            sampleCount: slice.screenTimeSampleCount,
          ),
        ],
      ],
    );
  }
}

class _FunnelRowData {
  const _FunnelRowData({required this.label, required this.count});
  final String label;
  final int count;
}

class _FunnelRow extends StatelessWidget {
  const _FunnelRow({
    required this.label,
    required this.count,
    required this.relativeToMax,
    required this.percentOfTop,
    required this.isBiggestDrop,
  });
  final String label;
  final int count;
  final double relativeToMax;
  final double percentOfTop;
  final bool isBiggestDrop;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          isBiggestDrop ? Colors.red.shade700 : Colors.black87,
                      fontWeight:
                          isBiggestDrop ? FontWeight.w600 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isBiggestDrop)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      'biggest drop',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 32,
            child: Text(
              '$count',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: relativeToMax,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(
                  isBiggestDrop
                      ? Colors.red.shade400
                      : const Color(0xFF002E5D),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 36,
            child: Text(
              '${(percentOfTop * 100).round()}%',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionBreakdown extends StatelessWidget {
  const _SectionBreakdown({required this.title, required this.data});
  final String title;
  final Map<String, int> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final entries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: entries.map((e) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                '${e.key} · ${e.value}',
                style: const TextStyle(fontSize: 11),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _ScreenTimeMiniTable extends StatelessWidget {
  const _ScreenTimeMiniTable({
    required this.averageMs,
    required this.sampleCount,
  });
  final Map<String, int> averageMs;
  final Map<String, int> sampleCount;

  @override
  Widget build(BuildContext context) {
    if (averageMs.isEmpty) return const SizedBox.shrink();
    final entries = averageMs.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Avg time on screen (top 5)',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        for (final entry in top)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    entry.key,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatMs(entry.value),
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 6),
                Text(
                  '(n=${sampleCount[entry.key] ?? 0})',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _formatMs(int ms) {
    if (ms < 1000) return '${ms}ms';
    final seconds = ms / 1000;
    if (seconds < 60) return '${seconds.toStringAsFixed(1)}s';
    final minutes = seconds / 60;
    return '${minutes.toStringAsFixed(1)}m';
  }
}
