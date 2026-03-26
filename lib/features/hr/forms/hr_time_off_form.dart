// lib/features/hr/forms/hr_time_off_form.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/forms/cancel_save_adapter.dart';
import 'package:kleenops_admin/services/firestore_service.dart';

class HrTimeOffForm extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final String? docId;

  const HrTimeOffForm({
    super.key,
    required this.companyRef,
    this.docId,
  });

  @override
  State<HrTimeOffForm> createState() => _HrTimeOffFormState();
}

class _HrTimeOffFormState extends State<HrTimeOffForm> {
  final _formKey = GlobalKey<FormState>();
  final _fs = FirestoreService();

  late final TextEditingController _hoursCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _startDateCtrl;
  late final TextEditingController _endDateCtrl;

  String? _selectedMemberId;
  String _type = 'vacation';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _loading = false;
  bool _saving = false;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _memberDocs = [];

  bool get _isEditing => widget.docId != null;

  @override
  void initState() {
    super.initState();
    _hoursCtrl = TextEditingController();
    _notesCtrl = TextEditingController();
    _startDateCtrl = TextEditingController();
    _endDateCtrl = TextEditingController();
    _loadMembers();
    if (_isEditing) {
      _loadExisting();
    }
  }

  Future<void> _loadMembers() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('member')
          .where('active', isEqualTo: true)
          .get();
      if (mounted) {
        setState(() => _memberDocs = snap.docs);
      }
    } catch (_) {}
  }

  Future<void> _loadExisting() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('timeOff')
          .doc(widget.docId)
          .get();
      if (!snap.exists) return;
      final data = snap.data();
      if (data == null) return;

      final memberVal = data['memberId'];
      if (memberVal is DocumentReference) {
        _selectedMemberId = memberVal.id;
      } else if (memberVal is String && memberVal.isNotEmpty) {
        _selectedMemberId = memberVal.contains('/')
            ? memberVal.split('/').last
            : memberVal;
      }

      _type = (data['type'] ?? 'vacation').toString();
      _hoursCtrl.text = (data['hours'] ?? '').toString();
      _notesCtrl.text = (data['notes'] ?? '').toString();

      if (data['startDate'] is Timestamp) {
        _startDate = (data['startDate'] as Timestamp).toDate();
        _startDateCtrl.text = DateFormat('yMMMd').format(_startDate!);
      }
      if (data['endDate'] is Timestamp) {
        _endDate = (data['endDate'] as Timestamp).toDate();
        _endDateCtrl.text = DateFormat('yMMMd').format(_endDate!);
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _hoursCtrl.dispose();
    _notesCtrl.dispose();
    _startDateCtrl.dispose();
    _endDateCtrl.dispose();
    super.dispose();
  }

  String _resolveMemberName(Map<String, dynamic> data) {
    final first = (data['firstName'] ?? '').toString().trim();
    final last = (data['lastName'] ?? '').toString().trim();
    final combined =
        [first, last].where((s) => s.isNotEmpty).join(' ');
    if (combined.isNotEmpty) return combined;
    return (data['name'] ?? '').toString();
  }

  Future<void> _selectStartDate() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        _startDateCtrl.text = DateFormat('yMMMd').format(picked);
      });
    }
  }

  Future<void> _selectEndDate() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
        _endDateCtrl.text = DateFormat('yMMMd').format(picked);
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    final data = <String, dynamic>{
      'type': _type,
      'status': 'requested',
    };

    if (_selectedMemberId != null) {
      data['memberId'] =
          FirebaseFirestore.instance.collection('member').doc(_selectedMemberId);
    }

    if (_startDate != null) {
      data['startDate'] = Timestamp.fromDate(_startDate!);
    }
    if (_endDate != null) {
      data['endDate'] = Timestamp.fromDate(_endDate!);
    }

    final hours = double.tryParse(_hoursCtrl.text.trim());
    if (hours != null) {
      data['hours'] = hours;
    }

    final notes = _notesCtrl.text.trim();
    if (notes.isNotEmpty) {
      data['notes'] = notes;
    }

    try {
      await _fs.saveDocument(
        collectionRef: FirebaseFirestore.instance.collection('timeOff'),
        data: data,
        docId: widget.docId,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title =
        _isEditing ? 'Edit Time Off Request' : 'New Time Off Request';

    return Scaffold(
      appBar: StandardAppBar(title: title),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _selectedMemberId,
                    decoration:
                        const InputDecoration(labelText: 'Employee'),
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Employee is required'
                        : null,
                    items: _memberDocs.map((doc) {
                      final name = _resolveMemberName(doc.data());
                      return DropdownMenuItem(
                        value: doc.id,
                        child: Text(
                            name.isNotEmpty ? name : doc.id),
                      );
                    }).toList(),
                    onChanged: (val) =>
                        setState(() => _selectedMemberId = val),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _type,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: const [
                      DropdownMenuItem(
                          value: 'vacation', child: Text('Vacation')),
                      DropdownMenuItem(
                          value: 'sick', child: Text('Sick')),
                      DropdownMenuItem(
                          value: 'personal', child: Text('Personal')),
                      DropdownMenuItem(
                          value: 'unpaid', child: Text('Unpaid')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _type = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _startDateCtrl,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Start Date',
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Start date is required'
                        : null,
                    onTap: _selectStartDate,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _endDateCtrl,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'End Date',
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    onTap: _selectEndDate,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _hoursCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Hours'),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'[\d.]')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _notesCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Notes'),
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
