// lib/features/sales/screens/platform_product_details.dart
//
// Detail screen for a single `platformProduct`, laid out like the scheduling
// routine-task detail screen: a ContainerHeader (name + description) on top,
// then three tabs —
//   • Details — the catalog/pricing ContainerAction cards (edit lives here).
//   • Charts  — usage/sales over time (aperture + group pills) plus, for metered
//               products, the per-company breakdown and per-model bars.
//   • Records — the underlying usage/purchase records generating the numbers,
//               filtered by the same aperture pill.
//
// Metered products chart their per-event usage docs (collectionGroup over
// aiUsage / pstnUsage / plaidUsage); non-metered/à-la-carte products chart their
// platform purchases (collectionGroup over platformPurchase). Charging itself is
// surfaced under Billing and on each company's Services section.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:shared_widgets/charts/chart_filter_pills.dart';
import 'package:shared_widgets/charts/column_chart.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/containers/container_header.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/labels/text_value_inline.dart';
import 'package:shared_widgets/tabs/lazy_tab_view.dart';
import 'package:shared_widgets/tabs/standard_tab.dart';
import 'package:shared_widgets/theme/app_palette.dart';

import '../../../services/admin_firebase_service.dart';
import '../widgets/platform_catalog_body.dart';

/// Map a product usageKey to the per-event subcollection name (for collectionGroup
/// time-series + record queries). Mirrors usageTotals.js writers.
String? _eventCollectionForKey(String usageKey) {
  switch (usageKey) {
    case 'ai':
      return 'aiUsage';
    case 'pstn':
      return 'pstnUsage';
    case 'plaid':
      return 'plaidUsage';
    case 'voice':
      return 'voiceUsage';
    case 'video':
      return 'videoUsage';
    default:
      return null;
  }
}

/// Map a cumulative total field to its per-event field name.
String _eventFieldFor(String usageMetric) {
  switch (usageMetric) {
    case 'totalInputTokens':
      return 'inputTokens';
    case 'totalOutputTokens':
      return 'outputTokens';
    default:
      return usageMetric; // pstn/plaid event fields match the total field name
  }
}

class PlatformProductDetailsScreen extends StatefulWidget {
  const PlatformProductDetailsScreen({super.key, required this.productKey});

  final String productKey;

  @override
  State<PlatformProductDetailsScreen> createState() =>
      _PlatformProductDetailsScreenState();
}

class _PlatformProductDetailsScreenState
    extends State<PlatformProductDetailsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Map a billing-type code to a human label.
  static String _billingLabel(String t) {
    switch (t) {
      case 'recurring':
        return 'Recurring';
      case 'metered':
        return 'Metered';
      case 'one_time':
        return 'One-time';
      default:
        return t.isEmpty ? '—' : t;
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
    final ref =
        FirebaseFirestore.instance.collection('platformProduct').doc(widget.productKey);

    return Scaffold(
      appBar: null,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          DetailsAppBar(title: 'Product'),
          HomeNavBarAdapter(highlightSelected: false),
        ],
      ),
      body: _wrapCanvas(
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: ref.snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(child: Text('Error: ${snap.error}'));
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snap.data!.exists) {
              return const Center(child: Text('Product not found.'));
            }
            final doc = snap.data!;
            final data = doc.data() ?? {};
            final label = data['label'] as String? ?? widget.productKey;
            final description = data['description'] as String? ?? '';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ContainerHeader(
                  showImage: false,
                  titleHeader: 'Name',
                  title: label,
                  descriptionHeader: 'Description',
                  description: description,
                ),
                StandardTabBar(
                  controller: _tabController,
                  isScrollable: true,
                  dividerColor: Colors.grey[300],
                  indicatorWeight: 3,
                  labelColor: Colors.black,
                  unselectedLabelColor: Colors.grey[600],
                  tabs: const [
                    Tab(text: 'Details'),
                    Tab(text: 'Charts'),
                    Tab(text: 'Records'),
                  ],
                ),
                Expanded(
                  child: LazyTabView(
                    controller: _tabController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _DetailsTab(
                        doc: doc,
                        data: data,
                        billingLabel: _billingLabel,
                      ),
                      _ProductChartsTab(productKey: widget.productKey, data: data),
                      _ProductRecordsTab(productKey: widget.productKey, data: data),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Details tab — the catalog/pricing cards (with Edit).
class _DetailsTab extends StatelessWidget {
  const _DetailsTab({
    required this.doc,
    required this.data,
    required this.billingLabel,
  });

  final DocumentSnapshot<Map<String, dynamic>> doc;
  final Map<String, dynamic> data;
  final String Function(String) billingLabel;

  @override
  Widget build(BuildContext context) {
    final priceCents = (data['priceCents'] as num?)?.toInt() ?? 0;
    final costCents = (data['costCents'] as num?)?.toInt() ?? priceCents;
    final interval = data['interval'] as String? ?? '';
    final billingType = data['billingType'] as String? ?? '';
    final provider = (data['provider'] as String?)?.trim() ?? '';
    final hardwired = data['hardwired'] == true;
    final unitLabel = (data['unitLabel'] as String?)?.trim() ?? '';
    final unitPrice = (data['unitPriceCents'] as num?)?.toDouble() ?? 0;
    final perModel = data['perModel'] == true;
    final modelRates =
        (data['modelRatesCents'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};

    final cost = costCents / 100;
    final priceD = priceCents / 100;
    final profit = priceD - cost;
    final markup =
        cost > 0 ? '${(profit / cost * 100).toStringAsFixed(1)}%' : '—';
    final price = '\$${priceD.toStringAsFixed(2)}'
        '${interval.isNotEmpty ? ' / $interval' : ''}';
    final profitColor = profit > 0
        ? Colors.green.shade700
        : (profit < 0 ? Colors.red.shade700 : Colors.grey.shade600);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ContainerActionWidget(
            title: 'Pricing',
            actionText: 'Edit',
            onAction: () => showPlatformProductDialog(context, doc: doc),
            content: Column(
              children: [
                TextValueInline(
                  header: 'Price',
                  value: price,
                  icon: Icons.sell_outlined,
                  boldValue: true,
                ),
                const SizedBox(height: 12),
                TextValueInline(
                  header: 'Base cost',
                  value: '\$${cost.toStringAsFixed(2)}',
                  icon: Icons.account_balance_wallet_outlined,
                ),
                const SizedBox(height: 12),
                TextValueInline(
                  header: 'Markup',
                  value: markup,
                  icon: Icons.trending_up,
                  color: profitColor,
                ),
                const SizedBox(height: 12),
                TextValueInline(
                  header: 'Profit',
                  value: '\$${profit.toStringAsFixed(2)}',
                  icon: Icons.savings_outlined,
                  color: profitColor,
                  boldValue: true,
                ),
                if (unitLabel.isNotEmpty && !perModel) ...[
                  const SizedBox(height: 12),
                  TextValueInline(
                    header: 'Unit rate',
                    value: '${unitPrice.toString()}¢ / $unitLabel',
                    icon: Icons.bolt_outlined,
                  ),
                ],
              ],
            ),
          ),
          if (perModel)
            ContainerActionWidget(
              title: 'Per-model rates (¢ / token)',
              actionText: 'Edit',
              onAction: () => showPlatformProductDialog(context, doc: doc),
              content: Column(
                children: [
                  if (modelRates.isEmpty)
                    Text('No model rates set yet.',
                        style: TextStyle(color: Colors.grey.shade600))
                  else
                    for (final e in modelRates.entries) ...[
                      TextValueInline(
                        header: e.key,
                        value: '${e.value}¢',
                        icon: Icons.memory_outlined,
                      ),
                      const SizedBox(height: 12),
                    ],
                ],
              ),
            ),
          ContainerActionWidget(
            title: 'Details',
            actionText: '',
            content: Column(
              children: [
                TextValueInline(
                  header: 'Billing',
                  value: billingLabel(billingType),
                  icon: Icons.receipt_long_outlined,
                ),
                const SizedBox(height: 12),
                TextValueInline(
                  header: 'Interval',
                  value: interval.isEmpty ? '—' : interval,
                  icon: Icons.schedule,
                ),
                const SizedBox(height: 12),
                TextValueInline(
                  header: 'Connected',
                  value: hardwired ? 'Every company' : 'À-la-carte (invoices)',
                  icon: hardwired ? Icons.cable_outlined : Icons.request_quote_outlined,
                ),
                if (provider.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  TextValueInline(
                    header: 'Provider',
                    value: provider,
                    icon: Icons.cloud_outlined,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Charts tab — usage/sales over time + per-company breakdown.
class _ProductChartsTab extends StatefulWidget {
  const _ProductChartsTab({required this.productKey, required this.data});

  final String productKey;
  final Map<String, dynamic> data;

  @override
  State<_ProductChartsTab> createState() => _ProductChartsTabState();
}

class _ProductChartsTabState extends State<_ProductChartsTab> {
  ChartGroupBy _groupBy = ChartGroupBy.day;
  ChartAperture _aperture = ChartAperture.month;

  @override
  Widget build(BuildContext context) {
    final usageKey = (widget.data['usageKey'] as String?)?.trim() ?? '';
    final usageMetric = (widget.data['usageMetric'] as String?)?.trim() ?? '';
    final unitLabel = (widget.data['unitLabel'] as String?)?.trim() ?? 'units';
    final eventCollection = _eventCollectionForKey(usageKey);
    final metered = eventCollection != null && usageMetric.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
      children: [
        ChartFilterPills(
          groupBy: _groupBy,
          aperture: _aperture,
          onGroupByChanged: (g) => setState(() => _groupBy = g),
          onApertureChanged: (a) => setState(() => _aperture = a),
        ),
        _TimeSeriesChart(
          productKey: widget.productKey,
          eventCollection: eventCollection,
          eventField: metered ? _eventFieldFor(usageMetric) : null,
          unitLabel: metered ? unitLabel : 'sales (\$)',
          groupBy: _groupBy,
          aperture: _aperture,
        ),
        if (metered) ...[
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),
          _UsageCharts(
            usageKey: usageKey,
            metricField: usageMetric,
            unitLabel: unitLabel,
            unitPriceCents:
                (widget.data['unitPriceCents'] as num?)?.toDouble() ?? 0,
            perModel: widget.data['perModel'] == true,
            modelRates: (widget.data['modelRatesCents'] as Map?)
                    ?.cast<String, dynamic>() ??
                const <String, dynamic>{},
          ),
        ],
      ],
    );
  }
}

/// Time-bucketed column chart of a product's activity. Metered products sum
/// [eventField] across all companies' per-event docs; non-metered products sum
/// platformPurchase amounts. Filtered by the aperture, bucketed by groupBy.
class _TimeSeriesChart extends StatelessWidget {
  const _TimeSeriesChart({
    required this.productKey,
    required this.eventCollection,
    required this.eventField,
    required this.unitLabel,
    required this.groupBy,
    required this.aperture,
  });

  final String productKey;
  final String? eventCollection;
  final String? eventField;
  final String unitLabel;
  final ChartGroupBy groupBy;
  final ChartAperture aperture;

  Future<List<ChartData>> _load() async {
    final fs = FirebaseFirestore.instance;
    final cutoff = chartCutoffForAperture(aperture) ??
        DateTime.now().subtract(const Duration(days: 365));
    final cutoffTs = Timestamp.fromDate(cutoff);
    final buckets = <DateTime, double>{};

    if (eventCollection != null && eventField != null) {
      // Metered: sum the event field across all companies' usage docs.
      final qs = await fs
          .collectionGroup(eventCollection!)
          .where('createdAt', isGreaterThanOrEqualTo: cutoffTs)
          .get();
      for (final d in qs.docs) {
        final m = d.data();
        final created = (m['createdAt'] as Timestamp?)?.toDate();
        final v = m[eventField!];
        if (created == null || v is! num) continue;
        final bucket = chartBucketForDate(created, groupBy);
        buckets[bucket] = (buckets[bucket] ?? 0) + v.toDouble();
      }
    } else {
      // Non-metered: sum platform purchases of this product over time.
      final qs = await fs
          .collectionGroup('platformPurchase')
          .where('productKey', isEqualTo: productKey)
          .where('createdAt', isGreaterThanOrEqualTo: cutoffTs)
          .get();
      for (final d in qs.docs) {
        final m = d.data();
        final created = (m['createdAt'] as Timestamp?)?.toDate();
        final cents = (m['amountCents'] as num?)?.toDouble() ?? 0;
        if (created == null) continue;
        final bucket = chartBucketForDate(created, groupBy);
        buckets[bucket] = (buckets[bucket] ?? 0) + cents / 100;
      }
    }

    final periods = buckets.keys.toList()..sort();
    return [
      for (final p in periods) ChartData(p, buckets[p] ?? 0, 0),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ChartData>>(
      future: _load(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Text('Error loading chart: ${snap.error}',
              style: TextStyle(color: Colors.red.shade700, fontSize: 12));
        }
        final data = snap.data ?? const <ChartData>[];
        if (data.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text('No activity in this window.',
                style: TextStyle(color: Colors.grey.shade600)),
          );
        }
        return SizedBox(
          height: 260,
          child: ColumnChart(
            data: data,
            column1: unitLabel,
            column2: '',
          ),
        );
      },
    );
  }
}

/// Records tab — the underlying usage/purchase records, aperture-filtered.
class _ProductRecordsTab extends StatefulWidget {
  const _ProductRecordsTab({required this.productKey, required this.data});

  final String productKey;
  final Map<String, dynamic> data;

  @override
  State<_ProductRecordsTab> createState() => _ProductRecordsTabState();
}

class _ProductRecordsTabState extends State<_ProductRecordsTab> {
  ChartAperture _aperture = ChartAperture.month;

  @override
  Widget build(BuildContext context) {
    final usageKey = (widget.data['usageKey'] as String?)?.trim() ?? '';
    final usageMetric = (widget.data['usageMetric'] as String?)?.trim() ?? '';
    final unitLabel = (widget.data['unitLabel'] as String?)?.trim() ?? 'units';
    final eventCollection = _eventCollectionForKey(usageKey);
    final metered = eventCollection != null && usageMetric.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
      children: [
        ChartAperturePill(
          aperture: _aperture,
          onChanged: (a) => setState(() => _aperture = a),
        ),
        _RecordsList(
          productKey: widget.productKey,
          eventCollection: eventCollection,
          eventField: metered ? _eventFieldFor(usageMetric) : null,
          unitLabel: metered ? unitLabel : 'sale',
          aperture: _aperture,
        ),
      ],
    );
  }
}

class _RecordsList extends StatelessWidget {
  const _RecordsList({
    required this.productKey,
    required this.eventCollection,
    required this.eventField,
    required this.unitLabel,
    required this.aperture,
  });

  final String productKey;
  final String? eventCollection;
  final String? eventField;
  final String unitLabel;
  final ChartAperture aperture;

  Future<List<_RecordRow>> _load() async {
    final fs = FirebaseFirestore.instance;
    final cutoff = chartCutoffForAperture(aperture) ??
        DateTime.now().subtract(const Duration(days: 365));
    final cutoffTs = Timestamp.fromDate(cutoff);
    final rows = <_RecordRow>[];

    if (eventCollection != null && eventField != null) {
      final qs = await fs
          .collectionGroup(eventCollection!)
          .where('createdAt', isGreaterThanOrEqualTo: cutoffTs)
          .orderBy('createdAt', descending: true)
          .limit(150)
          .get();
      for (final d in qs.docs) {
        final m = d.data();
        final v = m[eventField!];
        if (v is! num || v == 0) continue;
        rows.add(_RecordRow(
          when: (m['createdAt'] as Timestamp?)?.toDate(),
          title: _describeEvent(m),
          value: '${v.toString()} $unitLabel',
        ));
      }
    } else {
      final qs = await fs
          .collectionGroup('platformPurchase')
          .where('productKey', isEqualTo: productKey)
          .where('createdAt', isGreaterThanOrEqualTo: cutoffTs)
          .orderBy('createdAt', descending: true)
          .limit(150)
          .get();
      for (final d in qs.docs) {
        final m = d.data();
        final cents = (m['amountCents'] as num?)?.toDouble() ?? 0;
        rows.add(_RecordRow(
          when: (m['createdAt'] as Timestamp?)?.toDate(),
          title: (m['productLabel'] as String?) ?? 'Purchase',
          value: '\$${(cents / 100).toStringAsFixed(2)}',
        ));
      }
    }
    return rows;
  }

  String _describeEvent(Map<String, dynamic> m) {
    final parts = <String>[];
    final dir = (m['direction'] as String?)?.trim();
    final type = (m['type'] as String?)?.trim();
    final feature = (m['feature'] as String?)?.trim();
    final model = (m['model'] as String?)?.trim();
    final metric = (m['metric'] as String?)?.trim();
    if (type != null && type.isNotEmpty) parts.add(type);
    if (dir != null && dir.isNotEmpty) parts.add(dir);
    if (feature != null && feature.isNotEmpty) parts.add(feature);
    if (model != null && model.isNotEmpty) parts.add(model);
    if (metric != null && metric.isNotEmpty) parts.add(metric);
    return parts.isEmpty ? 'Usage event' : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_RecordRow>>(
      future: _load(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Text('Error loading records: ${snap.error}',
              style: TextStyle(color: Colors.red.shade700, fontSize: 12));
        }
        final rows = snap.data ?? const <_RecordRow>[];
        if (rows.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text('No records in this window.',
                style: TextStyle(color: Colors.grey.shade600)),
          );
        }
        return Column(
          children: [
            for (final r in rows)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.receipt_outlined, size: 18),
                title: Text(r.title, style: const TextStyle(fontSize: 13)),
                subtitle: r.when != null
                    ? Text(_fmtDate(r.when!),
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600))
                    : null,
                trailing: Text(r.value,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ),
          ],
        );
      },
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _RecordRow {
  _RecordRow({required this.when, required this.title, required this.value});
  final DateTime? when;
  final String title;
  final String value;
}

/// Cross-company usage for a metered product: a ranked per-business bar list
/// plus the platform average. Reads the top-level `total*Usage` rollups via
/// AdminFirebaseService.usageByCompany. For per-model products it also shows a
/// per-model token + estimated-cost breakdown.
class _UsageCharts extends StatelessWidget {
  const _UsageCharts({
    required this.usageKey,
    required this.metricField,
    required this.unitLabel,
    required this.unitPriceCents,
    this.perModel = false,
    this.modelRates = const <String, dynamic>{},
  });

  final String usageKey;
  final String metricField;
  final String unitLabel;
  final double unitPriceCents;
  final bool perModel;
  final Map<String, dynamic> modelRates;

  /// Format a raw unit count (e.g. "1,240 tokens").
  String _fmt(double v) {
    final n = v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
    return '$n $unitLabel';
  }

  /// Estimated charge for [units] at the product's per-unit rate.
  String _cost(double units) =>
      '\$${(units * unitPriceCents / 100).toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    if (perModel) return _buildPerModel(context);
    final palette = AppPaletteScope.of(context);
    return FutureBuilder<List<CompanyUsageDatum>>(
      future: AdminFirebaseService.instance
          .usageByCompany(usageKey: usageKey, metricField: metricField),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Text('Error loading usage: ${snap.error}');
        }
        final all = snap.data ?? const <CompanyUsageDatum>[];
        final data = all.where((d) => d.value > 0).toList();
        final total = data.fold<double>(0, (a, d) => a + d.value);
        final avg = data.isEmpty ? 0.0 : total / data.length;
        final maxVal = data.isEmpty
            ? 0.0
            : data.map((d) => d.value).reduce((a, b) => a > b ? a : b);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Usage across businesses',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (data.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text('No usage recorded yet for any company.',
                    style: TextStyle(color: Colors.grey.shade600)),
              )
            else ...[
              Row(
                children: [
                  _Stat(label: 'Companies', value: '${data.length}'),
                  _Stat(label: 'Average', value: _fmt(avg)),
                  _Stat(label: 'Total', value: _fmt(total)),
                  if (unitPriceCents > 0)
                    _Stat(label: 'Est. charge', value: _cost(total)),
                ],
              ),
              const SizedBox(height: 16),
              for (final d in data)
                _UsageBar(
                  name: d.companyName,
                  valueLabel: _fmt(d.value),
                  fraction: maxVal == 0 ? 0 : d.value / maxVal,
                  avgFraction: maxVal == 0 ? 0 : avg / maxVal,
                  color: palette.primary2,
                ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildPerModel(BuildContext context) {
    final mapField = metricField == 'totalInputTokens'
        ? 'inputTokensByModel'
        : metricField == 'totalOutputTokens'
            ? 'outputTokensByModel'
            : null;
    if (mapField == null) return const SizedBox.shrink();
    return FutureBuilder<List<CompanyModelUsageDatum>>(
      future:
          AdminFirebaseService.instance.aiModelUsageByCompany(mapField: mapField),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Text('Error loading usage: ${snap.error}');
        }
        final companies = snap.data ?? const <CompanyModelUsageDatum>[];
        // Aggregate tokens per model across all companies.
        final perModelTotals = <String, double>{};
        for (final c in companies) {
          c.byModel.forEach((m, v) {
            perModelTotals[m] = (perModelTotals[m] ?? 0) + v;
          });
        }
        if (perModelTotals.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text('No token usage recorded yet for any company.',
                style: TextStyle(color: Colors.grey.shade600)),
          );
        }
        final models = perModelTotals.keys.toList()
          ..sort((a, b) => perModelTotals[b]!.compareTo(perModelTotals[a]!));
        var estTotal = 0.0;
        for (final m in models) {
          final rate =
              modelRates[m] is num ? (modelRates[m] as num).toDouble() : 0.0;
          estTotal += perModelTotals[m]! * rate / 100;
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tokens by model (all businesses)',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            for (final m in models)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(m,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500)),
                    ),
                    Text(_fmt(perModelTotals[m]!),
                        style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Est. charge (all)',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                Text('\$${estTotal.toStringAsFixed(2)}',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.green.shade700)),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          Text(label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

class _UsageBar extends StatelessWidget {
  const _UsageBar({
    required this.name,
    required this.valueLabel,
    required this.fraction,
    required this.avgFraction,
    required this.color,
  });

  final String name;
  final String valueLabel;
  final double fraction;
  final double avgFraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
              ),
              Text(valueLabel,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 14,
            child: LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth;
                return Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: fraction.clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                    ),
                    Positioned(
                      left: (avgFraction.clamp(0.0, 1.0)) * w,
                      top: -2,
                      bottom: -2,
                      child: Container(width: 2, color: Colors.black54),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
