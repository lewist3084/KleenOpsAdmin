// lib/features/finances/forms/finance_invoice_line_item_form.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kleenops_admin/features/finances/services/finance_invoice_service.dart';
import 'package:shared_widgets/services/firestore_service.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/forms/cancel_save_adapter.dart';

class FinanceInvoiceLineItemForm extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> invoiceRef;
  final String? docId;

  const FinanceInvoiceLineItemForm({
    super.key,
    required this.invoiceRef,
    this.docId,
  });

  @override
  State<FinanceInvoiceLineItemForm> createState() =>
      _FinanceInvoiceLineItemFormState();
}

class _FinanceInvoiceLineItemFormState
    extends State<FinanceInvoiceLineItemForm> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _unitPriceController = TextEditingController();
  final _invoiceService = FinanceInvoiceService();

  bool _saving = false;
  bool _loading = true;

  double get _calculatedAmount {
    final qty = double.tryParse(_quantityController.text.trim()) ?? 0;
    final price =
        double.tryParse(_unitPriceController.text.trim()) ?? 0;
    return qty * price;
  }

  @override
  void initState() {
    super.initState();
    if (widget.docId != null) {
      _loadData();
    } else {
      _loading = false;
    }
  }

  Future<void> _loadData() async {
    final doc = await widget.invoiceRef
        .collection('lineItem')
        .doc(widget.docId)
        .get();
    if (doc.exists) {
      final data = doc.data()!;
      _descriptionController.text = data['description'] ?? '';
      _quantityController.text =
          (data['quantity'] ?? 1).toString();
      _unitPriceController.text =
          (data['unitPrice'] ?? '').toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final qty =
        double.tryParse(_quantityController.text.trim()) ?? 1;
    final unitPrice =
        double.tryParse(_unitPriceController.text.trim()) ?? 0;
    final amount = qty * unitPrice;

    final lineItemCollection = widget.invoiceRef.collection('lineItem');

    final data = <String, dynamic>{
      'description': _descriptionController.text.trim(),
      'quantity': qty,
      'unitPrice': unitPrice,
      'amount': amount,
    };

    // Assign position for new items.
    if (widget.docId == null) {
      final existing = await lineItemCollection
          .orderBy('position', descending: true)
          .limit(1)
          .get();
      int nextPosition = 0;
      if (existing.docs.isNotEmpty) {
        final lastPos = existing.docs.first.data()['position'];
        if (lastPos is num) nextPosition = lastPos.toInt() + 1;
      }
      data['position'] = nextPosition;
    }

    await FirestoreService().saveDocument(
      collectionRef: lineItemCollection,
      data: data,
      docId: widget.docId,
    );

    // Recalculate the parent invoice totals.
    await _invoiceService.recalculateInvoiceTotals(widget.invoiceRef);

    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _quantityController.dispose();
    _unitPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isEdit = widget.docId != null;
    final title = isEdit ? 'Edit Line Item' : 'New Line Item';

    return Scaffold(
      appBar: StandardAppBar(title: title),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Enter a description'
                  : null,
            ),
            const SizedBox(height: 16),

            // Quantity
            TextFormField(
              controller: _quantityController,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter quantity';
                final parsed = double.tryParse(v.trim());
                if (parsed == null || parsed <= 0) {
                  return 'Enter a valid quantity';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Unit Price
            TextFormField(
              controller: _unitPriceController,
              decoration: const InputDecoration(
                labelText: 'Unit Price',
                border: OutlineInputBorder(),
                prefixText: '\$ ',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Enter unit price';
                }
                final parsed = double.tryParse(v.trim());
                if (parsed == null || parsed < 0) {
                  return 'Enter a valid price';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Calculated Amount
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Amount',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '\$${_calculatedAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: CancelSaveBar(
        onCancel: () => Navigator.of(context).pop(),
        onSave: _saving ? null : _save,
        isSaving: _saving,
      ),
    );
  }
}
