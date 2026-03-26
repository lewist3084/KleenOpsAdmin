// lib/features/finances/forms/financeBillForm.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:kleenops_admin/services/firestore_service.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/forms/cancel_save_adapter.dart';
import 'package:shared_widgets/search/search_field_action.dart';

class FinanceBillForm extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final String? docId;

  const FinanceBillForm({
    super.key,
    required this.companyRef,
    this.docId,
  });

  @override
  State<FinanceBillForm> createState() => _FinanceBillFormState();
}

class _FinanceBillFormState extends State<FinanceBillForm> {
  final _formKey = GlobalKey<FormState>();
  final _billNumberController = TextEditingController();
  final _taxController = TextEditingController();
  final _notesController = TextEditingController();
  final _dateFormat = DateFormat.yMMMd();

  DocumentReference<Map<String, dynamic>>? _vendorRef;
  String _vendorName = '';
  DocumentReference<Map<String, dynamic>>? _purchaseOrderRef;
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
    }
  }

  Future<void> _loadData() async {
    final doc =
        await FirebaseFirestore.instance.collection('bill').doc(widget.docId).get();
    if (doc.exists) {
      final data = doc.data()!;
      _billNumberController.text = data['billNumber'] ?? '';
      _taxController.text = (data['tax'] as num?)?.toString() ?? '';
      _notesController.text = data['notes'] ?? '';

      final rawVendor = data['vendorId'];
      if (rawVendor is DocumentReference<Object?>) {
        _vendorRef = rawVendor as DocumentReference<Map<String, dynamic>>?;
      }
      _vendorName = (data['vendorName'] ?? '') as String;

      final rawPO = data['purchaseOrderId'];
      if (rawPO is DocumentReference<Object?>) {
        _purchaseOrderRef =
            rawPO as DocumentReference<Map<String, dynamic>>?;
      }

      final issueDateTs = data['issueDate'] as Timestamp?;
      if (issueDateTs != null) _issueDate = issueDateTs.toDate();

      final dueDateTs = data['dueDate'] as Timestamp?;
      if (dueDateTs != null) _dueDate = dueDateTs.toDate();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickDate({required bool isIssueDate}) async {
    final initial = isIssueDate ? _issueDate : (_dueDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isIssueDate) {
          _issueDate = picked;
        } else {
          _dueDate = picked;
        }
      });
    }
  }

  Future<void> _onPurchaseOrderSelected(
      DocumentReference<Map<String, dynamic>>? poRef) async {
    setState(() => _purchaseOrderRef = poRef);
    if (poRef == null) return;

    // Auto-populate vendor from the PO.
    try {
      final poSnap = await poRef.get();
      final poData = poSnap.data();
      if (poData == null) return;

      final rawVendor = poData['vendorId'];
      if (rawVendor is DocumentReference<Object?>) {
        final vendorRef = rawVendor as DocumentReference<Map<String, dynamic>>;
        final vendorSnap = await vendorRef.get();
        final vendorData = vendorSnap.data();
        if (vendorData != null && mounted) {
          setState(() {
            _vendorRef = vendorRef;
            _vendorName = (vendorData['name'] ?? '') as String;
          });
        }
      } else {
        // Try vendorName directly on PO.
        final poVendorName = poData['vendorName'];
        if (poVendorName is String && poVendorName.isNotEmpty && mounted) {
          setState(() => _vendorName = poVendorName);
        }
      }
    } catch (_) {
      // Best-effort only.
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final tax = double.tryParse(_taxController.text.trim()) ?? 0.0;

    final data = <String, dynamic>{
      'billNumber': _billNumberController.text.trim(),
      'vendorId': _vendorRef,
      'vendorName': _vendorName,
      'issueDate': Timestamp.fromDate(_issueDate),
      'tax': tax,
      'notes': _notesController.text.trim(),
    };

    if (_dueDate != null) {
      data['dueDate'] = Timestamp.fromDate(_dueDate!);
    }

    if (_purchaseOrderRef != null) {
      data['purchaseOrderId'] = _purchaseOrderRef;
    }

    // Defaults for new bills.
    if (widget.docId == null) {
      data['status'] = 'unpaid';
      data['amountPaid'] = 0;
      data['total'] = tax; // will be updated when line items are added
    }

    await FirestoreService().saveDocument(
      collectionRef: FirebaseFirestore.instance.collection('bill'),
      data: data,
      docId: widget.docId,
    );

    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _billNumberController.dispose();
    _taxController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isEdit = widget.docId != null;
    final title = isEdit ? 'Edit Bill' : 'New Bill';

    return Scaffold(
      appBar: StandardAppBar(title: title),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Bill Number
            TextFormField(
              controller: _billNumberController,
              decoration: const InputDecoration(
                labelText: 'Bill Number',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Enter bill number'
                  : null,
            ),
            const SizedBox(height: 16),

            // Vendor dropdown
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('companyCompany')
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
                  label: 'Vendor',
                  items: items,
                  initialValue: _vendorRef,
                  itemLabel: (ref) {
                    final d = docs.firstWhere(
                      (doc) => doc.reference == ref,
                      orElse: () => docs.first,
                    );
                    return (d.data()['name'] ?? 'Unnamed Vendor') as String;
                  },
                  onChanged: (val) {
                    setState(() => _vendorRef = val);
                    // Resolve vendor name.
                    if (val != null) {
                      final match = docs.where((d) => d.reference == val);
                      if (match.isNotEmpty) {
                        _vendorName =
                            (match.first.data()['name'] ?? '') as String;
                      }
                    }
                  },
                );
              },
            ),
            const SizedBox(height: 16),

            // Purchase Order (optional)
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('purchaseOrder')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox(
                    height: 60,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) return const SizedBox.shrink();
                final items = docs.map((d) => d.reference).toList();
                return SearchAddSelectDropdown<
                    DocumentReference<Map<String, dynamic>>>(
                  label: 'Purchase Order (optional)',
                  items: items,
                  initialValue: _purchaseOrderRef,
                  itemLabel: (ref) {
                    final d = docs.firstWhere(
                      (doc) => doc.reference == ref,
                      orElse: () => docs.first,
                    );
                    final poNumber = d.data()['poNumber'] ?? d.id;
                    return 'PO #$poNumber';
                  },
                  onChanged: _onPurchaseOrderSelected,
                );
              },
            ),
            const SizedBox(height: 16),

            // Issue Date
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Issue Date'),
              subtitle: Text(_dateFormat.format(_issueDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _pickDate(isIssueDate: true),
            ),
            const Divider(),

            // Due Date
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Due Date'),
              subtitle: Text(
                _dueDate != null ? _dateFormat.format(_dueDate!) : 'Not set',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _pickDate(isIssueDate: false),
            ),
            const Divider(),
            const SizedBox(height: 16),

            // Tax
            TextFormField(
              controller: _taxController,
              decoration: const InputDecoration(
                labelText: 'Tax',
                border: OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
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
}
