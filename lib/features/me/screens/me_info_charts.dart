//  me_info_charts.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/widgets/charts/column_chart.dart';
import 'package:shared_widgets/charts/chart_filter_pills.dart';
import 'package:shared_widgets/tabs/lazy_tab_view.dart';
import 'package:shared_widgets/tabs/standard_tab.dart';

class MeInfoChartsContent extends ConsumerStatefulWidget {
  /// Optional override to show another user’s stats
  final DocumentReference<Map<String, dynamic>>? employeeRef;

  const MeInfoChartsContent({
    super.key,
    this.employeeRef,
  });

  @override
  _MeInfoChartsContentState createState() => _MeInfoChartsContentState();
}

class _MeInfoChartsContentState extends ConsumerState<MeInfoChartsContent> {
  ChartGroupBy _groupBy = ChartGroupBy.day;
  ChartAperture _aperture = ChartAperture.week;

  @override
  Widget build(BuildContext context) {
    final companyRef = ref.watch(companyIdProvider).value;
    if (companyRef == null) {
      return const Center(child: Text('No company selected'));
    }

    final memberAsync = ref.watch(memberDocRefProvider);
    final memberRef = widget.employeeRef ?? memberAsync.value;
    if (widget.employeeRef == null && memberAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (memberRef == null) {
      return const Center(child: Text('Member profile not found'));
    }
    final mediaQuery = MediaQuery.of(context);
    final bool hideChrome = false;
    final bottomInset = mediaQuery.viewPadding.bottom;
    final bottomPadding = (bottomInset > 0 ? bottomInset : 24.0) + 24.0;

    return Container(
      color: Colors.white,
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            if (!hideChrome)
              StandardTabBar(
                isScrollable: true,
                dividerColor: Colors.grey[300],
                indicatorColor: Theme.of(context).primaryColor,
                indicatorWeight: 3,
                labelColor: Colors.black,
                unselectedLabelColor: Colors.grey[600],
                tabs: const [
                  Tab(text: 'Dependability'),
                  Tab(text: 'Contribution'),
                ],
              ),
            Expanded(
              child: Builder(
                builder: (context) => LazyTabView(
                  controller: DefaultTabController.of(context),
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    ListView(
                      padding:
                          EdgeInsets.fromLTRB(12, 12, 12, bottomPadding),
                      children: [
                        _buildFilterPills(),
                        _buildHoursVsScheduled(companyRef, memberRef),
                      ],
                    ),
                    ListView(
                      padding:
                          EdgeInsets.fromLTRB(12, 12, 12, bottomPadding),
                      children: [
                        _buildFilterPills(),
                        _buildContributionVsWorked(companyRef, memberRef),
                      ],
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

  Widget _buildFilterPills() {
    return ChartFilterPills(
      groupBy: _groupBy,
      aperture: _aperture,
      onGroupByChanged: (g) => setState(() => _groupBy = g),
      onApertureChanged: (a) => setState(() => _aperture = a),
    );
  }

  Widget _buildHoursVsScheduled(
    DocumentReference<Map<String, dynamic>> companyRef,
    DocumentReference<Map<String, dynamic>> memberRef,
  ) {
    return FutureBuilder<List<ChartData>>(
      key: ValueKey('hvs-${_groupBy.name}-${_aperture.name}'),
      future: _loadHoursVsScheduled(
          companyRef, memberRef, _groupBy, _aperture),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error: \${snap.error}'));
        }
        final data = snap.data ?? const [];
        final hasPct = data.any((d) => d.percent != null);
        return Container(
          height: 300,
          margin: const EdgeInsets.only(bottom: 24),
          child: ColumnChart(
            data: data,
            column1: 'Worked',
            column2: 'Scheduled',
            percentLabel: hasPct ? 'Completion %' : null,
          ),
        );
      },
    );
  }

  Widget _buildContributionVsWorked(
    DocumentReference<Map<String, dynamic>> companyRef,
    DocumentReference<Map<String, dynamic>> memberRef,
  ) {
    return FutureBuilder<List<ChartData>>(
      key: ValueKey('cvw-${_groupBy.name}-${_aperture.name}'),
      future: _loadContributionVsWorked(
          companyRef, memberRef, _groupBy, _aperture),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error: \${snap.error}'));
        }
        final data = snap.data ?? const [];
        final allZero = data.isEmpty || data.every((d) => d.actual == 0 && d.scheduled == 0);
        if (allZero) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('No contribution data')),
          );
        }
        final hasPct = data.any((d) => d.percent != null);
        return SizedBox(
          height: 300,
          child: ColumnChart(
            data: data,
            column1: 'Worked',
            column2: 'Contribution',
            percentLabel: hasPct ? 'Contribution %' : null,
          ),
        );
      },
    );
  }

  Future<List<ChartData>> _loadHoursVsScheduled(
    DocumentReference<Map<String, dynamic>> companyRef,
    DocumentReference<Map<String, dynamic>> memberRef,
    ChartGroupBy groupBy,
    ChartAperture aperture,
  ) async {
    final cutoff = chartCutoffForAperture(aperture);
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('timeline')
        .where('memberId', isEqualTo: memberRef);
    if (cutoff != null) {
      q = q.where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff));
    }
    final snap = await q.get();
    final worked = <DateTime, double>{};
    final scheduled = <DateTime, double>{};
    final now = DateTime.now();
    final scheduleCutoff = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    for (final doc in snap.docs) {
      final data = doc.data();
      final String? cat = (data['timelineCategory'] as String?) ??
          ((data['timelineCategoryId'] is DocumentReference)
              ? (data['timelineCategoryId'] as DocumentReference).id
              : null);
      if (cat == null) continue;
      final startTs = data['startTime'] as Timestamp?;
      if (startTs == null) continue;
      final endTs = data['endTime'] as Timestamp?;
      final start = startTs.toDate();
      final end = endTs?.toDate();
      final bucket = chartBucketForDate(start, groupBy);

      // Prefer explicit duration; fallback to end-start difference.
      double minutes = (data['duration'] is num) ? (data['duration'] as num).toDouble() : 0.0;
      if (minutes <= 0 && end != null) {
        minutes = end.difference(start).inMinutes.toDouble();
      }
      final hrs = minutes / 60.0;

      if (cat == 'X8yZRs8e8xXyHPl4VNAN') {
        worked[bucket] = (worked[bucket] ?? 0) + hrs;
      } else if (cat == 'ZLAjjDKp3hgRankr4sQ8') {
        // Ignore scheduled entries beyond today so the chart aligns with worked hours.
        if (start.isBefore(scheduleCutoff)) {
          scheduled[bucket] = (scheduled[bucket] ?? 0) + hrs;
        }
      }
    }
    return _toChartData(numerator: worked, denominator: scheduled);
  }

  Future<List<ChartData>> _loadContributionVsWorked(
    DocumentReference<Map<String, dynamic>> companyRef,
    DocumentReference<Map<String, dynamic>> memberRef,
    ChartGroupBy groupBy,
    ChartAperture aperture,
  ) async {
    final cutoff = chartCutoffForAperture(aperture);
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('timeline')
        .where('memberId', isEqualTo: memberRef);
    if (cutoff != null) {
      q = q.where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff));
    }
    final snap = await q.get();
    final contrib = <DateTime, double>{};
    final worked = <DateTime, double>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final String? cat = (data['timelineCategory'] as String?) ??
          ((data['timelineCategoryId'] is DocumentReference)
              ? (data['timelineCategoryId'] as DocumentReference).id
              : null);
      if (cat == null) continue;
      final startTs = data['startTime'] as Timestamp?;
      if (startTs == null) continue;
      final endTs = data['endTime'] as Timestamp?;
      final bucket = chartBucketForDate(startTs.toDate(), groupBy);

      // Prefer explicit duration; fallback to end-start difference.
      double minutes = (data['duration'] is num) ? (data['duration'] as num).toDouble() : 0.0;
      if (minutes <= 0 && endTs != null) {
        minutes = endTs.toDate().difference(startTs.toDate()).inMinutes.toDouble();
      }
      final hrs = minutes / 60.0;

      if (cat == 'X8yZRs8e8xXyHPl4VNAN') {
        worked[bucket] = (worked[bucket] ?? 0) + hrs;
      } else if (cat == 'E2HMUuMUUl4Alttuweba') {
        contrib[bucket] = (contrib[bucket] ?? 0) + hrs;
      }
    }
    // build ChartData so actual=worked, scheduled=contrib, percent=contrib/worked
    final buckets = {...worked.keys, ...contrib.keys}.toList()..sort();
    bool hasPct = false;
    final list = buckets.map((b) {
      final w = worked[b] ?? 0;
      final c = contrib[b] ?? 0;
      double? pct;
      if (w > 0 && c > 0) {
        pct = (c / w) * 100;
        hasPct = true;
      }
      return ChartData(b, w, c, percent: pct);
    }).toList();
    if (!hasPct) {
      return list.map((d) => ChartData(d.period, d.actual, d.scheduled)).toList();
    }
    return list;
  }

  List<ChartData> _toChartData({
    required Map<DateTime, double> numerator,
    required Map<DateTime, double> denominator,
  }) {
    final buckets = {...numerator.keys, ...denominator.keys}.toList()..sort();
    bool hasPct = false;
    final list = buckets.map((b) {
      final num = numerator[b] ?? 0;
      final den = denominator[b] ?? 0;
      double? pct;
      if (num > 0 && den > 0) {
        pct = (num / den) * 100;
        hasPct = true;
      }
      return ChartData(b, num, den, percent: pct);
    }).toList();
    if (!hasPct) {
      return list.map((d) => ChartData(d.period, d.actual, d.scheduled)).toList();
    }
    return list;
  }
}
