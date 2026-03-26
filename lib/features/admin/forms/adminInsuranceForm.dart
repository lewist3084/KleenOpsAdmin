import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/forms/cancel_save_adapter.dart';
import 'package:kleenops_admin/services/firestore_service.dart';

class AdminInsuranceFormScreen extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final String? docId;

  const AdminInsuranceFormScreen({
    super.key,
    required this.companyRef,
    this.docId,
  });

  bool get _isEditing => docId != null && docId!.isNotEmpty;

  @override
  State<AdminInsuranceFormScreen> createState() =>
      _AdminInsuranceFormState();
}

class _AdminInsuranceFormState extends State<AdminInsuranceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fs = FirestoreService();

  final _carrierCtrl = TextEditingController();
  final _policyNumberCtrl = TextEditingController();
  final _premiumCtrl = TextEditingController();
  final _coverageAmountCtrl = TextEditingController();
  final _effectiveDateCtrl = TextEditingController();
  final _expirationDateCtrl = TextEditingController();
  final _agentCtrl = TextEditingController();
  final _agentPhoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _type = '';
  bool _loading = true;
  bool _saving = false;

  static const _policyTypes = [
    '',
    'General Liability',
    'Workers\' Compensation',
    'Commercial Auto',
    'Bonding / Surety Bond',
    'Umbrella / Excess Liability',
    'Professional Liability (E&O)',
    'Property / Equipment',
    'Cyber Liability',
    'Pollution Liability',
    'Inland Marine',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    if (widget._isEditing) {
      _loadExisting();
    } else {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _carrierCtrl.dispose();
    _policyNumberCtrl.dispose();
    _premiumCtrl.dispose();
    _coverageAmountCtrl.dispose();
    _effectiveDateCtrl.dispose();
    _expirationDateCtrl.dispose();
    _agentCtrl.dispose();
    _agentPhoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('insurancePolicy')
          .doc(widget.docId)
          .get();
      final data = snap.data();
      if (data == null) return;
      _type = (data['type'] ?? '').toString();
      _carrierCtrl.text = (data['carrier'] ?? '').toString();
      _policyNumberCtrl.text = (data['policyNumber'] ?? '').toString();
      _premiumCtrl.text = (data['premium'] ?? '').toString();
      _coverageAmountCtrl.text = (data['coverageAmount'] ?? '').toString();
      _effectiveDateCtrl.text = (data['effectiveDate'] ?? '').toString();
      _expirationDateCtrl.text = (data['expirationDate'] ?? '').toString();
      _agentCtrl.text = (data['agent'] ?? '').toString();
      _agentPhoneCtrl.text = (data['agentPhone'] ?? '').toString();
      _notesCtrl.text = (data['notes'] ?? '').toString();
      if (!_policyTypes.contains(_type)) _type = '';
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final data = <String, dynamic>{
      'type': _type,
      'carrier': _carrierCtrl.text.trim(),
      'policyNumber': _policyNumberCtrl.text.trim(),
      'premium': _premiumCtrl.text.trim(),
      'coverageAmount': _coverageAmountCtrl.text.trim(),
      'effectiveDate': _effectiveDateCtrl.text.trim(),
      'expirationDate': _expirationDateCtrl.text.trim(),
      'agent': _agentCtrl.text.trim(),
      'agentPhone': _agentPhoneCtrl.text.trim(),
      'notes': _notesCtrl.text.trim(),
    };

    try {
      await _fs.saveDocument(
        collectionRef: FirebaseFirestore.instance.collection('insurancePolicy'),
        data: data,
        docId: widget.docId,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: StandardAppBar(
        title: widget._isEditing ? 'Edit Policy' : 'New Insurance Policy',
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                children: [
                  DropdownButtonFormField<String>(
                    value: _type,
                    decoration:
                        const InputDecoration(labelText: 'Policy Type'),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Select a type' : null,
                    items: _policyTypes
                        .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(e.isEmpty ? '-- Select --' : e),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _type = v ?? ''),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _carrierCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Insurance Carrier'),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _policyNumberCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Policy Number'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _premiumCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Annual Premium',
                      prefixText: '\$',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _coverageAmountCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Coverage Amount',
                      prefixText: '\$',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _effectiveDateCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Effective Date',
                      hintText: 'YYYY-MM-DD',
                    ),
                    keyboardType: TextInputType.datetime,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _expirationDateCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Expiration Date',
                      hintText: 'YYYY-MM-DD',
                    ),
                    keyboardType: TextInputType.datetime,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _agentCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Agent / Broker'),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _agentPhoneCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Agent Phone'),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _notesCtrl,
                    decoration: const InputDecoration(labelText: 'Notes'),
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 2,
                    maxLines: 4,
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
