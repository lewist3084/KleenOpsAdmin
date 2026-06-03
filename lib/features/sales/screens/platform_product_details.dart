// lib/features/sales/screens/platform_product_details.dart
//
// Detail + usage charts for a single `platformProduct`. For usage-metered
// products (those with a `usageKey`), shows per-company usage across all
// businesses with the platform average — the AI / voice-video "how much is
// each company using" view. For provisioned/one-time products it shows the
// catalog fields; sales/charges for those surface under Billing and on each
// company's Services section.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';

import '../../../services/admin_firebase_service.dart';
import '../../../theme/palette.dart';
import '../widgets/platform_catalog_body.dart';

class PlatformProductDetailsScreen extends StatelessWidget {
  const PlatformProductDetailsScreen({super.key, required this.productKey});

  final String productKey;

  static const _palette = adminPalette;

  @override
  Widget build(BuildContext context) {
    final ref =
        FirebaseFirestore.instance.collection('platformProduct').doc(productKey);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product'),
        backgroundColor: _palette.primary1,
        foregroundColor: Colors.white,
      ),
      body: StandardCanvas(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
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
            final label = data['label'] as String? ?? productKey;
            final description = data['description'] as String? ?? '';
            final priceCents = (data['priceCents'] as num?)?.toInt() ?? 0;
            final interval = data['interval'] as String? ?? '';
            final usageKey = (data['usageKey'] as String?)?.trim();
            final usageMetric =
                (data['usageMetric'] as String?)?.trim().isNotEmpty == true
                    ? (data['usageMetric'] as String).trim()
                    : 'totalRequestCount';
            final unitLabel =
                (data['unitLabel'] as String?)?.trim().isNotEmpty == true
                    ? (data['unitLabel'] as String).trim()
                    : 'units';
            final unitPriceCents = (data['unitPriceCents'] as num?)?.toInt() ?? 0;
            final price = '\$${(priceCents / 100).toStringAsFixed(2)}'
                '${interval.isNotEmpty ? ' / $interval' : ''}';

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(label,
                          style: Theme.of(context).textTheme.headlineSmall),
                    ),
                    TextButton.icon(
                      onPressed: () =>
                          showPlatformProductDialog(context, doc: doc),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(price,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(description,
                      style: TextStyle(color: Colors.grey.shade700)),
                ],
                const Divider(height: 32),
                if (usageKey != null && usageKey.isNotEmpty)
                  _UsageCharts(
                    usageKey: usageKey,
                    metricField: usageMetric,
                    unitLabel: unitLabel,
                    unitPriceCents: unitPriceCents,
                  )
                else
                  Text(
                    'This product isn\'t metered against company usage. '
                    'Purchases of it appear under Billing → Recent platform '
                    'sales and on each company\'s Services section.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Cross-company usage for a metered product: a ranked per-business bar list
/// plus the platform average. Reads `company/{id}/usage/{usageKey}.{metric}`.
class _UsageCharts extends StatelessWidget {
  const _UsageCharts({
    required this.usageKey,
    required this.metricField,
    required this.unitLabel,
    required this.unitPriceCents,
  });

  final String usageKey;
  final String metricField;
  final String unitLabel;
  final int unitPriceCents;

  /// Format a raw unit count (e.g. "1,240 requests").
  String _fmt(double v) {
    final n = v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
    return '$n $unitLabel';
  }

  /// Estimated charge for [units] at the product's per-unit rate.
  String _cost(double units) =>
      '\$${(units * unitPriceCents / 100).toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
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
        // Only chart companies that actually have usage.
        final data = all.where((d) => d.value > 0).toList();
        final total = data.fold<double>(0, (a, d) => a + d.value);
        final avg = data.isEmpty ? 0.0 : total / data.length;
        final maxVal =
            data.isEmpty ? 0.0 : data.map((d) => d.value).reduce((a, b) => a > b ? a : b);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Usage across businesses',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Metric: $usageKey · $metricField',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            if (data.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No usage recorded yet for any company.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
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
                  value: d.value,
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
    required this.value,
    required this.valueLabel,
    required this.fraction,
    required this.avgFraction,
    required this.color,
  });

  final String name;
  final double value;
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
                    // Average marker line.
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
