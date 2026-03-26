// lib/features/finances/forms/financeAccountForm.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/forms/cancel_save_adapter.dart';
import 'package:kleenops_admin/services/firestore_service.dart';

class FinanceAccountForm extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final String? docId;

  const FinanceAccountForm({
    super.key,
    required this.companyRef,
    this.docId,
  });

  @override
  State<FinanceAccountForm> createState() => _FinanceAccountFormState();
}

class _FinanceAccountFormState extends State<FinanceAccountForm> {
  final _formKey = GlobalKey<FormState>();
  final _fs = FirestoreService();

  final _nameCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  String _type = 'Asset';
  String? _parentAccountId;

  bool _loading = false;
  bool _saving = false;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _accountDocs = [];

  bool get _isEditing => widget.docId != null;

  static const _accountTypes = [
    'Asset',
    'Liability',
    'Equity',
    'Revenue',
    'Expense',
  ];

  @override
  void initState() {
    super.initState();
    _loadAccounts();
    if (_isEditing) _loadExisting();
  }

  Future<void> _loadAccounts() async {
    final snap = await FirebaseFirestore.instance
        .collection('account')
        .orderBy('name')
        .get();
    if (mounted) setState(() => _accountDocs = snap.docs);
  }

  Future<void> _loadExisting() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('account')
          .doc(widget.docId)
          .get();
      final data = snap.data();
      if (data == null) return;

      _nameCtrl.text = (data['name'] ?? '').toString();
      _descriptionCtrl.text = (data['description'] ?? '').toString();
      _type = (data['type'] ?? 'Asset').toString();

      final parent = data['parentAccountId'];
      if (parent is DocumentReference) {
        _parentAccountId = parent.id;
      } else if (parent is String && parent.isNotEmpty) {
        _parentAccountId = parent;
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    final data = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'type': _type,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final desc = _descriptionCtrl.text.trim();
    if (desc.isNotEmpty) {
      data['description'] = desc;
    } else if (_isEditing) {
      data['description'] = FieldValue.delete();
    }

    if (_parentAccountId != null) {
      data['parentAccountId'] =
          FirebaseFirestore.instance.collection('account').doc(_parentAccountId);
    } else if (_isEditing) {
      data['parentAccountId'] = FieldValue.delete();
    }

    if (!_isEditing) {
      data['createdAt'] = FieldValue.serverTimestamp();
      data['balance'] = 0;
    }

    try {
      await _fs.saveDocument(
        collectionRef: FirebaseFirestore.instance.collection('account'),
        data: data,
        docId: widget.docId,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save account: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: StandardAppBar(title: _isEditing ? 'Edit Account' : 'New Account'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Account Name'),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _type,
                    decoration: const InputDecoration(labelText: 'Account Type'),
                    items: _accountTypes
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _type = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String?>(
                    initialValue: _parentAccountId,
                    decoration: const InputDecoration(
                      labelText: 'Parent Account (optional)',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('None'),
                      ),
                      ..._accountDocs
                          .where((d) => d.id != widget.docId)
                          .map((doc) {
                        final name = (doc.data()['name'] ?? doc.id).toString();
                        return DropdownMenuItem<String?>(
                          value: doc.id,
                          child: Text(name),
                        );
                      }),
                    ],
                    onChanged: (val) => setState(() => _parentAccountId = val),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionCtrl,
                    decoration: const InputDecoration(labelText: 'Description'),
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
