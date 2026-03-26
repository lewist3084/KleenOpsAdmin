// lib/features/hr/forms/hr_benefit_plan_form.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/forms/cancel_save_adapter.dart';
import 'package:kleenops_admin/services/firestore_service.dart';

class HrBenefitPlanForm extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final String? docId;

  const HrBenefitPlanForm({
    super.key,
    required this.companyRef,
    this.docId,
  });

  @override
  State<HrBenefitPlanForm> createState() => _HrBenefitPlanFormState();
}

class _HrBenefitPlanFormState extends State<HrBenefitPlanForm> {
  final _formKey = GlobalKey<FormState>();
  final _fs = FirestoreService();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _providerCtrl;
  late final TextEditingController _planNumberCtrl;
  late final TextEditingController _employerContribCtrl;
  late final TextEditingController _employeeContribCtrl;
  late final TextEditingController _eligibilityMinHoursCtrl;
  late final TextEditingController _waitingPeriodCtrl;
  late final TextEditingController _enrollmentWindowCtrl;

  String _type = 'health';
  String _eligibilityType = 'full-time';
  bool _active = true;
  bool _loading = false;
  bool _saving = false;

  bool get _isEditing => widget.docId != null;

  static const _benefitTypes = [
    ('health', 'Health Insurance'),
    ('dental', 'Dental Insurance'),
    ('vision', 'Vision Insurance'),
    ('life', 'Life Insurance'),
    ('401k', '401(k) Retirement'),
    ('hsa', 'HSA'),
    ('fsa', 'FSA'),
    ('pto', 'Paid Time Off'),
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _providerCtrl = TextEditingController();
    _planNumberCtrl = TextEditingController();
    _employerContribCtrl = TextEditingController(text: '0');
    _employeeContribCtrl = TextEditingController(text: '0');
    _eligibilityMinHoursCtrl = TextEditingController(text: '30');
    _waitingPeriodCtrl = TextEditingController(text: '90');
    _enrollmentWindowCtrl = TextEditingController(text: '30');
    if (_isEditing) _loadExisting();
  }

  Future<void> _loadExisting() async {
    final companyRef = widget.companyRef;
    setState(() => _loading = true);
    try {
      final snap =
          await FirebaseFirestore.instance.collection('benefitPlan').doc(widget.docId).get();
      if (!snap.exists) return;
      final d = snap.data();
      if (d == null) return;

      _nameCtrl.text = (d['name'] ?? '').toString();
      _providerCtrl.text = (d['provider'] ?? '').toString();
      _planNumberCtrl.text = (d['planNumber'] ?? '').toString();
      _employerContribCtrl.text = (d['employerContribution'] ?? 0).toString();
      _employeeContribCtrl.text = (d['employeeContribution'] ?? 0).toString();
      _eligibilityMinHoursCtrl.text =
          (d['eligibilityMinHours'] ?? 30).toString();
      _waitingPeriodCtrl.text = (d['waitingPeriodDays'] ?? 90).toString();
      _enrollmentWindowCtrl.text =
          (d['enrollmentWindowDays'] ?? 30).toString();
      _type = (d['type'] ?? 'health').toString();
      _eligibilityType = (d['eligibilityType'] ?? 'full-time').toString();
      _active = d['active'] ?? true;
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _providerCtrl.dispose();
    _planNumberCtrl.dispose();
    _employerContribCtrl.dispose();
    _employeeContribCtrl.dispose();
    _eligibilityMinHoursCtrl.dispose();
    _waitingPeriodCtrl.dispose();
    _enrollmentWindowCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    final companyRef = widget.companyRef;

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    final data = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'type': _type,
      'provider': _providerCtrl.text.trim(),
      'planNumber': _planNumberCtrl.text.trim(),
      'employerContribution':
          double.tryParse(_employerContribCtrl.text.trim()) ?? 0,
      'employeeContribution':
          double.tryParse(_employeeContribCtrl.text.trim()) ?? 0,
      'eligibilityType': _eligibilityType,
      'eligibilityMinHours':
          double.tryParse(_eligibilityMinHoursCtrl.text.trim()) ?? 30,
      'waitingPeriodDays':
          int.tryParse(_waitingPeriodCtrl.text.trim()) ?? 90,
      'enrollmentWindowDays':
          int.tryParse(_enrollmentWindowCtrl.text.trim()) ?? 30,
      'active': _active,
    };

    try {
      await _fs.saveDocument(
        collectionRef: FirebaseFirestore.instance.collection('benefitPlan'),
        data: data,
        docId: widget.docId,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save benefit plan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEditing ? 'Edit Benefit Plan' : 'New Benefit Plan';

    return Scaffold(
      appBar: StandardAppBar(title: title),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                children: [
                  _sectionHeader('Plan Details'),
                  TextFormField(
                    controller: _nameCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Plan Name'),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Plan name is required'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _type,
                    decoration:
                        const InputDecoration(labelText: 'Benefit Type'),
                    items: _benefitTypes
                        .map((t) => DropdownMenuItem(
                            value: t.$1, child: Text(t.$2)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _type = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _providerCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Provider / Carrier'),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _planNumberCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Plan / Group Number'),
                  ),
                  const SizedBox(height: 24),

                  _sectionHeader('Contributions (per pay period)'),
                  TextFormField(
                    controller: _employerContribCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Employer Contribution',
                      prefixText: '\$ ',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _employeeContribCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Employee Contribution',
                      prefixText: '\$ ',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _sectionHeader('Eligibility'),
                  DropdownButtonFormField<String>(
                    initialValue: _eligibilityType,
                    decoration:
                        const InputDecoration(labelText: 'Eligibility'),
                    items: const [
                      DropdownMenuItem(
                          value: 'full-time',
                          child: Text('Full-Time Only')),
                      DropdownMenuItem(
                          value: 'all', child: Text('All Employees')),
                      DropdownMenuItem(
                          value: 'custom',
                          child: Text('Custom (min hours)')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _eligibilityType = v);
                    },
                  ),
                  if (_eligibilityType == 'custom') ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _eligibilityMinHoursCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Minimum Weekly Hours',
                        helperText:
                            'ACA threshold is 30 hours/week for benefits eligibility',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _waitingPeriodCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Waiting Period (days)',
                      helperText: 'Days after hire before enrollment opens',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _enrollmentWindowCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Enrollment Window (days)',
                      helperText:
                          'Days after waiting period to complete enrollment',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                  ),
                  const SizedBox(height: 24),

                  SwitchListTile(
                    title: const Text('Active'),
                    subtitle: Text(
                      _active
                          ? 'Plan is available for enrollment'
                          : 'Plan is inactive',
                    ),
                    value: _active,
                    onChanged: (v) => setState(() => _active = v),
                    contentPadding: EdgeInsets.zero,
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

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey[700],
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
