// lib/features/finances/details/financeInvoiceDetails.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/features/finances/forms/financeInvoiceForm.dart';
import 'package:kleenops_admin/features/finances/forms/financeInvoiceLineItemForm.dart';
import 'package:kleenops_admin/features/finances/services/finance_invoice_service.dart';
import 'package:kleenops_admin/features/finances/services/payment_link_service.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:shared_widgets/containers/container_header.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:shared_widgets/tiles/standard_tile_small.dart';

class FinanceInvoiceDetailsScreen extends ConsumerStatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final String docId;

  const FinanceInvoiceDetailsScreen({
    super.key,
    required this.companyRef,
    required this.docId,
  });

  @override
  ConsumerState<FinanceInvoiceDetailsScreen> createState() =>
      _FinanceInvoiceDetailsScreenState();
}

class _FinanceInvoiceDetailsScreenState
    extends ConsumerState<FinanceInvoiceDetailsScreen> {
  final _invoiceService = FinanceInvoiceService();
  final _paymentLinkService = PaymentLinkService();

  DocumentReference<Map<String, dynamic>> get _invoiceRef =>
      FirebaseFirestore.instance.collection('invoice').doc(widget.docId);

  // ---------------------------------------------------------------
  // Status Actions
  // ---------------------------------------------------------------

  Future<void> _markAsSent() async {
    await _invoiceService.updateInvoiceStatus(_invoiceRef, 'sent');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice marked as sent')),
      );
    }
  }

  Future<void> _markAsPaid() async {
    await _invoiceService.updateInvoiceStatus(_invoiceRef, 'paid');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice marked as paid')),
      );
    }
  }

  Future<void> _showRecordPaymentDialog(
      Map<String, dynamic> invoiceData) async {
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record Payment'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: amountController,
            decoration: const InputDecoration(
              labelText: 'Amount',
              border: OutlineInputBorder(),
              prefixText: '\$ ',
            ),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Enter amount';
              final parsed = double.tryParse(v.trim());
              if (parsed == null || parsed <= 0) {
                return 'Enter a valid amount';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx)
                    .pop(double.parse(amountController.text.trim()));
              }
            },
            child: const Text('Record'),
          ),
        ],
      ),
    );

    amountController.dispose();

    if (result != null && result > 0) {
      await _invoiceService.recordPayment(
        invoiceRef: _invoiceRef,
        amount: result,
        companyRef: widget.companyRef,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Payment of \$${result.toStringAsFixed(2)} recorded',
            ),
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------
  // Payment Link Actions
  // ---------------------------------------------------------------

  Future<void> _sendPaymentLink(Map<String, dynamic> invoiceData) async {
    try {
      final result = await _paymentLinkService.createAndSendPaymentLink(
        companyRef: widget.companyRef,
        invoiceRef: _invoiceRef,
        invoiceData: invoiceData,
      );
      if (mounted) {
        final sentTo = <String>[];
        if (result['emailSent'] == true) sentTo.add('email');
        if (result['smsSent'] == true) sentTo.add('SMS');
        final channel = sentTo.isEmpty ? '' : ' via ${sentTo.join(' & ')}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment link sent$channel')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  // ---------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: null,
      drawer: const UserDrawer(),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _invoiceRef.snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data?.data();
            if (data == null) {
              return const Center(child: Text('Invoice not found'));
            }

            final invoiceNumber =
                (data['invoiceNumber'] ?? '').toString();
            final customerName =
                (data['customerName'] ?? 'No Customer') as String;
            final status = (data['status'] ?? 'draft') as String;
            final subtotal =
                (data['subtotal'] as num?)?.toDouble() ?? 0.0;
            final tax = (data['tax'] as num?)?.toDouble() ?? 0.0;
            final total = (data['total'] as num?)?.toDouble() ?? 0.0;
            final amountPaid =
                (data['amountPaid'] as num?)?.toDouble() ?? 0.0;
            final amountDue =
                (data['amountDue'] as num?)?.toDouble() ?? total;
            final notes = (data['notes'] ?? '') as String;
            final issueDateTs = data['issueDate'] as Timestamp?;
            final dueDateTs = data['dueDate'] as Timestamp?;
            final issueDate = issueDateTs != null
                ? _formatDate(issueDateTs.toDate())
                : '---';
            final dueDate = dueDateTs != null
                ? _formatDate(dueDateTs.toDate())
                : '---';

            return SafeArea(
              top: true,
              bottom: false,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 120),
                children: [
                  ContainerHeader(
                    showImage: false,
                    titleHeader: 'Invoice',
                    title: '#$invoiceNumber',
                    descriptionHeader: 'Customer',
                    description: customerName,
                  ),
                  const SizedBox(height: 8),
                  // Status section
                  _buildStatusSection(status, data),
                  // Dates
                  _buildDatesSection(issueDate, dueDate),
                  // Line items
                  _buildLineItemsSection(subtotal, tax, total),
                  // Totals summary
                  _buildTotalsSection(
                    subtotal: subtotal,
                    tax: tax,
                    total: total,
                    amountPaid: amountPaid,
                    amountDue: amountDue,
                  ),
                  // Payment history
                  _buildPaymentHistorySection(),
                  // Notes
                  if (notes.isNotEmpty)
                    ContainerActionWidget(
                      title: 'Notes',
                      actionText: '',
                      content: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(notes),
                      ),
                    ),
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
                label: 'Edit Invoice',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FinanceInvoiceForm(
                        companyRef: widget.companyRef,
                        docId: widget.docId,
                      ),
                    ),
                  );
                },
              ),
              ContentMenuItem(
                icon: Icons.add_outlined,
                label: 'Add Line Item',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FinanceInvoiceLineItemForm(
                        invoiceRef: _invoiceRef,
                      ),
                    ),
                  );
                },
              ),
              ContentMenuItem(
                icon: Icons.payment_outlined,
                label: 'Record Payment',
                onTap: () async {
                  final snap = await _invoiceRef.get();
                  final invoiceData = snap.data();
                  if (invoiceData != null && mounted) {
                    _showRecordPaymentDialog(invoiceData);
                  }
                },
              ),
              ContentMenuItem(
                icon: Icons.link_outlined,
                label: 'Send Payment Link',
                onTap: () async {
                  final snap = await _invoiceRef.get();
                  final invoiceData = snap.data();
                  if (invoiceData != null && mounted) {
                    _sendPaymentLink(invoiceData);
                  }
                },
              ),
              ContentMenuItem(
                icon: Icons.home_outlined,
                label: 'Finances Home',
                onTap: () => context.push(AppRoutePaths.financeHome),
              ),
            ],
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DetailsAppBar(
                title: 'Invoice',
                menuSections: menuSections,
              ),
              const HomeNavBarAdapter(),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------
  // Section Builders
  // ---------------------------------------------------------------

  Widget _buildStatusSection(String status, Map<String, dynamic> data) {
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
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _statusColor(status).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _statusLabel(status),
                  style: TextStyle(
                    color: _statusColor(status),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (status == 'draft')
                OutlinedButton.icon(
                  icon: const Icon(Icons.send_outlined, size: 18),
                  label: const Text('Mark as Sent'),
                  onPressed: _markAsSent,
                ),
              if (status == 'sent' ||
                  status == 'partial' ||
                  status == 'overdue')
                OutlinedButton.icon(
                  icon: const Icon(Icons.payment_outlined, size: 18),
                  label: const Text('Record Payment'),
                  onPressed: () => _showRecordPaymentDialog(data),
                ),
              if (status != 'paid')
                OutlinedButton.icon(
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Mark as Paid'),
                  onPressed: _markAsPaid,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDatesSection(String issueDate, String dueDate) {
    return ContainerActionWidget(
      title: 'Dates',
      actionText: '',
      content: Column(
        children: [
          StandardTileSmallDart(
            label: 'Issue Date: $issueDate',
            leadingIcon: Icons.calendar_today_outlined,
          ),
          StandardTileSmallDart(
            label: 'Due Date: $dueDate',
            leadingIcon: Icons.event_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildLineItemsSection(
      double subtotal, double tax, double total) {
    return ContainerActionWidget(
      title: 'Line Items',
      headerActionText: 'Add',
      onHeaderAction: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FinanceInvoiceLineItemForm(
              invoiceRef: _invoiceRef,
            ),
          ),
        );
      },
      actionText: '',
      content: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _invoiceRef
            .collection('lineItem')
            .orderBy('position')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No line items yet',
                style: TextStyle(color: Colors.grey[600]),
              ),
            );
          }

          final docs = snapshot.data!.docs;
          return Column(
            children: docs.map((doc) {
              final d = doc.data();
              final description =
                  (d['description'] ?? '') as String;
              final qty =
                  (d['quantity'] as num?)?.toDouble() ?? 0;
              final unitPrice =
                  (d['unitPrice'] as num?)?.toDouble() ?? 0;
              final amount =
                  (d['amount'] as num?)?.toDouble() ?? 0;

              return StandardTileSmallDart(
                label: description,
                secondaryText:
                    '${qty.toStringAsFixed(qty.truncateToDouble() == qty ? 0 : 2)}'
                    ' x \$${unitPrice.toStringAsFixed(2)}'
                    ' = \$${amount.toStringAsFixed(2)}',
                leadingIcon: Icons.inventory_2_outlined,
                trailingIcon1: Icons.edit_outlined,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FinanceInvoiceLineItemForm(
                        invoiceRef: _invoiceRef,
                        docId: doc.id,
                      ),
                    ),
                  );
                },
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildTotalsSection({
    required double subtotal,
    required double tax,
    required double total,
    required double amountPaid,
    required double amountDue,
  }) {
    return ContainerActionWidget(
      title: 'Summary',
      actionText: '',
      content: Column(
        children: [
          _totalRow('Subtotal', subtotal),
          _totalRow('Tax', tax),
          const Divider(),
          _totalRow('Total', total, bold: true),
          _totalRow('Amount Paid', amountPaid),
          const Divider(),
          _totalRow('Amount Due', amountDue, bold: true),
        ],
      ),
    );
  }

  Widget _totalRow(String label, double value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '\$${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
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
            .where('invoiceId', isEqualTo: _invoiceRef)
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
              final ts = d['createdAt'] as Timestamp?;
              final dateStr =
                  ts != null ? _formatDate(ts.toDate()) : '---';
              final method = (d['method'] ?? '') as String;

              return StandardTileSmallDart(
                label: '\$${amount.toStringAsFixed(2)}',
                secondaryText:
                    '$dateStr${method.isNotEmpty ? ' - $method' : ''}',
                leadingIcon: Icons.payment_outlined,
                leadingIconColor: Colors.green,
              );
            }).toList(),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------

  String _statusLabel(String status) {
    switch (status) {
      case 'draft':
        return 'Draft';
      case 'sent':
        return 'Sent';
      case 'partial':
        return 'Partially Paid';
      case 'paid':
        return 'Paid';
      case 'overdue':
        return 'Overdue';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'draft':
        return Colors.grey;
      case 'sent':
        return Colors.blue;
      case 'partial':
        return Colors.orange;
      case 'paid':
        return Colors.green;
      case 'overdue':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}
