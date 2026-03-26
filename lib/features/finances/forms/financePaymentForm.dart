// lib/features/finances/forms/financePaymentForm.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:kleenops_admin/services/firestore_service.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/forms/cancel_save_adapter.dart';
import 'package:shared_widgets/search/search_field_action.dart';

class FinancePaymentForm extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;

  const FinancePaymentForm({
    super.key,
    required this.companyRef,
  });

  @override
  State<FinancePaymentForm> createState() => _FinancePaymentFormState();
}

class _FinancePaymentFormState extends State<FinancePaymentForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _referenceNumberController = TextEditingController();
  final _notesController = TextEditingController();
  final _dateFormat = DateFormat.yMMMd();

  /// 'received' or 'made'
  String _paymentType = 'received';
  String _method = 'transfer';
  DateTime _paymentDate = DateTime.now();

  // Received fields
  DocumentReference<Map<String, dynamic>>? _customerRef;
  DocumentReference<Map<String, dynamic>>? _invoiceRef;
  String _invoiceNumber = '';

  // Made fields
  DocumentReference<Map<String, dynamic>>? _vendorRef;
  DocumentReference<Map<String, dynamic>>? _billRef;
  String _billNumber = '';

  // Account
  DocumentReference<Map<String, dynamic>>? _accountRef;

  bool _saving = false;

  static const _methods = ['cash', 'check', 'card', 'transfer', 'other'];

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _paymentDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;

    final categoryRef = FirebaseFirestore.instance
        .collection('timelineCategory')
        .doc('jlXgbQiOKD3VjWd7AztM');

    final user = FirebaseAuth.instance.currentUser;
    final userRef = user != null
        ? FirebaseFirestore.instance.collection('user').doc(user.uid)
        : null;

    // 1. Build payment data.
    final paymentData = <String, dynamic>{
      'amount': amount,
      'type': _paymentType,
      'method': _method,
      'date': Timestamp.fromDate(_paymentDate),
      'referenceNumber': _referenceNumberController.text.trim(),
      'notes': _notesController.text.trim(),
      'accountId': _accountRef,
    };

    if (_paymentType == 'received') {
      paymentData['customerId'] = _customerRef;
      paymentData['invoiceId'] = _invoiceRef;
      paymentData['invoiceNumber'] = _invoiceNumber;
    } else {
      paymentData['vendorId'] = _vendorRef;
      paymentData['billId'] = _billRef;
      paymentData['billNumber'] = _billNumber;
    }

    // 2. Save payment doc.
    await FirestoreService().saveDocument(
      collectionRef: FirebaseFirestore.instance.collection('payment'),
      data: paymentData,
    );

    // 3. Update linked invoice or bill amountPaid.
    if (_paymentType == 'received' && _invoiceRef != null) {
      await _updateLinkedDocAmountPaid(_invoiceRef!, amount);
    } else if (_paymentType == 'made' && _billRef != null) {
      await _updateLinkedDocAmountPaid(_billRef!, amount);
    }

    // 4. Create journal entry.
    final journalName = _paymentType == 'received'
        ? 'Payment received${_invoiceNumber.isNotEmpty ? ': Invoice #$_invoiceNumber' : ''}'
        : 'Payment made${_billNumber.isNotEmpty ? ': Bill #$_billNumber' : ''}';

    await FirestoreService().saveDocument(
      collectionRef: FirebaseFirestore.instance.collection('timeline'),
      data: {
        'name': journalName,
        'amount': amount,
        'debitAccountId': _accountRef,
        'creditAccountId': _accountRef,
        'timelineCategoryId': categoryRef,
        'timelineCategory': 'jlXgbQiOKD3VjWd7AztM',
        'type': 'payment_$_paymentType',
        if (userRef != null) 'createdBy': userRef,
      },
    );

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _updateLinkedDocAmountPaid(
    DocumentReference<Map<String, dynamic>> docRef,
    double paymentAmount,
  ) async {
    try {
      final snap = await docRef.get();
      final data = snap.data();
      if (data == null) return;

      final total = (data['total'] as num?)?.toDouble() ?? 0.0;
      final previouslyPaid =
          (data['amountPaid'] as num?)?.toDouble() ?? 0.0;
      final newAmountPaid = previouslyPaid + paymentAmount;

      String newStatus;
      if (newAmountPaid >= total) {
        newStatus = 'paid';
      } else if (newAmountPaid > 0) {
        newStatus = 'partial';
      } else {
        newStatus = 'unpaid';
      }

      await docRef.update({
        'amountPaid': newAmountPaid,
        'status': newStatus,
      });
    } catch (_) {
      // Best-effort update.
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _paymentType == 'received'
        ? 'Record Payment Received'
        : 'Record Payment Made';

    return Scaffold(
      appBar: StandardAppBar(title: title),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Toggle: Received / Made
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'received',
                  label: Text('Received'),
                  icon: Icon(Icons.arrow_downward),
                ),
                ButtonSegment(
                  value: 'made',
                  label: Text('Made'),
                  icon: Icon(Icons.arrow_upward),
                ),
              ],
              selected: {_paymentType},
              onSelectionChanged: (selection) {
                setState(() {
                  _paymentType = selection.first;
                  // Clear linked selections when toggling type.
                  _customerRef = null;
                  _invoiceRef = null;
                  _invoiceNumber = '';
                  _vendorRef = null;
                  _billRef = null;
                  _billNumber = '';
                });
              },
            ),
            const SizedBox(height: 24),

            // Amount
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount',
                border: OutlineInputBorder(),
                prefixText: '\$ ',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter amount';
                if (double.tryParse(v.trim()) == null) return 'Invalid amount';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Date
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Payment Date'),
              subtitle: Text(_dateFormat.format(_paymentDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDate,
            ),
            const Divider(),
            const SizedBox(height: 8),

            // Method
            DropdownButtonFormField<String>(
              initialValue: _method,
              decoration: const InputDecoration(
                labelText: 'Payment Method',
                border: OutlineInputBorder(),
              ),
              items: _methods.map((m) {
                return DropdownMenuItem(
                  value: m,
                  child: Text(m[0].toUpperCase() + m.substring(1)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _method = val);
              },
            ),
            const SizedBox(height: 16),

            // Reference Number
            TextFormField(
              controller: _referenceNumberController,
              decoration: const InputDecoration(
                labelText: 'Reference Number',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Conditional fields based on payment type.
            if (_paymentType == 'received') ...[
              _buildReceivedFields(),
            ] else ...[
              _buildMadeFields(),
            ],

            const SizedBox(height: 16),

            // Account
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('account')
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
                  label: 'Account',
                  items: items,
                  initialValue: _accountRef,
                  itemLabel: (ref) {
                    final d = docs.firstWhere(
                      (doc) => doc.reference == ref,
                      orElse: () => docs.first,
                    );
                    return (d.data()['name'] ?? 'Unnamed Account') as String;
                  },
                  onChanged: (val) => setState(() => _accountRef = val),
                );
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

  // --- Received-specific fields ---

  Widget _buildReceivedFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Customer picker
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
                final d = docs.firstWhere(
                  (doc) => doc.reference == ref,
                  orElse: () => docs.first,
                );
                return (d.data()['name'] ?? 'Unnamed Customer') as String;
              },
              onChanged: (val) {
                setState(() {
                  _customerRef = val;
                  // Reset invoice when customer changes.
                  _invoiceRef = null;
                  _invoiceNumber = '';
                });
              },
            );
          },
        ),
        const SizedBox(height: 16),

        // Invoice picker (filtered by customer)
        if (_customerRef != null)
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('invoice')
                .where('customerId', isEqualTo: _customerRef)
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
              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No invoices for this customer',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                );
              }
              final items = docs.map((d) => d.reference).toList();
              return SearchAddSelectDropdown<
                  DocumentReference<Map<String, dynamic>>>(
                label: 'Invoice',
                items: items,
                initialValue: _invoiceRef,
                itemLabel: (ref) {
                  final d = docs.firstWhere(
                    (doc) => doc.reference == ref,
                    orElse: () => docs.first,
                  );
                  final num = d.data()['invoiceNumber'] ?? d.id;
                  final status = d.data()['status'] ?? '';
                  return '#$num ($status)';
                },
                onChanged: (val) {
                  setState(() => _invoiceRef = val);
                  if (val != null) {
                    final match =
                        docs.where((d) => d.reference == val);
                    if (match.isNotEmpty) {
                      _invoiceNumber =
                          (match.first.data()['invoiceNumber'] ?? '')
                              .toString();
                    }
                  }
                },
              );
            },
          ),
      ],
    );
  }

  // --- Made-specific fields ---

  Widget _buildMadeFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Vendor picker
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
                setState(() {
                  _vendorRef = val;
                  // Reset bill when vendor changes.
                  _billRef = null;
                  _billNumber = '';
                });
              },
            );
          },
        ),
        const SizedBox(height: 16),

        // Bill picker (filtered by vendor)
        if (_vendorRef != null)
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('bill')
                .where('vendorId', isEqualTo: _vendorRef)
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
              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No bills for this vendor',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                );
              }
              final items = docs.map((d) => d.reference).toList();
              return SearchAddSelectDropdown<
                  DocumentReference<Map<String, dynamic>>>(
                label: 'Bill',
                items: items,
                initialValue: _billRef,
                itemLabel: (ref) {
                  final d = docs.firstWhere(
                    (doc) => doc.reference == ref,
                    orElse: () => docs.first,
                  );
                  final num = d.data()['billNumber'] ?? d.id;
                  final status = d.data()['status'] ?? '';
                  return '#$num ($status)';
                },
                onChanged: (val) {
                  setState(() => _billRef = val);
                  if (val != null) {
                    final match =
                        docs.where((d) => d.reference == val);
                    if (match.isNotEmpty) {
                      _billNumber =
                          (match.first.data()['billNumber'] ?? '')
                              .toString();
                    }
                  }
                },
              );
            },
          ),
      ],
    );
  }
}
