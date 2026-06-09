// lib/features/finances/forms/finance_account_form.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/widgets/layout/bookended_canvas.dart';
import 'package:kleenops_admin/app/shared_widgets/forms/cancel_save_adapter.dart';
import 'package:shared_widgets/services/firestore_service.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';

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

  /// Name as loaded, to detect renames (so we can clear the stale localized
  /// name map that the Balance Sheet / P&L render from).
  String _originalName = '';

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
      _originalName = _nameCtrl.text;
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

    final newName = _nameCtrl.text.trim();
    final data = <String, dynamic>{
      'name': newName,
      'type': _type,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // On rename, drop the stale localized-name map so every view (Balance
    // Sheet / P&L use `nameLocalized`, the Ledger uses `name`) falls back to
    // the freshly-typed name. Re-localization can repopulate it later.
    if (_isEditing && newName != _originalName) {
      data['nameLocalized'] = FieldValue.delete();
    }

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
        SnackbarService.instance.showSnackBar(
          SnackBar(duration: const Duration(seconds: 5), content: Text('Failed to save account: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BookendedCanvas(
        child: _loading
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
                    textInputAction: TextInputAction.next,
                    onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
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
                    textInputAction: TextInputAction.newline,
                    onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                  ),
                ],
              ),
            ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CancelSaveBar(
            onCancel: () => Navigator.of(context).pop(),
            onSave: _saving ? null : _save,
            isSaving: _saving,
            reserveNavBarSpace: false,
          ),
          DetailsAppBar(title: _isEditing ? 'Edit Account' : 'New Account'),
          const HomeNavBarAdapter(),
        ],
      ),
    );
  }
}
