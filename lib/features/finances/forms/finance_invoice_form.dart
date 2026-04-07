// lib/features/finances/forms/finance_invoice_form.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kleenops_admin/features/finances/details/finance_invoice_details.dart';
import 'package:kleenops_admin/features/finances/services/finance_invoice_service.dart';
import 'package:shared_widgets/services/firestore_service.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/forms/cancel_save_adapter.dart';
import 'package:shared_widgets/search/search_field_action.dart';

class FinanceInvoiceForm extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final String? docId;
  final String? customerId;
  final DocumentReference<Map<String, dynamic>>? initialCustomerRef;

  const FinanceInvoiceForm({
    super.key,
    required this.companyRef,
    this.docId,
    this.customerId,
    this.initialCustomerRef,
  });

  @override
  State<FinanceInvoiceForm> createState() => _FinanceInvoiceFormState();
}

class _FinanceInvoiceFormState extends State<FinanceInvoiceForm> {
  final _formKey = GlobalKey<FormState>();
  final _taxController = TextEditingController(text: '0');
  final _notesController = TextEditingController();
  final _invoiceService = FinanceInvoiceService();

  DocumentReference<Map<String, dynamic>>? _customerRef;
  String _customerName = '';
  DateTime _issueDate = DateTime.now();
  DateTime? _dueDate;
  bool _saving = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.docId != null) {
      _loadData();
    } else {
      _loading = false;
      // Pre-select customer if provided.
      if (widget.initialCustomerRef != null) {
        _customerRef = widget.initialCustomerRef;
        _loadCustomerName(_customerRef!);
      } else if (widget.customerId != null) {
        _customerRef = FirebaseFirestore.instance
            .collection('customer')
            .doc(widget.customerId);
        _loadCustomerName(_customerRef!);
      }
      // Default due date to 30 days from now.
      _dueDate = DateTime.now().add(const Duration(days: 30));
    }
  }

  Future<void> _loadCustomerName(
      DocumentReference<Map<String, dynamic>> ref) async {
    final snap = await ref.get();
    if (snap.exists && mounted) {
      setState(() {
        _customerName = (snap.data()?['name'] ?? '') as String;
      });
    }
  }

  Future<void> _loadData() async {
    final doc = await FirebaseFirestore.instance
        .collection('invoice')
        .doc(widget.docId)
        .get();
    if (doc.exists) {
      final data = doc.data()!;
      _taxController.text = (data['tax'] ?? 0).toString();
      _notesController.text = data['notes'] ?? '';

      final rawCustomer = data['customerId'];
      if (rawCustomer is DocumentReference) {
        _customerRef =
            rawCustomer as DocumentReference<Map<String, dynamic>>;
        await _loadCustomerName(_customerRef!);
      }
      _customerName = (data['customerName'] ?? '') as String;

      final issueDateTs = data['issueDate'] as Timestamp?;
      if (issueDateTs != null) _issueDate = issueDateTs.toDate();

      final dueDateTs = data['dueDate'] as Timestamp?;
      if (dueDateTs != null) _dueDate = dueDateTs.toDate();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickDate({required bool isIssueDate}) async {
    final initial = isIssueDate
        ? _issueDate
        : (_dueDate ?? DateTime.now().add(const Duration(days: 30)));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isIssueDate) {
          _issueDate = picked;
        } else {
          _dueDate = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_customerRef == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer')),
      );
      return;
    }
    setState(() => _saving = true);

    final tax = double.tryParse(_taxController.text.trim()) ?? 0.0;

    final data = <String, dynamic>{
      'customerId': _customerRef,
      'customerName': _customerName,
      'issueDate': Timestamp.fromDate(_issueDate),
      'dueDate':
          _dueDate != null ? Timestamp.fromDate(_dueDate!) : null,
      'tax': tax,
      'notes': _notesController.text.trim(),
    };

    if (widget.docId == null) {
      // Create new invoice.
      data['status'] = 'draft';
      data['subtotal'] = 0.0;
      data['total'] = tax;
      data['amountPaid'] = 0.0;
      data['amountDue'] = tax;

      final docRef =
          await _invoiceService.createInvoice(widget.companyRef, data);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => FinanceInvoiceDetailsScreen(
              companyRef: widget.companyRef,
              docId: docRef.id,
            ),
          ),
        );
      }
    } else {
      // Update existing invoice.
      await FirestoreService().saveDocument(
        collectionRef: FirebaseFirestore.instance.collection('invoice'),
        data: data,
        docId: widget.docId,
      );

      // Recalculate totals since tax may have changed.
      final invoiceRef = FirebaseFirestore.instance
          .collection('invoice')
          .doc(widget.docId);
      await _invoiceService.recalculateInvoiceTotals(invoiceRef);

      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _taxController.dispose();
    _notesController.dispose();
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
    final title = isEdit ? 'Edit Invoice' : 'New Invoice';

    return Scaffold(
      appBar: StandardAppBar(title: title),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Customer selector
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('customer')
                  .orderBy('name')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox(
                    height: 60,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final docs = snapshot.data!.docs;
                final items = docs.map((d) => d.reference).toList();
                return SearchAddSelectDropdown<
                    DocumentReference<Map<String, dynamic>>>(
                  label: 'Customer',
                  items: items,
                  initialValue: _customerRef,
                  itemLabel: (ref) {
                    final d =
                        docs.firstWhere((doc) => doc.reference == ref);
                    return (d.data()['name'] ?? 'Unnamed') as String;
                  },
                  searchLabelText: 'Search Customers',
                  onChanged: (val) {
                    setState(() {
                      _customerRef = val;
                      if (val != null) {
                        final d = docs.firstWhere(
                            (doc) => doc.reference == val);
                        _customerName =
                            (d.data()['name'] ?? '') as String;
                      } else {
                        _customerName = '';
                      }
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 16),

            // Issue Date
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Issue Date'),
              subtitle: Text(_formatDate(_issueDate)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () => _pickDate(isIssueDate: true),
            ),
            const Divider(height: 1),

            // Due Date
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Due Date'),
              subtitle: Text(
                _dueDate != null ? _formatDate(_dueDate!) : 'Not set',
              ),
              trailing: const Icon(Icons.event_outlined),
              onTap: () => _pickDate(isIssueDate: false),
            ),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Tax
            TextFormField(
              controller: _taxController,
              decoration: const InputDecoration(
                labelText: 'Tax Amount',
                border: OutlineInputBorder(),
                prefixText: '\$ ',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                if (double.tryParse(v.trim()) == null) {
                  return 'Enter a valid number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Notes
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
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

  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}
