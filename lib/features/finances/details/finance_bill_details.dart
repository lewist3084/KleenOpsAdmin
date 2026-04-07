// lib/features/finances/details/finance_bill_details.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/features/finances/forms/finance_bill_form.dart';
import 'package:kleenops_admin/features/finances/services/finance_bill_service.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:shared_widgets/containers/container_header.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:shared_widgets/tiles/standard_tile_small.dart';

class FinanceBillDetailsScreen extends ConsumerStatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final String docId;

  const FinanceBillDetailsScreen({
    super.key,
    required this.companyRef,
    required this.docId,
  });

  @override
  ConsumerState<FinanceBillDetailsScreen> createState() =>
      _FinanceBillDetailsScreenState();
}

class _FinanceBillDetailsScreenState
    extends ConsumerState<FinanceBillDetailsScreen> {
  final _currencyFormat = NumberFormat.currency(symbol: '\$');
  final _dateFormat = DateFormat.yMMMd();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: null,
      drawer: const UserDrawer(),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('bill')
              .doc(widget.docId)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data?.data();
            if (data == null) {
              return const Center(child: Text('Bill not found'));
            }

            final billNumber = (data['billNumber'] ?? '') as String;
            final vendorName = (data['vendorName'] ?? '') as String;
            final status = (data['status'] ?? 'unpaid') as String;
            final total = (data['total'] as num?)?.toDouble() ?? 0.0;
            final amountPaid =
                (data['amountPaid'] as num?)?.toDouble() ?? 0.0;
            final tax = (data['tax'] as num?)?.toDouble() ?? 0.0;
            final notes = (data['notes'] ?? '') as String;

            final issueDateTs = data['issueDate'] as Timestamp?;
            final dueDateTs = data['dueDate'] as Timestamp?;
            final issueDateStr = issueDateTs != null
                ? _dateFormat.format(issueDateTs.toDate())
                : '\u2014';
            final dueDateStr = dueDateTs != null
                ? _dateFormat.format(dueDateTs.toDate())
                : '\u2014';

            return SafeArea(
              top: true,
              bottom: false,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 120),
                children: [
                  ContainerHeader(
                    showImage: false,
                    titleHeader: 'Bill',
                    title: billNumber.isNotEmpty ? '#$billNumber' : '\u2014',
                    descriptionHeader: 'Vendor',
                    description:
                        vendorName.isNotEmpty ? vendorName : '\u2014',
                  ),
                  const SizedBox(height: 8),
                  // Status + payment summary
                  _buildStatusSection(
                    status: status,
                    total: total,
                    amountPaid: amountPaid,
                    tax: tax,
                    issueDate: issueDateStr,
                    dueDate: dueDateStr,
                  ),
                  // Line Items
                  _buildLineItemsSection(),
                  // Payment History
                  _buildPaymentHistorySection(),
                  // Notes
                  if (notes.isNotEmpty) _buildNotesSection(notes),
                ],
              ),
            );
          },
        ),
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final menuSections = MenuDrawerSections(
            actions: [
              ContentMenuItem(
                icon: Icons.edit_outlined,
                label: 'Edit Bill',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FinanceBillForm(
                        companyRef: widget.companyRef,
                        docId: widget.docId,
                      ),
                    ),
                  );
                },
              ),
              ContentMenuItem(
                icon: Icons.payment_outlined,
                label: 'Record Payment',
                onTap: () => _showRecordPaymentDialog(),
              ),
              ContentMenuItem(
                icon: Icons.home_outlined,
                label: 'Finance Home',
                onTap: () => context.push(AppRoutePaths.financeHome),
              ),
            ],
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DetailsAppBar(
                title: 'Bill',
                menuSections: menuSections,
              ),
              const HomeNavBarAdapter(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusSection({
    required String status,
    required double total,
    required double amountPaid,
    required double tax,
    required String issueDate,
    required String dueDate,
  }) {
    final remaining = total - amountPaid;
    final statusColor = status == 'paid'
        ? Colors.green
        : status == 'partial'
            ? Colors.orange
            : Colors.red;

    return ContainerActionWidget(
      title: 'Status',
      actionText: '',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Total', _currencyFormat.format(total)),
          _buildInfoRow('Amount Paid', _currencyFormat.format(amountPaid)),
          _buildInfoRow('Remaining', _currencyFormat.format(remaining)),
          if (tax > 0) _buildInfoRow('Tax', _currencyFormat.format(tax)),
          _buildInfoRow('Issue Date', issueDate),
          _buildInfoRow('Due Date', dueDate),
          if (status != 'paid') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showRecordPaymentDialog,
                icon: const Icon(Icons.payment),
                label: const Text('Record Payment'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildLineItemsSection() {
    return ContainerActionWidget(
      title: 'Line Items',
      actionText: '',
      content: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('bill')
            .doc(widget.docId)
            .collection('lineItem')
            .orderBy('createdAt')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No line items',
                style: TextStyle(color: Colors.grey[600]),
              ),
            );
          }
          return Column(
            children: snapshot.data!.docs.map((doc) {
              final d = doc.data();
              final description =
                  (d['description'] ?? 'Item') as String;
              final qty = (d['quantity'] as num?)?.toDouble() ?? 1;
              final unitPrice =
                  (d['unitPrice'] as num?)?.toDouble() ?? 0.0;
              final lineTotal = qty * unitPrice;

              return StandardTileSmallDart(
                label: description,
                secondaryText:
                    '${qty.toStringAsFixed(0)} x ${_currencyFormat.format(unitPrice)} = ${_currencyFormat.format(lineTotal)}',
                leadingIcon: Icons.inventory_2_outlined,
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildPaymentHistorySection() {
    return ContainerActionWidget(
      title: 'Payment History',
      actionText: '',
      content: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('payment')
            .where('billId',
                isEqualTo: FirebaseFirestore.instance
                    .collection('bill')
                    .doc(widget.docId))
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No payments recorded',
                style: TextStyle(color: Colors.grey[600]),
              ),
            );
          }
          return Column(
            children: snapshot.data!.docs.map((doc) {
              final d = doc.data();
              final amount =
                  (d['amount'] as num?)?.toDouble() ?? 0.0;
              final method = (d['method'] ?? '') as String;
              final ts = d['createdAt'] as Timestamp?;
              final dateStr =
                  ts != null ? _dateFormat.format(ts.toDate()) : '';

              return StandardTileSmallDart(
                label: _currencyFormat.format(amount),
                secondaryText:
                    '${method.isNotEmpty ? method : 'Payment'}  |  $dateStr',
                leadingIcon: Icons.payment_outlined,
                leadingIconColor: Colors.green,
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildNotesSection(String notes) {
    return ContainerActionWidget(
      title: 'Notes',
      actionText: '',
      content: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(notes),
      ),
    );
  }

  Future<void> _showRecordPaymentDialog() async {
    final amountController = TextEditingController();
    DocumentReference<Map<String, dynamic>>? selectedAccount;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Record Payment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('account')
                      .orderBy('name')
                      .snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snap.data!.docs;
                    return DropdownButtonFormField<
                        DocumentReference<Map<String, dynamic>>>(
                      initialValue: selectedAccount,
                      decoration: const InputDecoration(
                        labelText: 'Account',
                        border: OutlineInputBorder(),
                      ),
                      items: docs.map((d) {
                        final name = d.data()['name'] ?? 'Unnamed';
                        return DropdownMenuItem(
                          value: d.reference,
                          child: Text(name),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setDialogState(() => selectedAccount = val),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount =
                    double.tryParse(amountController.text.trim());
                if (amount == null || amount <= 0 || selectedAccount == null) {
                  return;
                }
                Navigator.of(ctx).pop();
                try {
                  await FinanceBillService().recordBillPayment(
                    billRef: FirebaseFirestore.instance
                        .collection('bill')
                        .doc(widget.docId),
                    amount: amount,
                    companyRef: widget.companyRef,
                    accountRef: selectedAccount!,
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Payment recorded')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    amountController.dispose();
  }
}
