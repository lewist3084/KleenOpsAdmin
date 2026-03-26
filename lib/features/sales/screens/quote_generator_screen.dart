import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/features/sales/services/quote_generator_service.dart';

/// Screen for generating a quote from scanned rooms and detected objects.
///
/// Flow:
/// 1. Select customer and property/building.
/// 2. Service gathers objects with their assigned processes.
/// 3. User reviews, sets frequencies, and confirms.
/// 4. Draft invoice is created with calculated line items.
class QuoteGeneratorScreen extends ConsumerStatefulWidget {
  const QuoteGeneratorScreen({super.key});

  @override
  ConsumerState<QuoteGeneratorScreen> createState() =>
      _QuoteGeneratorScreenState();
}

class _QuoteGeneratorScreenState extends ConsumerState<QuoteGeneratorScreen> {
  // ─── Selection state ────────────────────────────────────────────
  DocumentReference<Map<String, dynamic>>? _companyRef;
  String? _selectedCustomerId;
  String? _selectedCustomerName;
  String? _selectedPropertyId;
  String? _selectedPropertyName;
  String? _selectedBuildingId;
  String? _selectedBuildingName;

  // ─── Dropdown data ──────────────────────────────────────────────
  List<_DropdownItem> _customers = [];
  List<_DropdownItem> _properties = [];
  List<_DropdownItem> _buildings = [];
  bool _loadingDropdowns = true;

  // ─── Quote data ─────────────────────────────────────────────────
  QuotePreviewData? _previewData;
  bool _loadingPreview = false;
  bool _generating = false;
  QuoteGenerationOutcome? _outcome;

  final _service = QuoteGeneratorService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDropdowns());
  }

  Future<void> _loadDropdowns() async {
    final companyRef = ref.read(companyIdProvider).asData?.value;
    if (companyRef == null) return;
    _companyRef = companyRef;

    final customerSnap = await FirebaseFirestore.instance.collection('customer').get();
    final customers = customerSnap.docs
        .map((d) => _DropdownItem(
              id: d.id,
              name: (d.data()['name'] as String?) ?? 'Unnamed',
            ))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final propertySnap = await FirebaseFirestore.instance.collection('property').get();
    final properties = propertySnap.docs
        .map((d) => _DropdownItem(
              id: d.id,
              name: (d.data()['name'] as String?) ?? 'Unnamed',
            ))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    if (!mounted) return;
    setState(() {
      _customers = customers;
      _properties = properties;
      _loadingDropdowns = false;
    });
  }

  Future<void> _loadBuildingsForProperty(String propertyId) async {
    final companyRef = _companyRef;
    if (companyRef == null) return;

    final buildingSnap = await FirebaseFirestore.instance
        .collection('building')
        .where('propertyId',
            isEqualTo: FirebaseFirestore.instance.collection('property').doc(propertyId))
        .get();

    final buildings = buildingSnap.docs
        .map((d) => _DropdownItem(
              id: d.id,
              name: (d.data()['name'] as String?) ?? 'Unnamed',
            ))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    if (!mounted) return;
    setState(() {
      _buildings = buildings;
      _selectedBuildingId = null;
      _selectedBuildingName = null;
    });
  }

  bool get _canLoadPreview =>
      !_loadingPreview &&
      _selectedCustomerId != null &&
      _selectedPropertyId != null;

  Future<void> _loadPreview() async {
    final companyRef = _companyRef;
    if (companyRef == null || _selectedPropertyId == null) return;

    setState(() => _loadingPreview = true);

    try {
      final data = await _service.gatherQuoteData(
        companyRef: companyRef,
        propertyId: _selectedPropertyId!,
        buildingId: _selectedBuildingId,
      );

      if (!mounted) return;
      setState(() {
        _previewData = data;
        _loadingPreview = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingPreview = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load data: $e')),
      );
    }
  }

  Future<void> _generateQuote() async {
    final companyRef = _companyRef;
    final preview = _previewData;
    if (companyRef == null || preview == null) return;

    setState(() => _generating = true);

    try {
      // Build line items from included objects × processes × frequency.
      final lineItems = <QuoteLineItem>[];

      for (final obj in preview.objectEntries) {
        if (!obj.included) continue;

        for (final proc in obj.processes) {
          if (proc.frequencyPerMonth <= 0) continue;

          final monthlyTotal = proc.totalCostPerUnit * proc.frequencyPerMonth;
          final description =
              '${obj.objectName} — ${proc.processName} '
              '(${proc.frequencyPerMonth}x/month)';

          lineItems.add(QuoteLineItem(
            description: description,
            quantity: proc.frequencyPerMonth.toDouble(),
            unitPrice: proc.totalCostPerUnit,
            amount: monthlyTotal,
            objectId: obj.objectId,
            processId: proc.processId,
            frequency: '${proc.frequencyPerMonth}/month',
          ));
        }
      }

      if (lineItems.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No items to quote.')),
          );
        }
        setState(() => _generating = false);
        return;
      }

      final outcome = await _service.generateQuote(
        companyRef: companyRef,
        customerRef: FirebaseFirestore.instance.collection('customer').doc(_selectedCustomerId),
        customerName: _selectedCustomerName ?? '',
        propertyId: _selectedPropertyId!,
        buildingId: _selectedBuildingId,
        lineItems: lineItems,
      );

      if (!mounted) return;
      setState(() {
        _outcome = outcome;
        _generating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _generating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Quote generation failed: $e')),
      );
    }
  }

  // ─── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_outcome != null) return _buildOutcomeView(theme);
    if (_previewData != null) return _buildPreviewView(theme);
    return _buildSetupView(theme);
  }

  // ─── Setup View ─────────────────────────────────────────────────

  Widget _buildSetupView(ThemeData theme) {
    return Scaffold(
      appBar: AppBar(title: const Text('Generate Quote')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _canLoadPreview ? _loadPreview : null,
        icon: _loadingPreview
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.preview),
        label: Text(_loadingPreview ? 'Loading...' : 'Preview Quote'),
        backgroundColor: _canLoadPreview ? null : theme.disabledColor,
      ),
      body: _loadingDropdowns
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Select a customer and property to generate a quote '
                  'from assigned processes and their costs.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 24),

                // Customer dropdown
                DropdownButtonFormField<String>(
                  value: _selectedCustomerId,
                  decoration: const InputDecoration(
                    labelText: 'Customer',
                    border: OutlineInputBorder(),
                  ),
                  items: _customers
                      .map((c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          ))
                      .toList(),
                  onChanged: (id) {
                    final name =
                        _customers.where((c) => c.id == id).firstOrNull?.name;
                    setState(() {
                      _selectedCustomerId = id;
                      _selectedCustomerName = name;
                      _previewData = null;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Property dropdown
                DropdownButtonFormField<String>(
                  value: _selectedPropertyId,
                  decoration: const InputDecoration(
                    labelText: 'Property',
                    border: OutlineInputBorder(),
                  ),
                  items: _properties
                      .map((p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(p.name),
                          ))
                      .toList(),
                  onChanged: (id) {
                    final name =
                        _properties.where((p) => p.id == id).firstOrNull?.name;
                    setState(() {
                      _selectedPropertyId = id;
                      _selectedPropertyName = name;
                      _previewData = null;
                    });
                    if (id != null) _loadBuildingsForProperty(id);
                  },
                ),
                const SizedBox(height: 16),

                // Building dropdown (optional)
                if (_buildings.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: _selectedBuildingId,
                    decoration: const InputDecoration(
                      labelText: 'Building (optional)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All buildings'),
                      ),
                      ..._buildings.map((b) => DropdownMenuItem(
                            value: b.id,
                            child: Text(b.name),
                          )),
                    ],
                    onChanged: (id) {
                      final name = _buildings
                          .where((b) => b.id == id)
                          .firstOrNull
                          ?.name;
                      setState(() {
                        _selectedBuildingId = id;
                        _selectedBuildingName = name;
                        _previewData = null;
                      });
                    },
                  ),
              ],
            ),
    );
  }

  // ─── Preview View ───────────────────────────────────────────────

  Widget _buildPreviewView(ThemeData theme) {
    final preview = _previewData!;
    final includedObjects =
        preview.objectEntries.where((o) => o.included).toList();

    // Calculate totals.
    double totalMonthly = 0;
    double totalMinutes = 0;
    for (final obj in includedObjects) {
      for (final proc in obj.processes) {
        totalMonthly += proc.totalCostPerUnit * proc.frequencyPerMonth;
        totalMinutes += proc.processTimeMins * proc.frequencyPerMonth;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Quote for ${_selectedCustomerName ?? "Customer"}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _previewData = null),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: includedObjects.isNotEmpty && !_generating
            ? _generateQuote
            : null,
        icon: _generating
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.receipt_long),
        label: Text(_generating ? 'Generating...' : 'Create Draft Invoice'),
        backgroundColor: includedObjects.isNotEmpty && !_generating
            ? null
            : theme.disabledColor,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          // Summary header
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedPropertyName ?? 'Property',
                  style: theme.textTheme.titleMedium,
                ),
                if (_selectedBuildingName != null)
                  Text(
                    _selectedBuildingName!,
                    style: theme.textTheme.bodySmall,
                  ),
                const Divider(),
                _summaryRow(
                  'Locations',
                  '${preview.locations.length}',
                ),
                _summaryRow(
                  'Objects with processes',
                  '${preview.objectEntries.length}',
                ),
                _summaryRow(
                  'Monthly estimate',
                  '\$${totalMonthly.toStringAsFixed(2)}',
                ),
                _summaryRow(
                  'Monthly time',
                  '${totalMinutes.toStringAsFixed(0)} min '
                      '(${(totalMinutes / 60).toStringAsFixed(1)} hrs)',
                ),
              ],
            ),
          ),

          // Objects with processes
          if (preview.objectEntries.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No objects with assigned processes found for this property. '
                'Assign processes to objects first, then come back to generate a quote.',
                style: theme.textTheme.bodyMedium,
              ),
            )
          else
            for (final obj in preview.objectEntries) ...[
              _buildObjectCard(obj, theme),
            ],
        ],
      ),
    );
  }

  Widget _buildObjectCard(QuoteObjectEntry obj, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          CheckboxListTile(
            value: obj.included,
            onChanged: (v) => setState(() => obj.included = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(obj.objectName, style: theme.textTheme.titleSmall),
            subtitle: obj.description.isNotEmpty
                ? Text(
                    obj.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  )
                : null,
          ),
          if (obj.included)
            for (final proc in obj.processes) ...[
              const Divider(height: 1, indent: 16, endIndent: 16),
              _buildProcessRow(proc, theme),
            ],
        ],
      ),
    );
  }

  Widget _buildProcessRow(QuoteObjectProcess proc, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(proc.processName, style: theme.textTheme.bodyMedium),
                Text(
                  '\$${proc.totalCostPerUnit.toStringAsFixed(2)}/service '
                  '(${proc.processTimeMins.toStringAsFixed(0)} min)',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  'Labor: \$${proc.laborCost.toStringAsFixed(2)} | '
                  'Materials: \$${proc.materialCost.toStringAsFixed(2)} | '
                  'Tools: \$${proc.toolCost.toStringAsFixed(2)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: DropdownButtonFormField<int>(
              value: proc.frequencyPerMonth,
              decoration: const InputDecoration(
                labelText: '/month',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                isDense: true,
              ),
              items: [0, 1, 2, 4, 5, 8, 12, 20, 22, 30]
                  .map((f) => DropdownMenuItem(
                        value: f,
                        child: Text('$f'),
                      ))
                  .toList(),
              onChanged: (v) =>
                  setState(() => proc.frequencyPerMonth = v ?? 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ─── Outcome View ───────────────────────────────────────────────

  Widget _buildOutcomeView(ThemeData theme) {
    final outcome = _outcome!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quote Created'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(Icons.check_circle,
                      color: theme.colorScheme.primary, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Draft invoice created',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${outcome.lineItemCount} line items',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Total: \$${outcome.total.toStringAsFixed(2)}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'You can review and edit the draft invoice in Finance > Invoices '
              'before sending it to the customer.',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DropdownItem {
  const _DropdownItem({required this.id, required this.name});
  final String id;
  final String name;
}
