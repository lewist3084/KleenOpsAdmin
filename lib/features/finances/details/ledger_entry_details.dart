// ledger_entry_details.dart
//
// Detail view for a single ledger entry. Tapped from the Ledger list. Shows who
// it was paid to + the date, then a Details block with the amount and the two
// double-entry accounts — each prefixed by a neutral up/down arrow showing
// whether that account increased or decreased.
//
// An edit FAB opens a focused editor for just the debited / credited accounts
// (the date and payee are intentionally not editable here).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/containers/container_header.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:shared_widgets/finance/account_math.dart';
import 'package:shared_widgets/finance/ledger_entry_tile.dart' show provenanceSpec;
import 'package:shared_widgets/finance/merchant_key.dart';
import 'package:shared_widgets/finance/transaction_categorizer_service.dart'
    show kLedgerTimelineCategoryId;
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';

class LedgerEntryDetailsScreen extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final LedgerBalances balances;

  const LedgerEntryDetailsScreen({
    super.key,
    required this.docId,
    required this.data,
    required this.balances,
  });

  @override
  State<LedgerEntryDetailsScreen> createState() =>
      _LedgerEntryDetailsScreenState();
}

class _LedgerEntryDetailsScreenState extends State<LedgerEntryDetailsScreen> {
  static final NumberFormat _money = NumberFormat.currency(symbol: '\$');

  late final Map<String, dynamic> _data = Map<String, dynamic>.from(widget.data);

  LedgerBalances get _balances => widget.balances;

  @override
  Widget build(BuildContext context) {
    final name = (_data['name'] ?? _data['memo'] ?? '(entry)').toString();
    final amount = (_data['amount'] as num?)?.toDouble() ?? 0.0;
    final ts = _data['createdAt'] as Timestamp?;
    final dateText = ts != null ? DateFormat.yMMMd().format(ts.toDate()) : '—';
    final debit = (_data['debitAccountId'] as DocumentReference?)?.path;
    final credit = (_data['creditAccountId'] as DocumentReference?)?.path;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      drawer: const UserDrawer(),
      floatingActionButton: FloatingActionButton(
        onPressed: _editAccounts,
        tooltip: 'Edit accounts',
        child: const Icon(Icons.edit),
      ),
      body: StandardCanvas(
        child: SafeArea(
          top: true,
          bottom: false,
          child: Stack(
            children: [
              Positioned.fill(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 120),
                  child: Column(
                    children: [
                      ContainerHeader(
                        showImage: false,
                        titleHeader: 'Paid to',
                        title: name,
                        descriptionHeader: 'Date',
                        description: dateText,
                      ),
                      ContainerActionWidget(
                        title: 'Details',
                        actionText: '',
                        content: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _row(context, 'Amount',
                                '\$${amount.toStringAsFixed(2)}'),
                            _accountRow(context, 'Debit', debit,
                                isDebitSide: true),
                            _accountRow(context, 'Credit', credit,
                                isDebitSide: false),
                            _provenanceRow(context),
                            _anomalyRow(context),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Positioned(
                  left: 0, right: 0, top: 0, child: CanvasTopBookend()),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(title: 'Transaction'),
          HomeNavBarAdapter(),
        ],
      ),
    );
  }

  /// Opens a focused editor for the debited / credited accounts only — the date
  /// and payee are fixed. Writes the new account references back to the ledger
  /// entry and refreshes the screen in place.
  Future<void> _editAccounts() async {
    // Account options (path → name), sorted by name.
    final options = _balances.accountName.entries.toList()
      ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
    if (options.isEmpty) return;

    String? debitPath = (_data['debitAccountId'] as DocumentReference?)?.path;
    String? creditPath = (_data['creditAccountId'] as DocumentReference?)?.path;

    final messenger = ScaffoldMessenger.of(context);
    final saved = await showDialog<bool>(
      context: context,
      builder: (c) {
        return StatefulBuilder(
          builder: (c, setLocal) {
            DropdownButtonFormField<String> dropdown(
                String label, String? value, ValueChanged<String?> onChanged) {
              return DropdownButtonFormField<String>(
                initialValue: value,
                isExpanded: true,
                decoration: InputDecoration(labelText: label),
                items: [
                  for (final e in options)
                    DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: onChanged,
              );
            }

            return DialogAction(
              title: 'Edit Accounts',
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  dropdown('Debit account', debitPath,
                      (v) => setLocal(() => debitPath = v)),
                  const SizedBox(height: 16),
                  dropdown('Credit account', creditPath,
                      (v) => setLocal(() => creditPath = v)),
                ],
              ),
              cancelText: 'Cancel',
              onCancel: () => Navigator.pop(c, false),
              actionText: 'Save',
              onAction: () => Navigator.pop(c, true),
            );
          },
        );
      },
    );

    if (saved != true || !mounted) return;
    if (debitPath == null || creditPath == null) return;

    final oldDebitPath = (_data['debitAccountId'] as DocumentReference?)?.path;
    final oldCreditPath = (_data['creditAccountId'] as DocumentReference?)?.path;

    final debitRef = FirebaseFirestore.instance.doc(debitPath!);
    final creditRef = FirebaseFirestore.instance.doc(creditPath!);
    await FirebaseFirestore.instance
        .collection('timeline')
        .doc(widget.docId)
        .update({
      'debitAccountId': debitRef,
      'creditAccountId': creditRef,
      'categorizedBy': 'user',
    });

    if (!mounted) return;
    setState(() {
      _data['debitAccountId'] = debitRef;
      _data['creditAccountId'] = creditRef;
      _data['categorizedBy'] = 'user';
    });
    messenger.showSnackBar(
      const SnackBar(content: Text('Accounts updated.')),
    );

    // Learn from the correction + offer to apply it to the same merchant
    // elsewhere. Only the leg that actually changed is the "category".
    String? side;
    DocumentReference<Map<String, dynamic>>? categoryRef;
    if (debitPath != oldDebitPath) {
      side = 'debitAccountId';
      categoryRef = debitRef;
    } else if (creditPath != oldCreditPath) {
      side = 'creditAccountId';
      categoryRef = creditRef;
    }
    if (side != null && categoryRef != null) {
      await _learnAndPropagate(side: side, categoryRef: categoryRef);
    }
  }

  /// Records a user-confirmed categorization rule (the strongest signal) keyed
  /// by the merchant's stable [merchantKey], then offers to apply the same fix
  /// to every other transaction from that merchant still booked the old way.
  Future<void> _learnAndPropagate({
    required String side,
    required DocumentReference<Map<String, dynamic>> categoryRef,
  }) async {
    final fs = FirebaseFirestore.instance;
    final name = (_data['name'] ?? _data['memo'] ?? '').toString();
    final mKey = (_data['merchantKey'] as String?)?.trim().isNotEmpty == true
        ? (_data['merchantKey'] as String)
        : merchantKey(name);
    if (mKey.isEmpty) return;

    // 1. Persist the user rule (overrides AI/crowd for this merchant forever).
    //    accountName/accountType are denormalized so the cross-company
    //    consensus trigger can tally without an extra read.
    await fs.collection('categorizationRule').doc(mKey).set({
      'merchantKey': mKey,
      'merchantName': name,
      'merchantNameNormalized': mKey,
      'accountRef': categoryRef,
      'accountName': _balances.nameFor(categoryRef.path) ?? '',
      'accountType': _balances.typeFor(categoryRef.path) ?? '',
      'accountSide': side,
      'source': 'user',
      'confidence': 'high',
      'updatedAt': FieldValue.serverTimestamp(),
      'usageCount': FieldValue.increment(1),
    }, SetOptions(merge: true));

    // 2. Find sibling entries from the same merchant still booked differently.
    final siblings = await fs
        .collection('timeline')
        .where('merchantKey', isEqualTo: mKey)
        .get();
    final stale = siblings.docs.where((d) {
      if (d.id == widget.docId) return false;
      final data = d.data();
      if ((data['timelineCategory'] ?? '') != kLedgerTimelineCategoryId) {
        return false;
      }
      final legPath = (data[side] as DocumentReference?)?.path;
      return legPath != categoryRef.path;
    }).toList();

    if (stale.isEmpty || !mounted) return;
    await _showPropagateDialog(side: side, categoryRef: categoryRef, stale: stale);
  }

  Future<void> _showPropagateDialog({
    required String side,
    required DocumentReference<Map<String, dynamic>> categoryRef,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> stale,
  }) async {
    final newName = _balances.nameFor(categoryRef.path) ?? 'the new account';
    final selected = {for (final d in stale) d.id: true};

    final apply = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setLocal) {
          return DialogAction(
            title: 'Apply to similar transactions?',
            content: SizedBox(
              width: double.infinity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${stale.length} other transaction(s) from this merchant '
                      'are booked differently. Re-book them to "$newName" too?',
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          for (final d in stale)
                            CheckboxListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              value: selected[d.id],
                              onChanged: (v) =>
                                  setLocal(() => selected[d.id] = v ?? false),
                              title: Text(
                                (d.data()['name'] ?? '').toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(_subtitleFor(d.data(), side)),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            cancelText: 'Just this one',
            onCancel: () => Navigator.pop(c, false),
            actionText: 'Apply to selected',
            onAction: () => Navigator.pop(c, true),
          );
        },
      ),
    );

    if (apply != true || !mounted) return;
    final fs = FirebaseFirestore.instance;
    final toUpdate = stale.where((d) => selected[d.id] == true).toList();
    final batch = fs.batch();
    for (final d in toUpdate) {
      batch.update(d.reference, {side: categoryRef, 'categorizedBy': 'user'});
    }
    await batch.commit();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Updated ${toUpdate.length} transaction(s).')),
    );
  }

  String _subtitleFor(Map<String, dynamic> data, String side) {
    final ts = data['createdAt'] as Timestamp?;
    final date = ts != null ? DateFormat.yMMMd().format(ts.toDate()) : '';
    final amount = (data['amount'] as num?)?.toDouble();
    final amt = amount != null ? _money.format(amount) : '';
    final current = _balances.nameFor((data[side] as DocumentReference?)?.path);
    return [date, amt, if (current != null) '→ $current']
        .where((s) => s.isNotEmpty)
        .join('  ·  ');
  }

  /// A Debit/Credit row prefixed by the per-account up/down movement (gray),
  /// then the account name, its current balance, and a reconciliation hint when
  /// the book balance differs from the bank's reported balance.
  Widget _accountRow(
    BuildContext context,
    String label,
    String? path, {
    required bool isDebitSide,
  }) {
    final accountName = _balances.nameFor(path) ?? '—';
    final type = _balances.typeFor(path) ?? '';
    final increases = entryIncreasesAccount(type: type, isDebitSide: isDebitSide);
    final balance = _balances.balanceFor(path);
    final bankBalance = _balances.bankBalanceFor(path);
    final mismatch = balance != null &&
        bankBalance != null &&
        (balance - bankBalance).abs() >= 0.01;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(width: 12),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Arrow in front of the account: up if this entry increases the
                // account, down if it decreases it. Neutral gray.
                Icon(
                  increases ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    balance != null
                        ? '$accountName  (${_money.format(balance)})'
                        : accountName,
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (mismatch) ...[
                  const SizedBox(width: 4),
                  Tooltip(
                    message: 'Book balance differs from bank '
                        '(${_money.format(bankBalance)})',
                    child: Icon(Icons.warning_amber_rounded,
                        size: 16, color: Colors.amber.shade700),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _anomalyRow(BuildContext context) {
    if (_data['amountAnomaly'] != true) return const SizedBox.shrink();
    final exp = (_data['expectedAmount'] as num?)?.toDouble();
    final msg = exp != null
        ? 'Unusual amount — usually ~${_money.format(exp)}'
        : 'Unusual amount for this merchant';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(Icons.report_problem_outlined,
              size: 18, color: Colors.orange.shade800),
          const SizedBox(width: 8),
          Expanded(
            child: Text(msg,
                style: TextStyle(color: Colors.orange.shade900)),
          ),
        ],
      ),
    );
  }

  Widget _provenanceRow(BuildContext context) {
    final spec = provenanceSpec(_data['categorizedBy']?.toString());
    if (spec == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Categorized by', style: TextStyle(color: Colors.grey.shade700)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(spec.icon, size: 16, color: spec.color),
              const SizedBox(width: 4),
              Text(spec.label,
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: spec.color)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
