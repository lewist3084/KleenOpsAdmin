// finance_import_statements.dart
//
// Manual statement import (overlord scope). Lets the user backfill history
// Plaid can't reach (Plaid caps at ~24 months) by importing downloaded bank /
// credit-card statements — a group of PDFs, images, OFX/QFX/QBO, or CSV at
// once. Files are added through the SAME shared FileUploaderField used app-wide,
// then a Cloud Function extracts + de-duplicates the transactions. The user
// reviews the staged rows and commits them into the same `bankTransaction`
// collection Plaid writes to, so categorization / AI bookkeeping /
// reconciliation all take over unchanged.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/containers/container_header.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/dialogs/dialog_select.dart';
import 'package:shared_widgets/fields/file_uploader.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:kleenops_admin/features/finances/services/plaid_service.dart';

class FinanceImportStatementsScreen extends StatefulWidget {
  const FinanceImportStatementsScreen({super.key});

  @override
  State<FinanceImportStatementsScreen> createState() =>
      _FinanceImportStatementsScreenState();
}

class _FinanceImportStatementsScreenState
    extends State<FinanceImportStatementsScreen> {
  // Admin banking = the overlord / platform's own books (top-level).
  final PlaidService _service = PlaidService.overlord();

  // Batch id for a NEW import (files upload into this folder up-front).
  late final String _newBatchId = _service.newImportBatchId();

  // The batch currently being processed/reviewed — either [_newBatchId] after
  // Extract, or a pending batch the user reopened.
  String? _activeBatchId;

  String? _bankAccountId;
  String? _selectedAccountName;
  List<Map<String, dynamic>> _documents = const [];

  bool _extracting = false;
  bool _committing = false;
  bool _started = false; // extraction has been kicked off (runs in background)
  String? _error;

  static final NumberFormat _money = NumberFormat.currency(symbol: '\$');
  static final DateFormat _date = DateFormat('MMM d, yyyy');

  // ── Extraction ──────────────────────────────────────────────────────────

  Future<void> _extract() async {
    if (_bankAccountId == null || _documents.isEmpty) return;
    setState(() {
      _extracting = true;
      _error = null;
    });
    try {
      final files = _documents.map((d) {
        final ext = (d['fileExtension'] ?? '').toString();
        return <String, dynamic>{
          'downloadUrl': d['url'],
          'fileName': d['fileName'],
          'fileType': ext.replaceAll('.', '').toLowerCase(),
        };
      }).toList();

      await _service.importStatements(
        bankAccountId: _bankAccountId!,
        importBatchId: _newBatchId,
        files: files,
      );
      if (!mounted) return;
      // Extraction now runs in the background per file; the UI tracks the live
      // batch status and shows the review list the moment it's ready.
      setState(() {
        _extracting = false;
        _started = true;
        _activeBatchId = _newBatchId;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _extracting = false;
        _error = e.toString();
      });
    }
  }

  // ── Commit ──────────────────────────────────────────────────────────────

  Future<void> _commit(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    setState(() => _committing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final rows = docs.map((d) {
        final data = d.data();
        return <String, dynamic>{
          'rowId': d.id,
          'included': data['included'] == true,
          'amount': data['amount'],
          'name': data['name'],
          'dateMillis': (data['date'] as Timestamp?)?.millisecondsSinceEpoch,
        };
      }).toList();

      final committed = await _service.commitImport(
          importBatchId: _activeBatchId!, rows: rows);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        duration: const Duration(seconds: 5),
        backgroundColor: Colors.green,
        content: Text('Imported $committed transaction(s). '
            'Run the AI Bookkeeper or Reconciliation to categorize them.'),
      ));
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        duration: const Duration(seconds: 6),
        content: Text('Import failed: $e'),
      ));
    } finally {
      if (mounted) setState(() => _committing = false);
    }
  }

  // ── Row edits (local: write straight back to the staged row doc) ─────────

  void _toggleRow(DocumentReference<Map<String, dynamic>> ref, bool value) {
    ref.update({'included': value});
  }

  Future<void> _editRow(
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> data,
  ) async {
    final nameCtl = TextEditingController(text: (data['name'] ?? '').toString());
    // Show the amount the way a person reads a statement: money OUT negative.
    final signed = -((data['amount'] as num?)?.toDouble() ?? 0);
    final amtCtl = TextEditingController(text: signed.toStringAsFixed(2));
    DateTime date =
        (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Edit transaction'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtl,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              TextField(
                controller: amtCtl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: const InputDecoration(
                  labelText: 'Amount (negative = money out)',
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: Text('Date: ${_date.format(date)}')),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: date,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setLocal(() => date = picked);
                    },
                    child: const Text('Change'),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      final entered = double.tryParse(amtCtl.text.trim());
      await ref.update({
        'name': nameCtl.text.trim(),
        if (entered != null) 'amount': -entered, // back to Plaid convention
        'date': Timestamp.fromDate(date),
      });
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      drawer: const UserDrawer(),
      body: StandardCanvas(
        child: SafeArea(
          top: true,
          bottom: false,
          child: Stack(
            children: [
              Positioned.fill(child: _buildBody()),
              const Positioned(
                  left: 0, right: 0, top: 0, child: CanvasTopBookend()),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(title: 'Import Statements'),
          HomeNavBarAdapter(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    // Once an import is running/being reviewed, the screen is just that batch.
    if (_started) {
      return ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _intro(),
          _statusGate(),
        ],
      );
    }

    // Otherwise: any pending imports to resume, then the new-import form.
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _intro(),
        _pendingImports(),
        _accountPicker(),
        _uploader(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
      ],
    );
  }

  /// Watches the batch doc: shows live extraction progress, then the review
  /// list once the background extraction + de-dup is done.
  Widget _statusGate() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _service.watchImportBatch(_activeBatchId!),
      builder: (context, snap) {
        final data = snap.data?.data();
        final status = (data?['status'] ?? 'extracting').toString();
        if (status == 'ready') return _reviewSection();

        final fileCount = (data?['fileCount'] as num?)?.toInt() ?? 0;
        final filesDone = (data?['filesDone'] as num?)?.toInt() ?? 0;
        final rowsFound = (data?['rowsFound'] as num?)?.toInt() ?? 0;
        final finalizing = status == 'finalizing';
        return ContainerActionWidget(
          title: 'Extracting',
          actionText: '',
          onAction: null,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(finalizing
                        ? 'Checking for duplicates…'
                        : 'Reading statements in the background…'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (fileCount > 0)
                LinearProgressIndicator(
                  value: finalizing ? null : filesDone / fileCount,
                ),
              const SizedBox(height: 8),
              Text(
                '$filesDone of $fileCount file(s) processed · '
                '$rowsFound transaction(s) found so far',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                'You can leave this open — it keeps working even on large '
                'batches.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _intro() => const ContainerHeader(
        showImage: false,
        titleHeader: 'Import older statements',
        title: '',
        descriptionHeader: 'About',
        description:
            'Add a batch of bank or credit-card statements (PDF, photo, '
            'OFX/QFX, CSV, or Excel). We extract the transactions, flag likely '
            'duplicates, and let you review before they post to your books.',
      );

  /// Imports the user started and navigated away from. Extraction keeps running
  /// in the background; tapping one reopens it to watch progress / review.
  Widget _pendingImports() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _service.watchRecentImportBatches(),
      builder: (context, snap) {
        final pending = (snap.data?.docs ?? []).where((d) {
          final s = (d.data()['status'] ?? '').toString();
          return s != 'committed' && s.isNotEmpty;
        }).toList();
        if (pending.isEmpty) return const SizedBox.shrink();

        return ContainerActionWidget(
          title: 'In progress',
          actionText: '',
          onAction: null,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...pending.map((d) {
                final data = d.data();
                final status = (data['status'] ?? '').toString();
                final fileCount = (data['fileCount'] as num?)?.toInt() ?? 0;
                final filesDone = (data['filesDone'] as num?)?.toInt() ?? 0;
                final rowCount = (data['rowCount'] as num?)?.toInt() ??
                    (data['rowsFound'] as num?)?.toInt() ?? 0;
                final created = (data['createdAt'] as Timestamp?)?.toDate();
                final ready = status == 'ready';
                final label = ready
                    ? 'Ready to review · $rowCount transaction(s)'
                    : status == 'finalizing'
                        ? 'Checking duplicates…'
                        : 'Extracting · $filesDone/$fileCount file(s)';
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    ready ? Icons.fact_check_outlined : Icons.hourglass_top,
                    color: ready ? Colors.green : Colors.orange,
                  ),
                  title: Text(label),
                  subtitle: created != null
                      ? Text('Started ${_date.format(created)}')
                      : null,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => setState(() {
                    _activeBatchId = d.id;
                    _started = true;
                  }),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _accountPicker() {
    return ContainerActionWidget(
      title: 'Import into',
      actionText: '',
      onAction: null,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _started ? null : _pickAccount,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedAccountName ?? 'Select an account',
                      style: TextStyle(
                        color: _selectedAccountName == null
                            ? Colors.grey[600]
                            : null,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_drop_down, color: Colors.grey[700]),
                ],
              ),
            ),
          ),
          TextButton.icon(
            onPressed: _started ? null : _createManualAccount,
            icon: const Icon(Icons.add),
            label: const Text('New account (not linked to a bank)'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAccount() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) =>
          DialogSelect.fromStream<QueryDocumentSnapshot<Map<String, dynamic>>>(
        title: 'Select account',
        itemsStream: _service.watchBankLinkedAccounts(),
        itemLabel: (d) => (d.data()['name'] ?? 'Account').toString(),
        emptyStateText: 'No accounts yet — add one below.',
        onCancel: () => Navigator.of(ctx).pop(),
        onSubmit: (res) {
          Navigator.of(ctx).pop();
          final doc = res.firstOrNull;
          if (doc == null) return;
          final ba = doc.data()['bankAccountId'];
          final id = ba is DocumentReference ? ba.id : null;
          if (id != null) {
            setState(() {
              _bankAccountId = id;
              _selectedAccountName = (doc.data()['name'] ?? '').toString();
            });
          }
        },
      ),
    );
  }

  Future<void> _createManualAccount() async {
    final nameCtl = TextEditingController();
    String subtype = 'checking';
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('New account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtl,
                decoration: const InputDecoration(
                    labelText: 'Account name (e.g. Old Checking)'),
              ),
              const SizedBox(height: 8),
              DropdownButton<String>(
                isExpanded: true,
                value: subtype,
                items: const [
                  DropdownMenuItem(value: 'checking', child: Text('Checking')),
                  DropdownMenuItem(value: 'savings', child: Text('Savings')),
                  DropdownMenuItem(
                      value: 'credit card', child: Text('Credit card')),
                ],
                onChanged: (v) => setLocal(() => subtype = v ?? 'checking'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    if (created != true || nameCtl.text.trim().isEmpty) return;
    try {
      final type = subtype == 'credit card' ? 'credit' : 'depository';
      final name = nameCtl.text.trim();
      final id = await _service.createManualAccount(
        name: name,
        subtype: subtype,
        type: type,
      );
      if (mounted) {
        setState(() {
          _bankAccountId = id;
          _selectedAccountName = name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create account: $e')),
        );
      }
    }
  }

  Widget _uploader() {
    final canExtract = _bankAccountId != null &&
        _documents.isNotEmpty &&
        !_extracting &&
        !_started;
    return ContainerActionWidget(
      title: 'Statements',
      actionText: '',
      onAction: null,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FileUploaderField(
            allowDocuments: true,
            allowImages: false,
            allowVideos: false,
            documentStorageFolder: _service.importFolderPath(_newBatchId),
            documentHintText:
                'Add each statement file (PDF, photo, OFX/QFX, CSV, or Excel).',
            documents: _documents,
            onDocumentsChanged: (docs) => setState(() => _documents = docs),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: canExtract ? _extract : null,
            icon: _extracting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome),
            label: Text(_extracting
                ? 'Reading ${_documents.length} file(s)…'
                : 'Extract transactions'),
          ),
        ],
      ),
    );
  }

  Widget _reviewSection() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _service.watchImportRows(_activeBatchId!),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const ContainerActionWidget(
            title: 'Review',
            actionText: '',
            onAction: null,
            content: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const ContainerActionWidget(
            title: 'Review',
            actionText: '',
            onAction: null,
            content: Text('No transactions were found in those files.'),
          );
        }
        final includedCount =
            docs.where((d) => d.data()['included'] == true).length;

        return ContainerActionWidget(
          title: 'Review (${docs.length})',
          actionText: '',
          onAction: null,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...docs.map(_rowTile),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: (_committing || includedCount == 0)
                    ? null
                    : () => _commit(docs),
                icon: _committing
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check),
                label: Text(_committing
                    ? 'Importing…'
                    : 'Import $includedCount transaction(s)'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _rowTile(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final included = data['included'] == true;
    final isDup = data['isDuplicate'] == true;
    final amount = (data['amount'] as num?)?.toDouble() ?? 0;
    final isOut = amount >= 0; // Plaid convention: positive = money out
    final displayAmount = _money.format(amount.abs());
    final date = (data['date'] as Timestamp?)?.toDate();

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      color: isDup ? Colors.orange[50] : null,
      child: ListTile(
        dense: true,
        leading: Checkbox(
          value: included,
          onChanged: (v) => _toggleRow(doc.reference, v ?? false),
        ),
        title: Text(
          (data['name'] ?? '').toString(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text([
          if (date != null) _date.format(date),
          if (isDup) 'possible duplicate',
        ].join(' · ')),
        trailing: Text(
          '${isOut ? '-' : '+'}$displayAmount',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isOut ? Colors.red[700] : Colors.green[700],
          ),
        ),
        onTap: () => _editRow(doc.reference, data),
      ),
    );
  }
}
