// lib/features/engagement/screens/engagement_platform_screen.dart
//
// One screen, two instances: the Mobile and Web tabs of the Engagement section.
// Everything here is scoped to a single platform ('web' | 'mobile') so the
// owner can answer, per platform:
//   • Where do companies get stuck setting up?  → onboarding funnel + drop-off
//   • Where do people spend their time?          → time-in-section bars
//   • How engaged are they, on average?          → daily sessions + avg length
//   • Do new vs existing users behave differently? → cohort comparison
//   • Which onboarding variant converts better?  → A/B experiment buckets
//
// Reads the rolled-up `funnelTotals/onboarding` + `engagementTotals/sections`
// docs the cloud function writes; the refresh control recomputes both on demand
// for a chosen window. This is behavioral analytics — distinct from the Sales
// section, which tracks what companies buy.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:kleenops_admin/features/engagement/widgets/engagement_funnel_view.dart';
import 'package:kleenops_admin/services/admin_firebase_service.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';

class EngagementPlatformScreen extends StatefulWidget {
  const EngagementPlatformScreen({
    super.key,
    required this.platform,
    required this.title,
  });

  /// 'web' or 'mobile' — matches the rollup's `byPlatform` keys.
  final String platform;
  final String title;

  @override
  State<EngagementPlatformScreen> createState() =>
      _EngagementPlatformScreenState();
}

class _EngagementPlatformScreenState extends State<EngagementPlatformScreen> {
  final _svc = AdminFirebaseService.instance;
  int _windowDays = 7;
  bool _refreshing = false;

  static const _windowOptions = [7, 30, 90];

  Future<void> _refresh(int windowDays) async {
    if (_refreshing) return;
    setState(() {
      _refreshing = true;
      _windowDays = windowDays;
    });
    try {
      await _svc.recomputeFunnelNow(windowDays: windowDays);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Refresh failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Widget _wrapCanvas(Widget child) {
    return StandardCanvas(
      child: SafeArea(
        top: true,
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(child: child),
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: CanvasTopBookend(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bottomInset = 16.0;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: null,
      drawer: const UserDrawer(),
      body: _wrapCanvas(
        ListView(
          padding: EdgeInsets.fromLTRB(12, 16, 12, bottomInset),
          children: [
            _windowControls(),
            const SizedBox(height: 12),
            _funnelCard(),
            const SizedBox(height: 12),
            _sectionTimeCard(),
            const SizedBox(height: 12),
            _dailyCard(),
            const SizedBox(height: 12),
            _cohortCard(),
            const SizedBox(height: 12),
            _experimentsCard(),
          ],
        ),
      ),
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final menuSections = MenuDrawerSections(
            actions: [
              ContentMenuItem(
                icon: Icons.home_outlined,
                label: 'Engagement Home',
                onTap: () => context.push(AppRoutePaths.engagementHome),
              ),
              ContentMenuItem(
                icon: Icons.receipt_long_outlined,
                label: 'Reports',
                onTap: () => context.push(AppRoutePaths.engagementReports),
              ),
            ],
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DetailsAppBar(
                title: 'Engagement · ${widget.title}',
                menuSections: menuSections,
              ),
              const HomeNavBarAdapter(),
            ],
          );
        },
      ),
    );
  }

  // ── Window selector + refresh ─────────────────────────────────────────
  Widget _windowControls() {
    return Row(
      children: [
        Icon(Icons.devices, size: 18, color: Colors.grey.shade700),
        const SizedBox(width: 6),
        Text(
          '${widget.title} engagement',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        const Spacer(),
        for (final d in _windowOptions)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: ChoiceChip(
              label: Text('${d}d', style: const TextStyle(fontSize: 12)),
              selected: _windowDays == d,
              onSelected: _refreshing ? null : (_) => _refresh(d),
              visualDensity: VisualDensity.compact,
            ),
          ),
        const SizedBox(width: 6),
        if (_refreshing)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          IconButton(
            tooltip: 'Rebuild now',
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () => _refresh(_windowDays),
          ),
      ],
    );
  }

  // ── Card shell ────────────────────────────────────────────────────────
  Widget _card({
    required String title,
    required IconData icon,
    String? subtitle,
    required Widget child,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: Colors.grey.shade700),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                  ),
                ),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  // ── Funnel (onboarding / Business Setup Wizard) ────────────────────────
  Widget _funnelCard() {
    return StreamBuilder<OnboardingFunnel?>(
      stream: _svc.onboardingFunnelStream(),
      builder: (context, snapshot) {
        final funnel = snapshot.data;
        return _card(
          title: 'Business Setup funnel',
          icon: Icons.timeline,
          subtitle: funnel == null
              ? null
              : 'Last ${funnel.windowDays}d · biggest drop highlighted in red',
          child: funnel == null
              ? const _Empty('No funnel data yet.')
              : EngagementFunnelView(slice: funnel.sliceFor(widget.platform)),
        );
      },
    );
  }

  // ── Time in section ─────────────────────────────────────────────────────
  Widget _sectionTimeCard() {
    return StreamBuilder<EngagementSections?>(
      stream: _svc.engagementSectionsStream(),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final slice = data?.sliceFor(widget.platform) ?? EngagementSlice.empty;
        return _card(
          title: 'Where time is spent',
          icon: Icons.access_time,
          subtitle: slice.sessionCount == 0
              ? null
              : '${slice.sessionCount} sessions · avg '
                  '${_fmtMs(slice.avgSessionMs)} per session',
          child: slice.sections.isEmpty
              ? const _Empty(
                  'No session data yet. Time-in-section appears once users '
                  'navigate the app on this platform.')
              : _SectionBars(sections: slice.sections),
        );
      },
    );
  }

  // ── Daily engagement ────────────────────────────────────────────────────
  Widget _dailyCard() {
    return StreamBuilder<EngagementSections?>(
      stream: _svc.engagementSectionsStream(),
      builder: (context, snapshot) {
        final days = snapshot.data?.perDay ?? const <EngagementDay>[];
        final recent = days.length > 14 ? days.sublist(days.length - 14) : days;
        return _card(
          title: 'Daily engagement',
          icon: Icons.show_chart,
          subtitle: 'Sessions per day on ${widget.title.toLowerCase()}',
          child: recent.isEmpty
              ? const _Empty('No daily sessions yet.')
              : _DailyBars(days: recent, platform: widget.platform),
        );
      },
    );
  }

  // ── New vs existing cohort comparison ──────────────────────────────────
  Widget _cohortCard() {
    return StreamBuilder<OnboardingFunnel?>(
      stream: _svc.onboardingFunnelStream(),
      builder: (context, snapshot) {
        final funnel = snapshot.data;
        final newSlice = funnel?.byCohort['new'];
        final existingSlice = funnel?.byCohort['existing'];
        return _card(
          title: 'New vs existing users',
          icon: Icons.group_outlined,
          subtitle: 'All platforms · where each cohort stalls',
          child: (newSlice == null && existingSlice == null)
              ? const _Empty('No cohort data yet.')
              : Column(
                  children: [
                    _CohortRow(label: 'New', slice: newSlice),
                    const SizedBox(height: 8),
                    _CohortRow(label: 'Existing', slice: existingSlice),
                  ],
                ),
        );
      },
    );
  }

  // ── A/B experiments ─────────────────────────────────────────────────────
  Widget _experimentsCard() {
    return StreamBuilder<OnboardingFunnel?>(
      stream: _svc.onboardingFunnelStream(),
      builder: (context, snapshot) {
        final experiments = snapshot.data?.experiments ?? const {};
        return _card(
          title: 'A/B experiments',
          icon: Icons.science_outlined,
          subtitle: 'Onboarding conversion by Remote Config variant',
          child: experiments.isEmpty
              ? const _Empty(
                  'No active experiments. Define a Remote Config parameter '
                  '(e.g. exp_onboarding) and start a Firebase A/B test to '
                  'compare variants here.')
              : Column(
                  children: experiments.entries
                      .map((e) =>
                          _ExperimentBlock(experimentKey: e.key, variants: e.value))
                      .toList(),
                ),
        );
      },
    );
  }
}

String _fmtMs(int ms) {
  if (ms <= 0) return '0s';
  if (ms < 1000) return '${ms}ms';
  final seconds = ms / 1000;
  if (seconds < 60) return '${seconds.toStringAsFixed(0)}s';
  final minutes = seconds / 60;
  if (minutes < 60) return '${minutes.toStringAsFixed(1)}m';
  return '${(minutes / 60).toStringAsFixed(1)}h';
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
    );
  }
}

/// Horizontal bars of time spent per section, sorted desc.
class _SectionBars extends StatelessWidget {
  const _SectionBars({required this.sections});
  final List<SectionUsage> sections;

  @override
  Widget build(BuildContext context) {
    final maxMs = sections.fold<int>(0, (m, s) => s.totalMs > m ? s.totalMs : m);
    final top = sections.take(10).toList();
    return Column(
      children: [
        for (final s in top)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    s.section,
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: maxMs == 0 ? 0 : s.totalMs / maxMs,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade200,
                      valueColor:
                          const AlwaysStoppedAnimation(Color(0xFF002E5D)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 86,
                  child: Text(
                    '${_fmtMs(s.totalMs)} · ${s.visits}×',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Mini daily session bar chart with avg-session-length annotation.
class _DailyBars extends StatelessWidget {
  const _DailyBars({required this.days, required this.platform});
  final List<EngagementDay> days;
  final String platform;

  @override
  Widget build(BuildContext context) {
    int sessionsOn(EngagementDay d) =>
        d.sessionCountByPlatform[platform] ?? 0;
    final maxSessions =
        days.fold<int>(0, (m, d) => sessionsOn(d) > m ? sessionsOn(d) : m);

    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final d in days)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${sessionsOn(d)}',
                      style:
                          const TextStyle(fontSize: 9, color: Colors.black54),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      height: maxSessions == 0
                          ? 2
                          : 90 * (sessionsOn(d) / maxSessions),
                      decoration: BoxDecoration(
                        color: const Color(0xFF002E5D),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${d.date.month}/${d.date.day}',
                      style:
                          TextStyle(fontSize: 8, color: Colors.grey.shade500),
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

/// One cohort's headline conversion + biggest-drop stage.
class _CohortRow extends StatelessWidget {
  const _CohortRow({required this.label, required this.slice});
  final String label;
  final FunnelSlice? slice;

  @override
  Widget build(BuildContext context) {
    final stages = EngagementFunnelView.funnelStageKeys;
    final counts = slice?.stageCounts ?? const {};
    final started = counts[stages.first] ?? 0;
    final completed = counts['onboarding_complete'] ?? 0;
    final pct = started == 0 ? 0 : (completed / started * 100).round();

    // Biggest drop label.
    String stuckAt = '—';
    int biggestDrop = 0;
    for (var i = 1; i < stages.length; i++) {
      final drop = (counts[stages[i - 1]] ?? 0) - (counts[stages[i]] ?? 0);
      if (drop > biggestDrop) {
        biggestDrop = drop;
        stuckAt = EngagementFunnelView.labelFor(stages[i]);
      }
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$started started → $completed completed ($pct%)',
                    style: const TextStyle(fontSize: 12)),
                Text('Stuck at: $stuckAt',
                    style: TextStyle(
                        fontSize: 11, color: Colors.red.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One experiment's variants, each with a conversion %.
class _ExperimentBlock extends StatelessWidget {
  const _ExperimentBlock({required this.experimentKey, required this.variants});
  final String experimentKey;
  final Map<String, Map<String, int>> variants;

  @override
  Widget build(BuildContext context) {
    final stages = EngagementFunnelView.funnelStageKeys;
    final rows = variants.entries.map((e) {
      final counts = e.value;
      final started = counts[stages.first] ?? 0;
      final completed = counts['onboarding_complete'] ?? 0;
      final pct = started == 0 ? 0 : (completed / started * 100).round();
      return (variant: e.key, started: started, completed: completed, pct: pct);
    }).toList()
      ..sort((a, b) => b.pct.compareTo(a.pct));

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(experimentKey,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(r.variant,
                        style: const TextStyle(fontSize: 12)),
                  ),
                  Text('${r.completed}/${r.started}',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 40,
                    child: Text('${r.pct}%',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
