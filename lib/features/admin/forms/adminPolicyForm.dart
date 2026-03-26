import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/forms/cancel_save_adapter.dart';
import 'package:kleenops_admin/services/firestore_service.dart';

class AdminPolicyFormScreen extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final String? docId;
  final String initialCategory;

  const AdminPolicyFormScreen({
    super.key,
    required this.companyRef,
    this.docId,
    this.initialCategory = 'company',
  });

  bool get _isEditing => docId != null && docId!.isNotEmpty;

  @override
  State<AdminPolicyFormScreen> createState() => _AdminPolicyFormState();
}

class _AdminPolicyFormState extends State<AdminPolicyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fs = FirestoreService();

  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _versionCtrl = TextEditingController(text: '1.0');
  final _effectiveDateCtrl = TextEditingController();

  String _category = 'company';
  String _status = 'draft';
  bool _requiresAck = false;
  bool _loading = true;
  bool _saving = false;

  static const _categories = ['company', 'operations'];
  static const _statuses = ['draft', 'active', 'archived'];

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
    if (widget._isEditing) {
      _loadExisting();
    } else {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _versionCtrl.dispose();
    _effectiveDateCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('policy')
          .doc(widget.docId)
          .get();
      final data = snap.data();
      if (data == null) return;

      _titleCtrl.text = (data['title'] ?? '').toString();
      _bodyCtrl.text = (data['body'] ?? '').toString();
      _versionCtrl.text = (data['version'] ?? '1.0').toString();
      _effectiveDateCtrl.text = (data['effectiveDate'] ?? '').toString();
      _category = (data['category'] ?? 'company').toString();
      _status = (data['status'] ?? 'draft').toString();
      _requiresAck = data['requiresAck'] == true;

      if (!_categories.contains(_category)) _category = 'company';
      if (!_statuses.contains(_status)) _status = 'draft';
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final data = <String, dynamic>{
      'title': _titleCtrl.text.trim(),
      'body': _bodyCtrl.text.trim(),
      'category': _category,
      'status': _status,
      'version': _versionCtrl.text.trim(),
      'effectiveDate': _effectiveDateCtrl.text.trim(),
      'requiresAck': _requiresAck,
    };

    try {
      await _fs.saveDocument(
        collectionRef: FirebaseFirestore.instance.collection('policy'),
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
        title: widget._isEditing ? 'Edit Policy' : 'New Policy',
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                children: [
                  TextFormField(
                    controller: _titleCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Policy Title'),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Title is required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _category,
                    decoration:
                        const InputDecoration(labelText: 'Category'),
                    items: const [
                      DropdownMenuItem(
                          value: 'company', child: Text('Company Policy')),
                      DropdownMenuItem(
                          value: 'operations',
                          child: Text('Operations Policy')),
                    ],
                    onChanged: (v) =>
                        setState(() => _category = v ?? 'company'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(
                          value: 'draft', child: Text('Draft')),
                      DropdownMenuItem(
                          value: 'active', child: Text('Active')),
                      DropdownMenuItem(
                          value: 'archived', child: Text('Archived')),
                    ],
                    onChanged: (v) =>
                        setState(() => _status = v ?? 'draft'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _versionCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Version'),
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
                  SwitchListTile(
                    title: const Text('Requires Employee Acknowledgment'),
                    subtitle: const Text(
                        'Employees must read and acknowledge this policy'),
                    value: _requiresAck,
                    onChanged: (v) => setState(() => _requiresAck = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _bodyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Policy Content',
                      alignLabelWithHint: true,
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 8,
                    maxLines: 20,
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
