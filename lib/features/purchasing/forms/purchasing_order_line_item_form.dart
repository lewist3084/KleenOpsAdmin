import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kleenops_admin/app/shared_widgets/forms/cancel_save_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:shared_widgets/services/firestore_service.dart';
import 'package:shared_widgets/search/search_field_action.dart';

class PurchasingOrderLineItemForm extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> purchaseOrderRef;
  final String? docId;

  const PurchasingOrderLineItemForm({
    super.key,
    required this.purchaseOrderRef,
    this.docId,
  });

  @override
  State<PurchasingOrderLineItemForm> createState() =>
      _PurchasingOrderLineItemFormState();
}

class _PurchasingOrderLineItemFormState extends State<PurchasingOrderLineItemForm> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _unitPriceCtrl = TextEditingController(text: '0');

  DocumentReference<Map<String, dynamic>>? _selectedObjectRef;
  bool _loading = true;
  bool _saving = false;

  bool get _isEditing => widget.docId != null;
  DocumentReference<Map<String, dynamic>> get _companyRef =>
      widget.purchaseOrderRef.parent.parent!;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!_isEditing) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final snap = await widget.purchaseOrderRef
        .collection('lineItem')
        .doc(widget.docId)
        .get();
    final data = snap.data();
    if (data != null) {
      _descriptionCtrl.text = (data['description'] ?? '').toString();
      _qtyCtrl.text = ((data['quantity'] ?? 1)).toString();
      _unitPriceCtrl.text = ((data['unitPrice'] ?? 0)).toString();
      final refValue = data['companyObjectId'];
      if (refValue is DocumentReference<Map<String, dynamic>>) {
        _selectedObjectRef = refValue;
      } else if (refValue is DocumentReference) {
        _selectedObjectRef = FirebaseFirestore.instance.collection('companyObject').doc(refValue.id);
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    _qtyCtrl.dispose();
    _unitPriceCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final quantity = double.tryParse(_qtyCtrl.text.trim()) ?? 0.0;
    final unitPrice = double.tryParse(_unitPriceCtrl.text.trim()) ?? 0.0;
    final amount = quantity * unitPrice;

    final data = <String, dynamic>{
      'description': _descriptionCtrl.text.trim(),
      'quantity': quantity,
      'unitPrice': unitPrice,
      'amount': amount,
      'updatedAt': FieldValue.serverTimestamp(),
      if (_selectedObjectRef != null) 'companyObjectId': _selectedObjectRef,
      if (!_isEditing) 'createdAt': FieldValue.serverTimestamp(),
    };

    if (_isEditing && _selectedObjectRef == null) {
      data['companyObjectId'] = FieldValue.delete();
    }

    try {
      await FirestoreService().saveDocument(
        collectionRef: widget.purchaseOrderRef.collection('lineItem'),
        data: data,
        docId: widget.docId,
      );

      await _recalculateOrderTotal();

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save line item: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _recalculateOrderTotal() async {
    final lines = await widget.purchaseOrderRef.collection('lineItem').get();
    var subtotal = 0.0;
    for (final line in lines.docs) {
      final amount = (line.data()['amount'] as num?)?.toDouble() ?? 0.0;
      subtotal += amount;
    }
    await widget.purchaseOrderRef.set(
      {
        'purchaseOrderSubtotal': subtotal,
        'purchaseOrderTotal': subtotal,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: StandardAppBar(title: _isEditing ? 'Edit Line Item' : 'Add Line Item'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                children: [
                  TextFormField(
                    controller: _descriptionCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Description is required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('companyObject')
                        .orderBy('name')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final docs = snapshot.data!.docs;
                      final items = docs.map((doc) => doc.reference).toList();
                      return SearchAddSelectDropdown<DocumentReference<Map<String, dynamic>>>(
                        label: 'Object (optional)',
                        items: items,
                        initialValue: _selectedObjectRef,
                        itemLabel: (ref) {
                          final match = docs.where((doc) => doc.reference == ref);
                          if (match.isEmpty) return ref.id;
                          final data = match.first.data();
                          final name = (data['name'] ?? data['localName'] ?? ref.id)
                              .toString();
                          return name;
                        },
                        onChanged: (value) => setState(() => _selectedObjectRef = value),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _qtyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                    validator: (value) {
                      final parsed = double.tryParse((value ?? '').trim());
                      if (parsed == null || parsed <= 0) {
                        return 'Quantity must be greater than 0';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _unitPriceCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Unit Price',
                      prefixText: '\$ ',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                    validator: (value) {
                      final parsed = double.tryParse((value ?? '').trim());
                      if (parsed == null || parsed < 0) {
                        return 'Unit price must be valid';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _qtyCtrl,
                    builder: (_, __, ___) {
                      final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
                      final unit = double.tryParse(_unitPriceCtrl.text.trim()) ?? 0;
                      return ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _unitPriceCtrl,
                        builder: (_, __, ___) => Text(
                          'Line total: \$${(qty * unit).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      );
                    },
                  ),
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
