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
import 'package:shared_widgets/dialogs/dialog_select.dart';
import 'package:shared_widgets/finance/account_math.dart';
import 'package:shared_widgets/finance/ledger_entry_critic.dart';
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

  /// The organization this entry is paid to (top-level `organization` doc),
  /// once loaded — kept as the raw doc data so we tolerate both the registry
  /// schema (nameLower/website/category) and the older directory schema
  /// (websites/locations). Drives the "Paid to" header + unverified chip.
  String? _orgId;
  Map<String, dynamic>? _orgData;

  /// A stronger, already-verified registry org with the same normalized name as
  /// a still-`suggested` linked org — offered as "is this the same company?".
  _OrgRef? _candidate;

  /// A suspected duplicate of this entry (same money recorded twice), once the
  /// on-open scan finds one — drives the "Possible duplicate" banner.
  LedgerDuplicateMatch? _dupMatch;
  QueryDocumentSnapshot<Map<String, dynamic>>? _dupPartner;

  String get _orgName => (_orgData?['name'] ?? '').toString();
  bool get _orgIsSuggested => (_orgData?['status'] ?? '') == 'suggested';

  LedgerBalances get _balances => widget.balances;

  @override
  void initState() {
    super.initState();
    _loadOrg();
    _checkDuplicates();
  }

  /// Scans the ledger for another entry that looks like the same money recorded
  /// twice (the in-view half of the duplicate workflow — the server observer
  /// also surfaces this in My Tasks). Conservative: see [findLedgerDuplicates].
  Future<void> _checkDuplicates() async {
    if (_data['voided'] == true) return;
    final amount = (_data['amount'] as num?)?.toDouble();
    if (amount == null || amount.abs() < 0.005) return;

    final fs = FirebaseFirestore.instance;
    final categoryRef =
        fs.collection('timelineCategory').doc(kLedgerTimelineCategoryId);
    final selfPath = fs.collection('timeline').doc(widget.docId).path;

    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await fs
          .collection('timeline')
          .where('timelineCategoryId', isEqualTo: categoryRef)
          .where('amount', isEqualTo: amount)
          .get();
    } catch (_) {
      return; // never block the screen on a duplicate-scan read failure
    }

    final byPath = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    final candidates = <LedgerEntrySnapshot>[];
    LedgerEntrySnapshot? target;
    final suppressed = _pathSet(_data['notDuplicateOf']);
    for (final d in snap.docs) {
      final data = d.data();
      final snapshot = _snapshotOf(d.reference.path, data);
      if (d.id == widget.docId) {
        target = snapshot;
        continue;
      }
      if (data['voided'] == true) continue;
      // Symmetric suppression: the sibling has already been marked "not a dup".
      if (_pathSet(data['notDuplicateOf']).contains(selfPath)) continue;
      byPath[d.reference.path] = d;
      candidates.add(snapshot);
    }
    target ??= _snapshotOf(selfPath, _data);

    final matches = findLedgerDuplicates(
      target: target,
      candidates: candidates,
      suppressedIds: suppressed,
    );
    if (matches.isEmpty || !mounted) return;
    final best = matches.first;
    final partner = byPath[best.id];
    if (partner == null) return;
    setState(() {
      _dupMatch = best;
      _dupPartner = partner;
    });
  }

  LedgerEntrySnapshot _snapshotOf(String path, Map<String, dynamic> d) {
    final ts = d['createdAt'] as Timestamp?;
    return LedgerEntrySnapshot(
      id: path,
      amount: (d['amount'] as num?)?.toDouble() ?? 0.0,
      dateMs: ts?.millisecondsSinceEpoch,
      debitPath: (d['debitAccountId'] as DocumentReference?)?.path,
      creditPath: (d['creditAccountId'] as DocumentReference?)?.path,
      name: (d['name'] ?? d['memo'] ?? '').toString(),
      merchantKey: (d['merchantKey'] as String?) ?? '',
    );
  }

  /// Reads a `notDuplicateOf` field (list of doc paths or refs) into a path set.
  Set<String> _pathSet(dynamic v) {
    if (v is! List) return <String>{};
    return v
        .map((e) => e is DocumentReference ? e.path : e.toString())
        .toSet();
  }

  /// Voids this entry as a confirmed duplicate. A soft void: the doc is kept for
  /// audit but excluded from the ledger list and from every balance/statement
  /// (see [LedgerBalances.load]). The server observer closes the matching My
  /// Task automatically.
  Future<void> _voidEntry() async {
    final partner = _dupPartner;
    final messenger = ScaffoldMessenger.of(context);
    await FirebaseFirestore.instance
        .collection('timeline')
        .doc(widget.docId)
        .update({
      'voided': true,
      'voidReason': 'duplicate',
      if (partner != null) 'voidedOf': partner.reference.path,
      'voidedAt': FieldValue.serverTimestamp(),
    });
    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('Entry voided as a duplicate.')),
    );
    Navigator.of(context).pop();
  }

  /// Records that this entry and its suspected twin are NOT the same money, so
  /// neither flags the other again (written on both, mirroring the matcher).
  Future<void> _dismissDuplicate() async {
    final partner = _dupPartner;
    final messenger = ScaffoldMessenger.of(context);
    if (partner != null) {
      final fs = FirebaseFirestore.instance;
      final selfRef = fs.collection('timeline').doc(widget.docId);
      final batch = fs.batch();
      batch.update(selfRef, {
        'notDuplicateOf': FieldValue.arrayUnion([partner.reference.path]),
      });
      batch.update(partner.reference, {
        'notDuplicateOf': FieldValue.arrayUnion([selfRef.path]),
      });
      await batch.commit();
    }
    if (!mounted) return;
    setState(() {
      _dupMatch = null;
      _dupPartner = null;
    });
    messenger.showSnackBar(
      const SnackBar(content: Text('Marked as not a duplicate.')),
    );
  }

  /// Loads the linked organization and, when it is still `suggested`, looks for
  /// a verified registry org of the same name to offer as a merge target.
  Future<void> _loadOrg() async {
    final orgId = (_data['organizationId'] as String?)?.trim();
    if (orgId == null || orgId.isEmpty) {
      if (mounted) {
        setState(() {
          _orgId = null;
          _orgData = null;
          _candidate = null;
        });
      }
      return;
    }
    final fs = FirebaseFirestore.instance;
    final doc = await fs.collection('organization').doc(orgId).get();
    if (!doc.exists || !mounted) return;
    final data = doc.data()!;
    final status = (data['status'] ?? 'active').toString();
    final nameLower = (data['nameLower'] ?? _orgNameLower(data)).toString();
    _OrgRef? candidate;
    if (status == 'suggested' && nameLower.isNotEmpty) {
      // Single-field equality (no composite index); filter status client-side.
      final q = await fs
          .collection('organization')
          .where('nameLower', isEqualTo: nameLower)
          .limit(5)
          .get();
      for (final d in q.docs) {
        if (d.id == orgId) continue;
        if ((d.data()['status'] ?? '') == 'active') {
          candidate = _OrgRef(d.id, (d.data()['name'] ?? '').toString());
          break;
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _orgId = orgId;
      _orgData = data;
      _candidate = candidate;
    });
  }

  static String _orgNameLower(Map<String, dynamic> data) =>
      (data['name'] ?? '').toString().trim().toLowerCase();

  /// Promotes a suggested merchant org to `active` ("yes, this company is real").
  Future<void> _confirmCompany() async {
    final orgId = _orgId;
    if (orgId == null) return;
    final messenger = ScaffoldMessenger.of(context);
    await FirebaseFirestore.instance
        .collection('organization')
        .doc(orgId)
        .update({'status': 'active'});
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text('Confirmed $_orgName.')));
    await _loadOrg();
  }

  /// Re-links this entry to a pre-existing verified registry org (which already
  /// carries the public website/phone/address) instead of the suggested dupe —
  /// the "yes, it's the same company" action. Only public, org-level data is
  /// inherited; the org's contacts/people are never touched.
  Future<void> _useCandidate() async {
    final cand = _candidate;
    if (cand == null) return;
    final messenger = ScaffoldMessenger.of(context);
    await FirebaseFirestore.instance
        .collection('timeline')
        .doc(widget.docId)
        .update({'organizationId': cand.id, 'organizationName': cand.name});
    if (!mounted) return;
    setState(() {
      _data['organizationId'] = cand.id;
      _data['organizationName'] = cand.name;
    });
    messenger.showSnackBar(SnackBar(content: Text('Linked to ${cand.name}.')));
    await _loadOrg();
  }

  @override
  Widget build(BuildContext context) {
    final raw = (_data['name'] ?? _data['memo'] ?? '(entry)').toString();
    final paidTo = (_data['organizationName'] as String?)?.trim().isNotEmpty == true
        ? (_data['organizationName'] as String).trim()
        : raw;
    final note = (_data['note'] ?? '').toString().trim();
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
                        title: paidTo,
                        descriptionHeader: 'Date',
                        description: dateText,
                      ),
                      _verificationBanner(context),
                      _duplicateBanner(context),
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
                            if (raw.isNotEmpty)
                              _row(context, 'Transaction', raw),
                            if (note.isNotEmpty) _row(context, 'Notes', note),
                          ],
                        ),
                      ),
                      _companySection(context),
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

  /// Opens the transaction editor: who it was paid to (organization), the
  /// debited / credited accounts (hierarchical pickers), and a free-text note.
  /// Writes everything back to the ledger entry and refreshes in place.
  Future<void> _editAccounts() async {
    // Account doc paths, grouped by their top-level parent then by name, so the
    // pickers mirror the chart of accounts.
    final accountOptions = _balances.accountName.keys.toList()
      ..sort((a, b) {
        final byGroup = (_balances.groupLabelFor(a) ?? '')
            .toLowerCase()
            .compareTo((_balances.groupLabelFor(b) ?? '').toLowerCase());
        if (byGroup != 0) return byGroup;
        return (_balances.nameFor(a) ?? '')
            .toLowerCase()
            .compareTo((_balances.nameFor(b) ?? '').toLowerCase());
      });
    if (accountOptions.isEmpty) return;

    String? debitPath = (_data['debitAccountId'] as DocumentReference?)?.path;
    String? creditPath = (_data['creditAccountId'] as DocumentReference?)?.path;
    String? orgId = _data['organizationId'] as String?;
    String? orgName = _data['organizationName'] as String?;
    final noteCtrl =
        TextEditingController(text: (_data['note'] ?? '').toString());

    final oldDebitPath = debitPath;
    final oldCreditPath = creditPath;

    final messenger = ScaffoldMessenger.of(context);
    final saved = await showDialog<bool>(
      context: context,
      builder: (c) {
        return StatefulBuilder(
          builder: (c, setLocal) {
            return DialogAction(
              title: 'Edit Transaction',
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _pickerField(
                    label: 'Paid to',
                    value: (orgName ?? '').isEmpty ? '(none)' : orgName!,
                    icon: Icons.business_outlined,
                    onTap: () async {
                      final picked = await _pickOrganization(c, orgId);
                      if (picked != null) {
                        setLocal(() {
                          orgId = picked.id;
                          orgName = picked.name;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  _pickerField(
                    label: 'Debit account',
                    value: _balances.nameFor(debitPath) ?? '(none)',
                    icon: Icons.arrow_upward,
                    onTap: () async {
                      final p = await _pickAccount(
                          c, 'Debit account', accountOptions, debitPath);
                      if (p != null) setLocal(() => debitPath = p);
                    },
                  ),
                  const SizedBox(height: 12),
                  _pickerField(
                    label: 'Credit account',
                    value: _balances.nameFor(creditPath) ?? '(none)',
                    icon: Icons.arrow_downward,
                    onTap: () async {
                      final p = await _pickAccount(
                          c, 'Credit account', accountOptions, creditPath);
                      if (p != null) setLocal(() => creditPath = p);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      border: OutlineInputBorder(),
                    ),
                  ),
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

    final debitRef = FirebaseFirestore.instance.doc(debitPath!);
    final creditRef = FirebaseFirestore.instance.doc(creditPath!);
    final note = noteCtrl.text.trim();
    final update = <String, dynamic>{
      'debitAccountId': debitRef,
      'creditAccountId': creditRef,
      'categorizedBy': 'user',
      'note': note,
    };
    if (orgId != null) {
      update['organizationId'] = orgId;
      update['organizationName'] = orgName ?? '';
    }
    await FirebaseFirestore.instance
        .collection('timeline')
        .doc(widget.docId)
        .update(update);

    if (!mounted) return;
    setState(() {
      _data['debitAccountId'] = debitRef;
      _data['creditAccountId'] = creditRef;
      _data['categorizedBy'] = 'user';
      _data['note'] = note;
      if (orgId != null) {
        _data['organizationId'] = orgId;
        _data['organizationName'] = orgName ?? '';
      }
    });
    messenger.showSnackBar(
      const SnackBar(content: Text('Transaction updated.')),
    );

    // Refresh the linked-org header/banner if the company changed.
    await _loadOrg();

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

  /// "Unverified — Confirm" chip for a still-suggested merchant org, plus a
  /// "same company?" prompt when a verified registry org of the same name exists.
  Widget _verificationBanner(BuildContext context) {
    if (_orgData == null || !_orgIsSuggested) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.help_outline, size: 18, color: Colors.amber.shade800),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Unverified company — AI matched this transaction to '
                    '"$_orgName".',
                    style: TextStyle(color: Colors.amber.shade900),
                  ),
                ),
                TextButton(
                  onPressed: _confirmCompany,
                  child: const Text('Confirm'),
                ),
              ],
            ),
          ),
          if (_candidate != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(
                children: [
                  Icon(Icons.business, size: 18, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'We also found "${_candidate!.name}" in your '
                      'organizations. Same company?',
                      style: TextStyle(color: Colors.blue.shade900),
                    ),
                  ),
                  TextButton(
                    onPressed: _useCandidate,
                    child: const Text('Use it'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// "Possible duplicate" banner shown when the on-open scan found another
  /// ledger entry that looks like the same money. Offers a one-tap void of this
  /// entry or a "not a duplicate" dismissal.
  Widget _duplicateBanner(BuildContext context) {
    final match = _dupMatch;
    final partner = _dupPartner;
    if (match == null || partner == null) return const SizedBox.shrink();

    final pd = partner.data();
    final pName = (pd['name'] ?? pd['memo'] ?? '(entry)').toString();
    final pTs = pd['createdAt'] as Timestamp?;
    final pDate = pTs != null ? DateFormat.yMMMd().format(pTs.toDate()) : '—';
    final pAmount = (pd['amount'] as num?)?.toDouble();
    final pAmt = pAmount != null ? _money.format(pAmount) : '';
    final high = match.confidence == LedgerDuplicateConfidence.high;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: high ? Colors.red.shade50 : Colors.orange.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: high ? Colors.red.shade200 : Colors.orange.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.copy_all_outlined,
                    size: 18,
                    color: high ? Colors.red.shade700 : Colors.orange.shade800),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    high
                        ? 'Likely duplicate'
                        : 'Possible duplicate',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color:
                          high ? Colors.red.shade900 : Colors.orange.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(match.reason,
                style: TextStyle(
                    color:
                        high ? Colors.red.shade900 : Colors.orange.shade900)),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LedgerEntryDetailsScreen(
                    docId: partner.id,
                    data: pd,
                    balances: widget.balances,
                  ),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Matches: $pName'
                        '${pAmt.isEmpty ? '' : '  ·  $pAmt'}  ·  $pDate',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _dismissDuplicate,
                  child: const Text('Not a duplicate'),
                ),
                const SizedBox(width: 4),
                FilledButton.icon(
                  onPressed: _voidEntry,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Void this entry'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Public, org-level info from the linked organization (website, phone,
  /// domain, address, category). Deliberately excludes the org's
  /// contacts/people — only data the public would have about the company is
  /// shown here.
  Widget _companySection(BuildContext context) {
    final data = _orgData;
    if (data == null) return const SizedBox.shrink();
    final rows = <Widget>[];

    String firstString(dynamic v) {
      if (v is String) return v.trim();
      if (v is List && v.isNotEmpty) return v.first.toString().trim();
      return '';
    }

    // Registry schema uses singular `website`; older directory schema uses
    // `websites` (list). Accept either.
    final website = firstString(data['website']).isNotEmpty
        ? firstString(data['website'])
        : firstString(data['websites']);
    if (website.isNotEmpty) rows.add(_row(context, 'Website', website));

    final phone = firstString(data['phones']);
    if (phone.isNotEmpty) rows.add(_row(context, 'Phone', phone));

    final domain = firstString(data['domains']);
    if (domain.isNotEmpty) rows.add(_row(context, 'Domain', domain));

    // Public address from the first `locations` entry, if present.
    final locations = data['locations'];
    if (locations is List && locations.isNotEmpty && locations.first is Map) {
      final loc = Map<String, dynamic>.from(locations.first as Map);
      final addr = [loc['address'], loc['city'], loc['state'], loc['postalCode']]
          .map((e) => (e ?? '').toString().trim())
          .where((s) => s.isNotEmpty)
          .join(', ');
      if (addr.isNotEmpty) rows.add(_row(context, 'Address', addr));
    }

    final category = firstString(data['category']);
    if (category.isNotEmpty) rows.add(_row(context, 'Category', category));

    if (rows.isEmpty) return const SizedBox.shrink();
    return ContainerActionWidget(
      title: 'Company',
      actionText: '',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      ),
    );
  }

  /// A read-only, tappable form field that opens a picker dialog.
  Widget _pickerField({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          prefixIcon: Icon(icon),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(value, overflow: TextOverflow.ellipsis),
      ),
    );
  }

  /// Hierarchical account picker (grouped by top-level parent account), returns
  /// the chosen account doc path.
  Future<String?> _pickAccount(BuildContext context, String title,
      List<String> options, String? initial) {
    return showDialog<String>(
      context: context,
      builder: (c) => DialogSelect<String>(
        title: title,
        items: options,
        tileType: DialogSelectTileType.radio,
        initialSelection: initial,
        itemLabel: (p) => _balances.nameFor(p) ?? p,
        itemGroupLabel: (p) => _balances.groupLabelFor(p),
        itemSearchString: (p) =>
            '${_balances.nameFor(p) ?? ''} ${_balances.groupLabelFor(p) ?? ''}',
        onCancel: () => Navigator.pop(c),
        onSubmit: (res) => Navigator.pop(c, res.firstOrNull),
      ),
    );
  }

  /// Organization picker over the top-level registry (verified first), with an
  /// inline "add company" action. Returns the chosen org.
  Future<_OrgOption?> _pickOrganization(BuildContext context, String? initialId) {
    final stream = FirebaseFirestore.instance
        .collection('organization')
        .orderBy('nameLower')
        .limit(500)
        .snapshots()
        .map((s) => s.docs
            .map((d) => _OrgOption(
                  id: d.id,
                  name: (d.data()['name'] ?? '').toString(),
                  status: (d.data()['status'] ?? 'active').toString(),
                ))
            .toList());
    final initial =
        initialId == null ? null : _OrgOption(id: initialId, name: '', status: '');
    return showDialog<_OrgOption>(
      context: context,
      builder: (c) => DialogSelect.fromStream<_OrgOption>(
        title: 'Paid to',
        itemsStream: stream,
        tileType: DialogSelectTileType.radio,
        initialSelection: initial,
        itemLabel: (o) => o.name.isEmpty ? '(unnamed)' : o.name,
        itemGroupLabel: (o) => o.status == 'active' ? 'Verified' : 'Suggested',
        itemSearchString: (o) => o.name,
        onAdd: () => _addOrganization(c),
        addTooltip: 'Add a company',
        onCancel: () => Navigator.pop(c),
        onSubmit: (res) => Navigator.pop(c, res.firstOrNull),
      ),
    );
  }

  /// Creates a new suggested organization from a prompted name. The picker's
  /// live stream then surfaces it for selection.
  Future<void> _addOrganization(BuildContext context) async {
    final name = await _promptText(context, 'New company', 'Company name');
    if (name == null || name.trim().isEmpty) return;
    await FirebaseFirestore.instance.collection('organization').add({
      'name': name.trim(),
      'nameLower': name.trim().toLowerCase(),
      'status': 'suggested',
      'source': 'manual',
      'relationships': ['merchant'],
      'domains': <String>[],
      'phones': <String>[],
      'merchantKeys': <String>[],
      'transactionCount': 0,
      'emailCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'lastActivityAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String?> _promptText(
      BuildContext context, String title, String label) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (c) => DialogAction(
        title: title,
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
          onSubmitted: (_) => Navigator.pop(c, ctrl.text),
        ),
        cancelText: 'Cancel',
        onCancel: () => Navigator.pop(c),
        actionText: 'Add',
        onAction: () => Navigator.pop(c, ctrl.text),
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

/// A verified registry org offered as the "same company?" target.
class _OrgRef {
  const _OrgRef(this.id, this.name);
  final String id;
  final String name;
}

/// An option in the "Paid to" organization picker. Equality is by id so a
/// stub built from the current `organizationId` preselects the live item.
class _OrgOption {
  const _OrgOption({required this.id, required this.name, required this.status});
  final String id;
  final String name;
  final String status;

  @override
  bool operator ==(Object other) => other is _OrgOption && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
