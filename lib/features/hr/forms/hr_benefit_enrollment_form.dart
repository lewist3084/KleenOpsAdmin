// lib/features/hr/forms/hr_benefit_enrollment_form.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/forms/cancel_save_adapter.dart';
import 'package:kleenops_admin/services/firestore_service.dart';

class HrBenefitEnrollmentForm extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final String? planId;
  final String? planName;
  final String? memberId;
  final String? enrollmentId;

  const HrBenefitEnrollmentForm({
    super.key,
    required this.companyRef,
    this.planId,
    this.planName,
    this.memberId,
    this.enrollmentId,
  });

  @override
  State<HrBenefitEnrollmentForm> createState() =>
      _HrBenefitEnrollmentFormState();
}

class _HrBenefitEnrollmentFormState extends State<HrBenefitEnrollmentForm> {
  final _formKey = GlobalKey<FormState>();
  final _fs = FirestoreService();

  // Selections
  String? _selectedPlanId;
  String? _selectedMemberId;
  String _status = 'active';

  // Plan data (loaded when plan selected)
  Map<String, dynamic>? _planData;

  // Controllers
  late final TextEditingController _effectiveDateCtrl;
  late final TextEditingController _employeeContribCtrl;
  late final TextEditingController _employerContribCtrl;

  DateTime? _effectiveDate;
  bool _loading = false;
  bool _saving = false;

  // Loaded lists
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _planDocs = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _memberDocs = [];

  bool get _isEditing => widget.enrollmentId != null;

  @override
  void initState() {
    super.initState();
    _effectiveDateCtrl = TextEditingController();
    _employeeContribCtrl = TextEditingController();
    _employerContribCtrl = TextEditingController();

    _selectedPlanId = widget.planId;
    _selectedMemberId = widget.memberId;

    _loadPlans();
    _loadMembers();
    if (_isEditing) {
      _loadExisting();
    } else if (_selectedPlanId != null) {
      _loadPlanData(_selectedPlanId!);
    }
  }

  Future<void> _loadPlans() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('benefitPlan')
          .where('active', isEqualTo: true)
          .orderBy('name')
          .get();
      if (mounted) setState(() => _planDocs = snap.docs);
    } catch (_) {}
  }

  Future<void> _loadMembers() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('member')
          .where('active', isEqualTo: true)
          .orderBy('name')
          .get();
      if (mounted) setState(() => _memberDocs = snap.docs);
    } catch (_) {}
  }

  Future<void> _loadPlanData(String planId) async {
    try {
      final snap =
          await FirebaseFirestore.instance.collection('benefitPlan').doc(planId).get();
      if (!snap.exists) return;
      final data = snap.data();
      if (data == null) return;
      setState(() {
        _planData = data;
        _employeeContribCtrl.text =
            (data['employeeContribution'] ?? 0).toString();
        _employerContribCtrl.text =
            (data['employerContribution'] ?? 0).toString();
      });
    } catch (_) {}
  }

  Future<void> _loadExisting() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('benefitEnrollment')
          .doc(widget.enrollmentId)
          .get();
      if (!snap.exists) return;
      final d = snap.data();
      if (d == null) return;

      final planRef = d['benefitPlanId'];
      if (planRef is DocumentReference) {
        _selectedPlanId = planRef.id;
        _loadPlanData(planRef.id);
      }

      final memberRef = d['memberId'];
      if (memberRef is DocumentReference) {
        _selectedMemberId = memberRef.id;
      } else if (memberRef is String) {
        _selectedMemberId = memberRef;
      }

      _status = (d['status'] ?? 'active').toString();
      _employeeContribCtrl.text =
          (d['employeeContribution'] ?? 0).toString();
      _employerContribCtrl.text =
          (d['employerContribution'] ?? 0).toString();

      if (d['effectiveDate'] is Timestamp) {
        _effectiveDate = (d['effectiveDate'] as Timestamp).toDate();
        _effectiveDateCtrl.text =
            DateFormat('yMMMd').format(_effectiveDate!);
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _effectiveDateCtrl.dispose();
    _employeeContribCtrl.dispose();
    _employerContribCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickEffectiveDate() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _effectiveDate ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() {
        _effectiveDate = picked;
        _effectiveDateCtrl.text = DateFormat('yMMMd').format(picked);
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPlanId == null || _selectedMemberId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select both a plan and an employee')),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    // Resolve member name
    String memberName = '';
    final memberDoc = _memberDocs
        .where((d) => d.id == _selectedMemberId)
        .firstOrNull;
    if (memberDoc != null) {
      memberName = (memberDoc.data()['name'] ?? '').toString();
    }

    // Resolve plan name
    String planName = widget.planName ?? '';
    if (planName.isEmpty) {
      final planDoc = _planDocs
          .where((d) => d.id == _selectedPlanId)
          .firstOrNull;
      if (planDoc != null) {
        planName = (planDoc.data()['name'] ?? '').toString();
      }
    }

    final data = <String, dynamic>{
      'benefitPlanId':
          FirebaseFirestore.instance.collection('benefitPlan').doc(_selectedPlanId),
      'benefitPlanName': planName,
      'memberId': _selectedMemberId,
      'memberName': memberName,
      'status': _status,
      'employeeContribution':
          double.tryParse(_employeeContribCtrl.text.trim()) ?? 0,
      'employerContribution':
          double.tryParse(_employerContribCtrl.text.trim()) ?? 0,
      'enrollmentDate': FieldValue.serverTimestamp(),
    };

    if (_effectiveDate != null) {
      data['effectiveDate'] = Timestamp.fromDate(_effectiveDate!);
    }

    try {
      await _fs.saveDocument(
        collectionRef: FirebaseFirestore.instance.collection('benefitEnrollment'),
        data: data,
        docId: widget.enrollmentId,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save enrollment: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEditing ? 'Edit Enrollment' : 'Enroll in Benefit Plan';

    return Scaffold(
      appBar: StandardAppBar(title: title),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                children: [
                  _sectionHeader('Benefit Plan'),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedPlanId,
                    decoration:
                        const InputDecoration(labelText: 'Select Plan'),
                    items: _planDocs.map((doc) {
                      final name =
                          (doc.data()['name'] ?? doc.id).toString();
                      final type =
                          (doc.data()['type'] ?? '').toString();
                      return DropdownMenuItem(
                        value: doc.id,
                        child: Text('$name ($type)'),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _selectedPlanId = v);
                        _loadPlanData(v);
                      }
                    },
                    validator: (v) =>
                        (v == null) ? 'Plan is required' : null,
                  ),

                  if (_planData != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Provider: ${_planData!['provider'] ?? '—'} · '
                        'Waiting: ${_planData!['waitingPeriodDays'] ?? 90} days · '
                        'Eligibility: ${_planData!['eligibilityType'] ?? 'full-time'}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.blue[800]),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  _sectionHeader('Employee'),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedMemberId,
                    decoration: const InputDecoration(
                        labelText: 'Select Employee'),
                    items: _memberDocs.map((doc) {
                      final name =
                          (doc.data()['name'] ?? doc.id).toString();
                      return DropdownMenuItem(
                        value: doc.id,
                        child: Text(name),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _selectedMemberId = v);
                      }
                    },
                    validator: (v) =>
                        (v == null) ? 'Employee is required' : null,
                  ),
                  const SizedBox(height: 24),

                  _sectionHeader('Enrollment Details'),
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration:
                        const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(
                          value: 'pending', child: Text('Pending')),
                      DropdownMenuItem(
                          value: 'active', child: Text('Active')),
                      DropdownMenuItem(
                          value: 'waived', child: Text('Waived')),
                      DropdownMenuItem(
                          value: 'terminated',
                          child: Text('Terminated')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _status = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _effectiveDateCtrl,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Effective Date',
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    onTap: _pickEffectiveDate,
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
