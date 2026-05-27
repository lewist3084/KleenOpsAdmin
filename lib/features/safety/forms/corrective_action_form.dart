import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/forms/cancel_save_adapter.dart';
import 'package:kleenops_admin/widgets/layout/bookended_canvas.dart';
import 'package:shared_widgets/services/firestore_service.dart';

class CorrectiveActionForm extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> potentialCauseRef;

  const CorrectiveActionForm({
    super.key,
    required this.potentialCauseRef,
  });

  @override
  State<CorrectiveActionForm> createState() => _CorrectiveActionFormState();
}

class _CorrectiveActionFormState extends State<CorrectiveActionForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameC = TextEditingController();
  final _descC = TextEditingController();
  final _dateC = TextEditingController();
  DateTime? _targetDate;
  bool _saving = false;

  @override
  void dispose() {
    _nameC.dispose();
    _descC.dispose();
    _dateC.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() => _targetDate = picked);
      _dateC.text = '${picked.month}/${picked.day}/${picked.year}';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final data = {
      'name': _nameC.text.trim(),
      'description': _descC.text.trim(),
      if (_targetDate != null) 'targetDate': Timestamp.fromDate(_targetDate!),
      'createdAt': FieldValue.serverTimestamp(),
    };
    await FirestoreService().saveDocument(
      collectionRef: widget.potentialCauseRef.collection('controlCorrectiveAction'),
      data: data,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BookendedCanvas(
        child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameC,
                decoration: const InputDecoration(labelText: 'Name'),
                textInputAction: TextInputAction.next,
                onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descC,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
                textInputAction: TextInputAction.newline,
                onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _pickDate,
                child: AbsorbPointer(
                  child: TextFormField(
                    decoration: const InputDecoration(labelText: 'Target Date'),
                    controller: _dateC,
                    textInputAction: TextInputAction.done,
                    onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CancelSaveBar(
            onCancel: () => Navigator.of(context).pop(),
            onSave: _saving ? null : _save,
            reserveNavBarSpace: false,
          ),
          const DetailsAppBar(title: 'Corrective Action'),
          const HomeNavBarAdapter(),
        ],
      ),
    );
  }
}
