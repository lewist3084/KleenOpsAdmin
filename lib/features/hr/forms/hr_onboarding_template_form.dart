// lib/features/hr/forms/hr_onboarding_template_form.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/forms/cancel_save_adapter.dart';
import 'package:kleenops_admin/services/firestore_service.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';

class HrOnboardingTemplateForm extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final String? docId;

  const HrOnboardingTemplateForm({
    super.key,
    required this.companyRef,
    this.docId,
  });

  @override
  State<HrOnboardingTemplateForm> createState() =>
      _HrOnboardingTemplateFormState();
}

class _HrOnboardingTemplateFormState extends State<HrOnboardingTemplateForm> {
  final _formKey = GlobalKey<FormState>();
  final _fs = FirestoreService();

  late final TextEditingController _nameCtrl;
  bool _loading = false;
  bool _saving = false;

  // Steps list: each step is { title, type, required, description }
  List<Map<String, dynamic>> _steps = [];

  bool get _isEditing => widget.docId != null;

  static const _defaultSteps = [
    {
      'title': 'Complete Personal Information',
      'type': 'form',
      'required': true,
      'description': 'Address, phone, emergency contact',
    },
    {
      'title': 'Employment Classification',
      'type': 'form',
      'required': true,
      'description': 'Work state, hourly/salary, exempt status',
    },
    {
      'title': 'W-4 Federal Tax Withholding',
      'type': 'form',
      'required': true,
      'description': 'Filing status and allowances',
    },
    {
      'title': 'State Tax Withholding',
      'type': 'form',
      'required': true,
      'description': 'State-specific tax withholding',
    },
    {
      'title': 'Direct Deposit Setup',
      'type': 'form',
      'required': false,
      'description': 'Bank account for payroll',
    },
    {
      'title': 'I-9 Employment Verification',
      'type': 'document_upload',
      'required': true,
      'description': 'Identity and work authorization documents',
    },
    {
      'title': 'Benefits Enrollment',
      'type': 'form',
      'required': false,
      'description': 'Enroll in available benefit plans',
    },
    {
      'title': 'Policy Acknowledgements',
      'type': 'acknowledgement',
      'required': true,
      'description': 'Review and sign company policies',
    },
    {
      'title': 'Upload Documents',
      'type': 'document_upload',
      'required': false,
      'description': 'ID, certifications, licenses',
    },
    {
      'title': 'Assign to Team & Schedule',
      'type': 'manual',
      'required': true,
      'description': 'Team placement and initial schedule',
    },
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    if (_isEditing) {
      _loadExisting();
    } else {
      _nameCtrl.text = 'Standard Onboarding';
      _steps = _defaultSteps
          .asMap()
          .entries
          .map((e) => {
                ...e.value,
                'position': e.key,
              })
          .toList();
    }
  }

  Future<void> _loadExisting() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('onboardingTemplate')
          .doc(widget.docId)
          .get();
      if (!snap.exists) return;
      final d = snap.data();
      if (d == null) return;

      _nameCtrl.text = (d['name'] ?? '').toString();
      final rawSteps = d['steps'];
      if (rawSteps is List) {
        _steps = rawSteps
            .map((s) => Map<String, dynamic>.from(s as Map))
            .toList();
        _steps.sort((a, b) =>
            (a['position'] as int? ?? 0).compareTo(b['position'] as int? ?? 0));
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    // Re-index positions
    final indexedSteps = _steps.asMap().entries.map((e) {
      return {...e.value, 'position': e.key};
    }).toList();

    final data = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'steps': indexedSteps,
    };

    try {
      await _fs.saveDocument(
        collectionRef: FirebaseFirestore.instance.collection('onboardingTemplate'),
        data: data,
        docId: widget.docId,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save template: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addStep() {
    showDialog(
      context: context,
      builder: (_) => _AddStepDialog(
        onAdd: (step) {
          setState(() {
            _steps.add({...step, 'position': _steps.length});
          });
        },
      ),
    );
  }

  void _removeStep(int index) {
    setState(() => _steps.removeAt(index));
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _steps.removeAt(oldIndex);
      _steps.insert(newIndex, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEditing ? 'Edit Template' : 'New Onboarding Template';

    return Scaffold(
      appBar: StandardAppBar(title: title),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Template Name'),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Name is required'
                          : null,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text(
                          'Steps (${_steps.length})',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _addStep,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Step'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 80),
                      itemCount: _steps.length,
                      onReorder: _onReorder,
                      itemBuilder: (context, index) {
                        final step = _steps[index];
                        final title = (step['title'] ?? '').toString();
                        final type = (step['type'] ?? 'manual').toString();
                        final required = step['required'] == true;
                        final desc =
                            (step['description'] ?? '').toString();

                        return ListTile(
                          key: ValueKey('step_$index'),
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.grey[200],
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                          title: Text(title,
                              style: const TextStyle(fontSize: 14)),
                          subtitle: Text(
                            [
                              _stepTypeLabel(type),
                              if (required) 'Required',
                              if (desc.isNotEmpty) desc,
                            ].join(' · '),
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.delete_outline,
                                    size: 20, color: Colors.red[400]),
                                onPressed: () => _removeStep(index),
                              ),
                              const Icon(Icons.drag_handle, size: 20),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
          ),
      bottomNavigationBar: CancelSaveBar(
        onCancel: () => Navigator.of(context).pop(),
        onSave: _saving ? null : _handleSave,
        isSaving: _saving,
      ),
    );
  }

  String _stepTypeLabel(String type) {
    switch (type) {
      case 'form':
        return 'Form';
      case 'document_upload':
        return 'Upload';
      case 'acknowledgement':
        return 'Acknowledge';
      case 'manual':
        return 'Manual';
      default:
        return type;
    }
  }
}

// ─────────────────────── Add Step Dialog ───────────────────────

class _AddStepDialog extends StatefulWidget {
  final ValueChanged<Map<String, dynamic>> onAdd;

  const _AddStepDialog({required this.onAdd});

  @override
  State<_AddStepDialog> createState() => _AddStepDialogState();
}

class _AddStepDialogState extends State<_AddStepDialog> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _type = 'manual';
  bool _required = true;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DialogAction(
      title: 'Add Step',
      cancelText: 'Cancel',
      actionText: 'Add',
      onCancel: () => Navigator.of(context).pop(),
      onAction: () {
        final title = _titleCtrl.text.trim();
        if (title.isEmpty) return;
        widget.onAdd({
          'title': title,
          'type': _type,
          'required': _required,
          'description': _descCtrl.text.trim(),
        });
        Navigator.of(context).pop();
      },
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(labelText: 'Step Title'),
            textCapitalization: TextCapitalization.sentences,
            autofocus: true,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Step Type'),
            items: const [
              DropdownMenuItem(value: 'form', child: Text('Form')),
              DropdownMenuItem(
                  value: 'document_upload', child: Text('Document Upload')),
              DropdownMenuItem(
                  value: 'acknowledgement', child: Text('Acknowledgement')),
              DropdownMenuItem(value: 'manual', child: Text('Manual')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _type = v);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(labelText: 'Description'),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Required'),
            value: _required,
            onChanged: (v) => setState(() => _required = v),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ],
      ),
    );
  }
}
