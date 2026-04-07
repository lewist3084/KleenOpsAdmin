// lib/features/hr/forms/hr_role_form.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/forms/cancel_save_adapter.dart';
import 'package:shared_widgets/services/firestore_service.dart';

class HrRoleForm extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final String? docId;

  const HrRoleForm({
    super.key,
    required this.companyRef,
    this.docId,
  });

  @override
  State<HrRoleForm> createState() => _HrRoleFormState();
}

class _HrRoleFormState extends State<HrRoleForm> {
  final _formKey = GlobalKey<FormState>();
  final _fs = FirestoreService();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _descriptionCtrl;

  bool _loading = false;
  bool _saving = false;

  bool get _isEditing => widget.docId != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _descriptionCtrl = TextEditingController();
    if (_isEditing) {
      _loadExisting();
    }
  }

  Future<void> _loadExisting() async {
    setState(() => _loading = true);
    try {
      final snap =
          await FirebaseFirestore.instance.collection('role').doc(widget.docId).get();
      if (!snap.exists) return;
      final data = snap.data();
      if (data == null) return;

      _nameCtrl.text = (data['name'] ?? '').toString();
      _descriptionCtrl.text = (data['description'] ?? '').toString();
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

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    final name = _nameCtrl.text.trim();
    final description = _descriptionCtrl.text.trim();

    final data = <String, dynamic>{
      'name': name,
    };

    if (description.isNotEmpty) {
      data['description'] = description;
    } else if (_isEditing) {
      data['description'] = FieldValue.delete();
    }

    try {
      await _fs.saveDocument(
        collectionRef: FirebaseFirestore.instance.collection('role'),
        data: data,
        docId: widget.docId,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save role: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEditing ? 'Edit Role' : 'New Role';

    return Scaffold(
      appBar: StandardAppBar(title: title),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Name'),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Name is required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Description'),
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 2,
                    maxLines: 4,
                  ),
                ],
              ),
          ),
      bottomNavigationBar: CancelSaveBar(
        onCancel: () => Navigator.of(context).pop(),
        onSave: _saving ? null : _handleSave,
      ),
    );
  }
}
