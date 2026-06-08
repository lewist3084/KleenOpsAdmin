// ledger_entry_details.dart
//
// Detail view for a single ledger entry. Tapped from the Ledger list. Shows a
// ContainerHeader (who it was paid to + date) and a ContainerActionWidget with
// the amount, the plain-language profitability visual, and the double-entry
// accounts.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/containers/container_header.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:kleenops_admin/features/finances/screens/finance_ledger.dart'
    show profitabilityVisual;

class LedgerEntryDetailsScreen extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final Map<String, String> accountNames; // ref.path -> name
  final Map<String, String> accountTypes; // ref.path -> type

  const LedgerEntryDetailsScreen({
    super.key,
    required this.docId,
    required this.data,
    required this.accountNames,
    required this.accountTypes,
  });

  @override
  Widget build(BuildContext context) {
    final name = (data['name'] ?? data['memo'] ?? '(entry)').toString();
    final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
    final ts = data['createdAt'] as Timestamp?;
    final dateText = ts != null ? DateFormat.yMMMd().format(ts.toDate()) : '—';
    final debit = (data['debitAccountId'] as DocumentReference?)?.path;
    final credit = (data['creditAccountId'] as DocumentReference?)?.path;
    final debitName = debit != null ? (accountNames[debit] ?? '—') : '—';
    final creditName = credit != null ? (accountNames[credit] ?? '—') : '—';
    final visual = profitabilityVisual(
      debit != null ? accountTypes[debit] : null,
      credit != null ? accountTypes[credit] : null,
    );

    return Scaffold(
      backgroundColor: Colors.grey[100],
      drawer: const UserDrawer(),
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
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Icon(visual.icon, size: 18, color: visual.color),
                                  const SizedBox(width: 6),
                                  Text(visual.label,
                                      style: TextStyle(
                                          color: visual.color,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            _row(context, 'Debit', debitName),
                            _row(context, 'Credit', creditName),
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
