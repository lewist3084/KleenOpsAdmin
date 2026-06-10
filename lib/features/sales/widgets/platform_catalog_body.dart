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
import 'package:shared_widgets/dialogs/dialog_select.dart';
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
  bool _hardwired = false;
  bool _perModel = false;
  bool _saving = false;

  /// Preserved through edits (set by the catalog seed, not editable here).
  String _billingType = 'one_time';
  bool _seatBilled = false;

  /// Per-model token rates (model id → ¢ per token) for [_perModel] products,
  /// edited as parallel name/rate controller rows.
  final List<_ModelRateRow> _modelRates = <_ModelRateRow>[];

  /// Group options shown in the select dialog: the canonical order, plus
  /// 'Other', the current group, and any custom groups already used across the
  /// live catalog (loaded in [_loadGroups]). Custom groups added via the "+"
  /// action are appended here too.
  List<String> _groups = const [];

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
    _hardwired = d['hardwired'] as bool? ?? false;
    _perModel = d['perModel'] as bool? ?? false;
    _billingType = d['billingType'] as String? ?? 'one_time';
    _seatBilled = d['seatBilled'] as bool? ?? false;
    final rates = (d['modelRatesCents'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    rates.forEach((model, rate) {
      _modelRates.add(_ModelRateRow(
        model: TextEditingController(text: model),
        rate: TextEditingController(text: (rate as num?)?.toString() ?? ''),
      ));
    });
    _seedGroups();
    _loadGroups();
  }

  /// Seed the in-memory group list from the canonical order + current group.
  void _seedGroups() {
    _groups = _sortGroups({...kPlatformProductGroupOrder, 'Other', _group});
  }

  /// Pull the distinct groups already used across the catalog so the select
  /// offers every existing bucket, not just the canonical ones.
  Future<void> _loadGroups() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('platformProduct')
          .get();
      final set = <String>{...kPlatformProductGroupOrder, 'Other', _group};
      for (final d in snap.docs) {
        set.add(resolveProductGroup(d.data()));
      }
      if (mounted) setState(() => _groups = _sortGroups(set));
    } catch (_) {
      // best-effort; keep the seeded list on error
    }
  }

  /// Canonical groups first (in order), custom groups last alphabetically.
  List<String> _sortGroups(Set<String> groups) {
    final list = groups.where((g) => g.trim().isNotEmpty).toList();
    list.sort((a, b) {
      final si = platformGroupSortIndex(a).compareTo(platformGroupSortIndex(b));
      return si != 0 ? si : a.toLowerCase().compareTo(b.toLowerCase());
    });
    return list;
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
    for (final r in _modelRates) {
      r.model.dispose();
      r.rate.dispose();
    }
    super.dispose();
  }

  // ── group select (mirrors the app-wide DialogSelect "+" add workflow) ──
  Future<void> _openGroupDialog() async {
    FocusScope.of(context).unfocus();
    await showDialog<void>(
      context: context,
      builder: (ctx) => DialogSelect<String>(
        title: 'Select Group',
        items: _groups,
        itemLabel: (g) => g,
        tileType: DialogSelectTileType.radio,
        initialSelection: _group,
        addTooltip: 'Add group',
        onCancel: () => Navigator.of(ctx).pop(),
        onSubmit: (res) {
          Navigator.of(ctx).pop();
          final v = res.firstOrNull;
          if (v != null) setState(() => _group = v);
        },
        onAdd: () async {
          // Close, prompt for the new group, then reopen with it selected so
          // the refreshed (re-sorted) list includes it.
          Navigator.of(ctx).pop();
          final created = await _promptCreateGroup();
          if (created != null) {
            setState(() {
              _group = created;
              _groups = _sortGroups({..._groups, created});
            });
          }
          await _openGroupDialog();
        },
      ),
    );
  }

  /// Prompt for a brand-new group name. Groups are just labels stored on the
  /// product (no separate collection), so this returns the trimmed name and the
  /// caller records it locally; it becomes "real" once a product is saved with it.
  Future<String?> _promptCreateGroup() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New group'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Group name',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return null;
    return name;
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
    final metered = usageKey.isNotEmpty;
    // Build the per-model rate map (skip blank rows).
    final modelRates = <String, num>{};
    for (final r in _modelRates) {
      final m = r.model.text.trim();
      final v = double.tryParse(r.rate.text.trim());
      if (m.isNotEmpty && v != null) modelRates[m] = v;
    }
    final usePerModel = metered && _perModel;
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
      // Metered when a usage key is set; otherwise keep the product's existing
      // billing type (recurring subscriptions / one-time services).
      'billingType': metered ? 'metered' : _billingType,
      'provider': _provider.text.trim(),
      'active': _active,
      'hardwired': _hardwired,
      'seatBilled': _seatBilled,
      'usageKey': metered ? usageKey : FieldValue.delete(),
      'usageMetric': metered ? _usageMetric.text.trim() : FieldValue.delete(),
      'unitPriceCents':
          metered ? (double.tryParse(_unitPrice.text.trim()) ?? 0) : FieldValue.delete(),
      'unitLabel': metered ? _unitLabel.text.trim() : FieldValue.delete(),
      'perModel': usePerModel ? true : FieldValue.delete(),
      'modelRatesCents': usePerModel ? modelRates : FieldValue.delete(),
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

  /// Editable list of per-model token rates (model id → ¢ per token).
  Widget _modelRatesEditor() {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Per-model rates (¢ / token)',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700)),
              const Spacer(),
              IconButton(
                tooltip: 'Add model',
                icon: const Icon(Icons.add, size: 18),
                onPressed: () => setState(() => _modelRates.add(_ModelRateRow(
                      model: TextEditingController(),
                      rate: TextEditingController(),
                    ))),
              ),
            ],
          ),
          for (final r in _modelRates)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: r.model,
                      decoration: const InputDecoration(
                        labelText: 'Model',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: r.rate,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: '¢ / token',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() {
                      r.model.dispose();
                      r.rate.dispose();
                      _modelRates.remove(r);
                    }),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
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
            GestureDetector(
              onTap: _openGroupDialog,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Group',
                  border: OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: Icon(Icons.arrow_drop_down),
                ),
                child: Text(_group),
              ),
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
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Usage key (optional — ai / pstn / plaid / video)',
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
            if (_usageKey.text.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Per-model pricing'),
                subtitle: const Text(
                    'Bill each AI model at its own per-token rate'),
                value: _perModel,
                onChanged: (v) => setState(() => _perModel = v),
              ),
              if (_perModel) _modelRatesEditor(),
            ],
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Connected to every company'),
              subtitle: const Text(
                  'Auto-attached & billed by usage; off = sold via invoices'),
              value: _hardwired,
              onChanged: (v) => setState(() => _hardwired = v),
            ),
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

/// A single editable per-model rate row (model id + ¢/token).
class _ModelRateRow {
  _ModelRateRow({required this.model, required this.rate});
  final TextEditingController model;
  final TextEditingController rate;
}
