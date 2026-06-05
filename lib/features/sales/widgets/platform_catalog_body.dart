// lib/features/sales/widgets/platform_catalog_body.dart
//
// The overlord's sellable platform-product catalog (`platformProduct/{key}`):
// domains, registered agent, virtual address, phone, plus usage-metered
// products (AI, voice/video) that link to `company/{id}/usage/{usageKey}`.
//
// Shared body (no Scaffold) so it can render both inside the Sales → Products
// tab and the Billing → Platform Products screen — one catalog, two entry
// points. Tapping a product opens its detail/charts screen.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:shared_widgets/lists/standardViewGroup.dart';
import 'package:shared_widgets/tiles/standard_tile_medium.dart';

import '../data/platform_products_catalog.dart';
import '../services/platform_catalog_service.dart';
import '../screens/platform_product_details.dart';

class PlatformCatalogBody extends StatefulWidget {
  const PlatformCatalogBody({super.key});

  @override
  State<PlatformCatalogBody> createState() => _PlatformCatalogBodyState();
}

class _PlatformCatalogBodyState extends State<PlatformCatalogBody> {
  @override
  void initState() {
    super.initState();
    // Seed/refresh the catalog from the canonical product list on first open.
    // Idempotent + version-gated, so it only writes when the catalog changes.
    PlatformCatalogService.instance.seedCatalogIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('platformProduct')
        .orderBy('label');

    return Stack(
      children: [
        StandardViewGroup(
          queryStream: query.snapshots(),
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 88),
          emptyMessage: 'No products yet — pull to refresh or tap +.',
          groupBy: (doc) => resolveProductGroup(doc.data()),
          groupSort: (a, b) =>
              platformGroupSortIndex(a).compareTo(platformGroupSortIndex(b)),
          groupCollapsible: true,
          headerIcon: Icons.sell_outlined,
          enableReorder: false,
          itemBuilder: (doc) => _ProductTile(doc: doc),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: 'platformProductFab',
            onPressed: () => showPlatformProductDialog(context),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}

/// One catalog product rendered as the shared three-row medium tile:
///   • row 1 — product label, with a status dot (green active / grey inactive)
///   • row 2 — price (or "Metered" for usage-billed products)
///   • row 3 — provider + billing cadence
class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.doc});

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final label = data['label'] as String? ?? doc.id;
    final priceCents = (data['priceCents'] as num?)?.toInt() ?? 0;
    final interval = data['interval'] as String? ?? '';
    final provider = data['provider'] as String? ?? '';
    final billingType = data['billingType'] as String? ?? 'one_time';
    final usageKey = data['usageKey'] as String?;
    final unitLabel = data['unitLabel'] as String?;
    final active = data['active'] as bool? ?? false;
    final metered = usageKey != null && usageKey.isNotEmpty;

    // Row 2 — what it costs.
    final String priceLine = metered
        ? 'Metered${unitLabel != null && unitLabel.isNotEmpty ? ' · per $unitLabel' : ''}'
        : '\$${(priceCents / 100).toStringAsFixed(2)}'
            '${interval.isNotEmpty ? ' / $interval' : ''}';

    // Row 3 — provider + how it's billed.
    final String cadence = metered
        ? 'metered'
        : billingType == 'recurring'
            ? 'subscription'
            : 'one-time';
    final String detailLine =
        provider.isNotEmpty ? '$provider · $cadence' : cadence;

    return StandardTileMediumDart(
      imageUrl: '',
      showImage: false,
      title: label,
      titleIcon: active ? Icons.circle : Icons.circle_outlined,
      titleIconColor: active ? Colors.green : Colors.grey,
      subTitle: priceLine,
      subTitleIcon: metered ? Icons.bolt_outlined : Icons.attach_money,
      thirdLine: detailLine,
      thirdLineIcon: Icons.sell_outlined,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlatformProductDetailsScreen(productKey: doc.id),
        ),
      ),
    );
  }
}

/// Add (doc == null) or edit a `platformProduct`. New products with a
/// `usageKey` become metered products charted against company usage; the
/// provisioned products (domain/phone/etc.) keep their server provisioning
/// keyed to the doc id.
Future<void> showPlatformProductDialog(
  BuildContext context, {
  DocumentSnapshot<Map<String, dynamic>>? doc,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _PlatformProductDialog(doc: doc),
  );
}

class _PlatformProductDialog extends StatefulWidget {
  const _PlatformProductDialog({this.doc});

  final DocumentSnapshot<Map<String, dynamic>>? doc;

  @override
  State<_PlatformProductDialog> createState() => _PlatformProductDialogState();
}

class _PlatformProductDialogState extends State<_PlatformProductDialog> {
  late final TextEditingController _key;
  late final TextEditingController _label;
  late final TextEditingController _desc;
  late final TextEditingController _price;
  late final TextEditingController _cost;
  late final TextEditingController _provider;
  late final TextEditingController _usageKey;
  late final TextEditingController _usageMetric;
  late final TextEditingController _unitPrice;
  late final TextEditingController _unitLabel;
  String _interval = 'month';
  String _group = kPlatformProductGroupOrder.first;
  bool _active = true;
  bool _saving = false;

  bool get _isEdit => widget.doc != null;

  @override
  void initState() {
    super.initState();
    final d = widget.doc?.data() ?? const <String, dynamic>{};
    _key = TextEditingController(text: widget.doc?.id ?? '');
    _label = TextEditingController(text: d['label'] as String? ?? '');
    _desc = TextEditingController(text: d['description'] as String? ?? '');
    final cents = (d['priceCents'] as num?)?.toInt() ?? 0;
    _price = TextEditingController(text: (cents / 100).toStringAsFixed(2));
    // Default cost to existing costCents, falling back to the price (0% markup).
    final costCents = (d['costCents'] as num?)?.toInt() ?? cents;
    _cost = TextEditingController(text: (costCents / 100).toStringAsFixed(2));
    _provider = TextEditingController(text: d['provider'] as String? ?? '');
    _usageKey = TextEditingController(text: d['usageKey'] as String? ?? '');
    _usageMetric = TextEditingController(
        text: d['usageMetric'] as String? ?? 'totalRequestCount');
    _unitPrice = TextEditingController(
        text: (d['unitPriceCents'] as num?)?.toString() ?? '');
    _unitLabel = TextEditingController(text: d['unitLabel'] as String? ?? '');
    _interval = d['interval'] as String? ?? 'month';
    _group = resolveProductGroup(d);
    _active = d['active'] as bool? ?? true;
  }

  @override
  void dispose() {
    _key.dispose();
    _label.dispose();
    _desc.dispose();
    _price.dispose();
    _cost.dispose();
    _provider.dispose();
    _usageKey.dispose();
    _usageMetric.dispose();
    _unitPrice.dispose();
    _unitLabel.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final key = _key.text.trim();
    final label = _label.text.trim();
    final dollars = double.tryParse(_price.text.trim());
    if (key.isEmpty || label.isEmpty || dollars == null || dollars < 0) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Key, label and a valid price are required')));
      return;
    }
    final usageKey = _usageKey.text.trim();
    setState(() => _saving = true);
    final payload = <String, dynamic>{
      'productKey': key,
      'group': _group,
      'label': label,
      'description': _desc.text.trim(),
      'priceCents': (dollars * 100).round(),
      'costCents': ((double.tryParse(_cost.text.trim()) ?? 0) * 100).round(),
      'currency': 'usd',
      'interval': _interval,
      'billingType': usageKey.isNotEmpty ? 'metered' : 'one_time',
      'provider': _provider.text.trim(),
      'active': _active,
      'usageKey': usageKey.isEmpty ? FieldValue.delete() : usageKey,
      'usageMetric':
          usageKey.isEmpty ? FieldValue.delete() : _usageMetric.text.trim(),
      'unitPriceCents': usageKey.isEmpty
          ? FieldValue.delete()
          : (double.tryParse(_unitPrice.text.trim()) ?? 0),
      'unitLabel':
          usageKey.isEmpty ? FieldValue.delete() : _unitLabel.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    try {
      final ref =
          FirebaseFirestore.instance.collection('platformProduct').doc(key);
      if (!_isEdit) payload['createdAt'] = FieldValue.serverTimestamp();
      await ref.set(payload, SetOptions(merge: true));
      navigator.pop();
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  /// Live markup readout computed from the Cost + Price fields.
  Widget _markupLine() {
    final cost = double.tryParse(_cost.text.trim()) ?? 0;
    final price = double.tryParse(_price.text.trim()) ?? 0;
    final profit = price - cost;
    final pct = cost > 0 ? (profit / cost * 100) : null;
    final color = profit > 0
        ? Colors.green.shade700
        : (profit < 0 ? Colors.red.shade700 : Colors.grey.shade600);
    final text = cost <= 0
        ? 'Enter a cost to see markup'
        : 'Markup ${pct!.toStringAsFixed(1)}%  ·  profit \$${profit.toStringAsFixed(2)}'
            '${price > 0 ? '' : ' (price \$0)'}';
    return Row(
      children: [
        Icon(Icons.trending_up, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DialogAction(
      title: _isEdit ? 'Edit ${_label.text}' : 'New Platform Product',
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _key,
              enabled: !_isEdit,
              decoration: const InputDecoration(
                labelText: 'Key (e.g. domain_registration, ai_usage)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _label,
              decoration: const InputDecoration(
                  labelText: 'Label',
                  border: OutlineInputBorder(),
                  isDense: true),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _group,
              decoration: const InputDecoration(
                  labelText: 'Group',
                  border: OutlineInputBorder(),
                  isDense: true),
              items: [
                for (final g in {...kPlatformProductGroupOrder, _group})
                  DropdownMenuItem(value: g, child: Text(g)),
              ],
              onChanged: (v) => setState(() => _group = v ?? _group),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _desc,
              maxLines: 2,
              decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  isDense: true),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cost,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                        labelText: 'Cost (USD)',
                        helperText: 'What we pay',
                        prefixText: '\$ ',
                        border: OutlineInputBorder(),
                        isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _price,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                        labelText: 'Price (USD)',
                        helperText: 'What we charge',
                        prefixText: '\$ ',
                        border: OutlineInputBorder(),
                        isDense: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _markupLine(),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _interval,
              decoration: const InputDecoration(
                  labelText: 'Interval',
                  border: OutlineInputBorder(),
                  isDense: true),
              items: const [
                DropdownMenuItem(value: 'month', child: Text('month')),
                DropdownMenuItem(value: 'year', child: Text('year')),
                DropdownMenuItem(value: 'once', child: Text('once')),
              ],
              onChanged: (v) => setState(() => _interval = v ?? _interval),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _provider,
              decoration: const InputDecoration(
                  labelText: 'Provider (optional)',
                  border: OutlineInputBorder(),
                  isDense: true),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _usageKey,
              decoration: const InputDecoration(
                labelText: 'Usage key (optional — ai / voice / storage)',
                helperText: 'Set to meter this product against company usage',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _usageMetric,
              decoration: const InputDecoration(
                labelText: 'Usage metric field (e.g. totalRequestCount, '
                    'totalDurationSeconds)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _unitPrice,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Price per unit (¢)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _unitLabel,
                    decoration: const InputDecoration(
                      labelText: 'Unit label (request, minute…)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active (available to buy)'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
          ],
        ),
      ),
      cancelText: 'Cancel',
      onCancel: () => Navigator.of(context).pop(),
      actionText: _saving ? 'Saving…' : 'Save',
      onAction: _saving ? () {} : _save,
    );
  }
}
