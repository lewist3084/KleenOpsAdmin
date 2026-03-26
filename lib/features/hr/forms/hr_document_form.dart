import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kleenops_admin/app/shared_widgets/forms/cancel_save_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/services/firestore_service.dart';
import 'package:shared_widgets/search/search_field_action.dart';

class HrDocumentForm extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final String? docId;

  const HrDocumentForm({
    super.key,
    required this.companyRef,
    this.docId,
  });

  @override
  State<HrDocumentForm> createState() => _HrDocumentFormState();
}

class _HrDocumentFormState extends State<HrDocumentForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _fileUrlCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _dateFormat = DateFormat.yMMMd();

  DocumentReference<Map<String, dynamic>>? _memberRef;
  String _memberName = '';
  String _type = 'other';
  DateTime? _expirationDate;

  bool _loading = true;
  bool _saving = false;

  static const _types = ['id', 'contract', 'certification', 'tax', 'other'];

  bool get _isEditing => widget.docId != null;

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

    final snap = await FirebaseFirestore.instance
        .collection('employeeDocument')
        .doc(widget.docId)
        .get();
    final data = snap.data();
    if (data != null) {
      _nameCtrl.text = (data['name'] ?? '').toString();
      _fileUrlCtrl.text = (data['fileUrl'] ?? '').toString();
      _notesCtrl.text = (data['notes'] ?? '').toString();
      _type = (data['type'] ?? 'other').toString();

      final memberValue = data['memberId'];
      if (memberValue is DocumentReference<Map<String, dynamic>>) {
        _memberRef = memberValue;
      } else if (memberValue is DocumentReference) {
        _memberRef = FirebaseFirestore.instance.collection('member').doc(memberValue.id);
      }
      _memberName = (data['memberName'] ?? '').toString();

      final exp = data['expirationDate'];
      if (exp is Timestamp) {
        _expirationDate = exp.toDate();
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _fileUrlCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickExpirationDate() async {
    final initial = _expirationDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _expirationDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_memberRef == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an employee')),
      );
      return;
    }

    setState(() => _saving = true);

    final data = <String, dynamic>{
      'memberId': _memberRef,
      'memberName': _memberName,
      'type': _type,
      'name': _nameCtrl.text.trim(),
      'fileUrl': _fileUrlCtrl.text.trim(),
      'notes': _notesCtrl.text.trim(),
      if (_expirationDate != null)
        'expirationDate': Timestamp.fromDate(_expirationDate!),
      if (!_isEditing) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (_isEditing && _expirationDate == null) {
      data['expirationDate'] = FieldValue.delete();
    }

    try {
      await FirestoreService().saveDocument(
        collectionRef: FirebaseFirestore.instance.collection('employeeDocument'),
        data: data,
        docId: widget.docId,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save document: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: StandardAppBar(title: _isEditing ? 'Edit Document' : 'New Document'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                children: [
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('member')
                        .where('active', isEqualTo: true)
                        .orderBy('name')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = snapshot.data!.docs;
                      final items = docs.map((d) => d.reference).toList();
                      return SearchAddSelectDropdown<DocumentReference<Map<String, dynamic>>>(
                        label: 'Employee',
                        items: items,
                        initialValue: _memberRef,
                        itemLabel: (ref) {
                          final match = docs.where((d) => d.reference == ref);
                          if (match.isEmpty) return ref.id;
                          final data = match.first.data();
                          final first = (data['firstName'] ?? '').toString().trim();
                          final last = (data['lastName'] ?? '').toString().trim();
                          final fullName = [first, last]
                              .where((part) => part.isNotEmpty)
                              .join(' ');
                          return fullName.isNotEmpty
                              ? fullName
                              : (data['name'] ?? ref.id).toString();
                        },
                        onChanged: (value) {
                          setState(() => _memberRef = value);
                          if (value != null) {
                            final match = docs.where((d) => d.reference == value);
                            if (match.isNotEmpty) {
                              final data = match.first.data();
                              final first =
                                  (data['firstName'] ?? '').toString().trim();
                              final last =
                                  (data['lastName'] ?? '').toString().trim();
                              _memberName = [first, last]
                                  .where((part) => part.isNotEmpty)
                                  .join(' ');
                              if (_memberName.isEmpty) {
                                _memberName = (data['name'] ?? value.id).toString();
                              }
                            }
                          }
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _type,
                    decoration: const InputDecoration(
                      labelText: 'Document Type',
                      border: OutlineInputBorder(),
                    ),
                    items: _types
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(type[0].toUpperCase() + type.substring(1)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _type = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Document Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Document name is required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _fileUrlCtrl,
                    decoration: const InputDecoration(
                      labelText: 'File URL',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'File URL is required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Expiration Date (optional)'),
                    subtitle: Text(
                      _expirationDate != null
                          ? _dateFormat.format(_expirationDate!)
                          : 'Not set',
                    ),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: _pickExpirationDate,
                  ),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _notesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      border: OutlineInputBorder(),
                    ),
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
