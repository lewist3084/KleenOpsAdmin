// lib/features/admin/forms/adminStateRuleForm.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/forms/cancel_save_adapter.dart';
import 'package:kleenops_admin/services/firestore_service.dart';

class AdminStateRuleForm extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final String? stateCode;

  const AdminStateRuleForm({
    super.key,
    required this.companyRef,
    this.stateCode,
  });

  @override
  State<AdminStateRuleForm> createState() => _AdminStateRuleFormState();
}

class _AdminStateRuleFormState extends State<AdminStateRuleForm> {
  final _formKey = GlobalKey<FormState>();
  final _fs = FirestoreService();

  String _stateCode = '';
  late final TextEditingController _stateNameCtrl;
  late final TextEditingController _minimumWageCtrl;
  late final TextEditingController _overtimeThresholdCtrl;
  late final TextEditingController _overtimeMultiplierCtrl;
  late final TextEditingController _benefitsThresholdCtrl;
  late final TextEditingController _stateTaxRateCtrl;
  late final TextEditingController _sickLeaveAccrualCtrl;
  late final TextEditingController _sickLeaveMaxCtrl;
  late final TextEditingController _mealBreakAfterCtrl;
  late final TextEditingController _restBreakEveryCtrl;
  late final TextEditingController _stateUnemploymentRateCtrl;
  late final TextEditingController _notesCtrl;

  bool _workersCompRequired = true;
  bool _ptoMandated = false;
  String _benefitsThresholdType = 'weekly';
  bool _loading = false;
  bool _saving = false;

  bool get _isEditing => widget.stateCode != null;

  static const _usStates = <String, String>{
    'AL': 'Alabama', 'AK': 'Alaska', 'AZ': 'Arizona', 'AR': 'Arkansas',
    'CA': 'California', 'CO': 'Colorado', 'CT': 'Connecticut',
    'DE': 'Delaware', 'FL': 'Florida', 'GA': 'Georgia', 'HI': 'Hawaii',
    'ID': 'Idaho', 'IL': 'Illinois', 'IN': 'Indiana', 'IA': 'Iowa',
    'KS': 'Kansas', 'KY': 'Kentucky', 'LA': 'Louisiana', 'ME': 'Maine',
    'MD': 'Maryland', 'MA': 'Massachusetts', 'MI': 'Michigan',
    'MN': 'Minnesota', 'MS': 'Mississippi', 'MO': 'Missouri',
    'MT': 'Montana', 'NE': 'Nebraska', 'NV': 'Nevada',
    'NH': 'New Hampshire', 'NJ': 'New Jersey', 'NM': 'New Mexico',
    'NY': 'New York', 'NC': 'North Carolina', 'ND': 'North Dakota',
    'OH': 'Ohio', 'OK': 'Oklahoma', 'OR': 'Oregon', 'PA': 'Pennsylvania',
    'RI': 'Rhode Island', 'SC': 'South Carolina', 'SD': 'South Dakota',
    'TN': 'Tennessee', 'TX': 'Texas', 'UT': 'Utah', 'VT': 'Vermont',
    'VA': 'Virginia', 'WA': 'Washington', 'WV': 'West Virginia',
    'WI': 'Wisconsin', 'WY': 'Wyoming', 'DC': 'District of Columbia',
  };

  @override
  void initState() {
    super.initState();
    _stateNameCtrl = TextEditingController();
    _minimumWageCtrl = TextEditingController(text: '7.25');
    _overtimeThresholdCtrl = TextEditingController(text: '40');
    _overtimeMultiplierCtrl = TextEditingController(text: '1.5');
    _benefitsThresholdCtrl = TextEditingController(text: '30');
    _stateTaxRateCtrl = TextEditingController();
    _sickLeaveAccrualCtrl = TextEditingController();
    _sickLeaveMaxCtrl = TextEditingController();
    _mealBreakAfterCtrl = TextEditingController();
    _restBreakEveryCtrl = TextEditingController();
    _stateUnemploymentRateCtrl = TextEditingController();
    _notesCtrl = TextEditingController();

    if (_isEditing) {
      _stateCode = widget.stateCode!;
      _loadExisting();
    }
  }

  Future<void> _loadExisting() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('stateRule')
          .doc(_stateCode)
          .get();
      if (!snap.exists) return;
      final d = snap.data();
      if (d == null) return;

      _stateNameCtrl.text = (d['stateName'] ?? '').toString();
      _minimumWageCtrl.text = (d['minimumWage'] ?? '').toString();
      _overtimeThresholdCtrl.text =
          (d['overtimeThreshold'] ?? '40').toString();
      _overtimeMultiplierCtrl.text =
          (d['overtimeMultiplier'] ?? '1.5').toString();
      _benefitsThresholdCtrl.text =
          (d['benefitsThresholdHours'] ?? '30').toString();
      _benefitsThresholdType =
          (d['benefitsThresholdType'] ?? 'weekly').toString();
      _stateTaxRateCtrl.text = (d['stateTaxRate'] ?? '').toString();
      _workersCompRequired = d['workersCompRequired'] ?? true;
      _ptoMandated = d['ptoMandated'] ?? false;

      final breaks = d['requiredBreaks'];
      if (breaks is Map) {
        _mealBreakAfterCtrl.text =
            (breaks['mealAfterHours'] ?? '').toString();
        _restBreakEveryCtrl.text =
            (breaks['restEveryHours'] ?? '').toString();
      }

      final sickLeave = d['sickLeaveAccrual'];
      if (sickLeave is Map) {
        _sickLeaveAccrualCtrl.text =
            (sickLeave['hoursPerWorked'] ?? '').toString();
        _sickLeaveMaxCtrl.text =
            (sickLeave['maxAnnual'] ?? '').toString();
      }

      _stateUnemploymentRateCtrl.text =
          (d['stateUnemploymentRate'] ?? '').toString();
      _notesCtrl.text = (d['notes'] ?? '').toString();
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _stateNameCtrl.dispose();
    _minimumWageCtrl.dispose();
    _overtimeThresholdCtrl.dispose();
    _overtimeMultiplierCtrl.dispose();
    _benefitsThresholdCtrl.dispose();
    _stateTaxRateCtrl.dispose();
    _sickLeaveAccrualCtrl.dispose();
    _sickLeaveMaxCtrl.dispose();
    _mealBreakAfterCtrl.dispose();
    _restBreakEveryCtrl.dispose();
    _stateUnemploymentRateCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_stateCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a state')),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    final data = <String, dynamic>{
      'stateCode': _stateCode,
      'stateName': _stateNameCtrl.text.trim().isNotEmpty
          ? _stateNameCtrl.text.trim()
          : _usStates[_stateCode] ?? _stateCode,
      'minimumWage':
          double.tryParse(_minimumWageCtrl.text.trim()) ?? 7.25,
      'overtimeThreshold':
          double.tryParse(_overtimeThresholdCtrl.text.trim()) ?? 40,
      'overtimeMultiplier':
          double.tryParse(_overtimeMultiplierCtrl.text.trim()) ?? 1.5,
      'benefitsThresholdHours':
          double.tryParse(_benefitsThresholdCtrl.text.trim()) ?? 30,
      'benefitsThresholdType': _benefitsThresholdType,
      'workersCompRequired': _workersCompRequired,
      'ptoMandated': _ptoMandated,
    };

    final stateTaxRate =
        double.tryParse(_stateTaxRateCtrl.text.trim());
    if (stateTaxRate != null) data['stateTaxRate'] = stateTaxRate;

    final stateUnemploymentRate =
        double.tryParse(_stateUnemploymentRateCtrl.text.trim());
    if (stateUnemploymentRate != null) {
      data['stateUnemploymentRate'] = stateUnemploymentRate;
    }

    // Breaks
    final mealAfter =
        double.tryParse(_mealBreakAfterCtrl.text.trim());
    final restEvery =
        double.tryParse(_restBreakEveryCtrl.text.trim());
    if (mealAfter != null || restEvery != null) {
      data['requiredBreaks'] = {
        if (mealAfter != null) 'mealAfterHours': mealAfter,
        if (restEvery != null) 'restEveryHours': restEvery,
      };
    }

    // Sick leave
    final accrual =
        double.tryParse(_sickLeaveAccrualCtrl.text.trim());
    final maxAnnual =
        double.tryParse(_sickLeaveMaxCtrl.text.trim());
    if (accrual != null || maxAnnual != null) {
      data['sickLeaveAccrual'] = {
        if (accrual != null) 'hoursPerWorked': accrual,
        if (maxAnnual != null) 'maxAnnual': maxAnnual,
      };
    }

    final notes = _notesCtrl.text.trim();
    if (notes.isNotEmpty) data['notes'] = notes;

    try {
      await _fs.saveDocument(
        collectionRef: FirebaseFirestore.instance.collection('stateRule'),
        data: data,
        docId: _stateCode,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save state rule: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEditing
        ? 'Edit State Rule — $_stateCode'
        : 'New State Rule';

    return Scaffold(
      appBar: StandardAppBar(title: title),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                children: [
                  // ── State selector ──
                  _sectionHeader('State'),
                  if (!_isEditing)
                    DropdownButtonFormField<String>(
                      initialValue:
                          _stateCode.isEmpty ? null : _stateCode,
                      decoration: const InputDecoration(
                          labelText: 'Select State'),
                      items: _usStates.entries
                          .map((e) => DropdownMenuItem(
                                value: e.key,
                                child: Text('${e.value} (${e.key})'),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            _stateCode = v;
                            _stateNameCtrl.text =
                                _usStates[v] ?? v;
                          });
                        }
                      },
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'State is required'
                          : null,
                    )
                  else
                    Text(
                      '${_usStates[_stateCode] ?? _stateCode} ($_stateCode)',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  const SizedBox(height: 24),

                  // ── Wages & Overtime ──
                  _sectionHeader('Wages & Overtime'),
                  TextFormField(
                    controller: _minimumWageCtrl,
                    decoration: const InputDecoration(
                      labelText: 'State Minimum Wage',
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
                    controller: _overtimeThresholdCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Overtime Threshold (hours/week)',
                      helperText: 'Hours per week before overtime kicks in',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _overtimeMultiplierCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Overtime Multiplier',
                      helperText: 'e.g. 1.5 = time-and-a-half',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Benefits ──
                  _sectionHeader('Benefits Eligibility'),
                  TextFormField(
                    controller: _benefitsThresholdCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Benefits Threshold (hours)',
                      helperText:
                          'Weekly hours above which benefits are required (ACA: 30)',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _benefitsThresholdType,
                    decoration: const InputDecoration(
                        labelText: 'Threshold Type'),
                    items: const [
                      DropdownMenuItem(
                          value: 'weekly', child: Text('Weekly')),
                      DropdownMenuItem(
                          value: 'monthly', child: Text('Monthly')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _benefitsThresholdType = v);
                      }
                    },
                  ),
                  const SizedBox(height: 24),

                  // ── Tax ──
                  _sectionHeader('State Tax'),
                  TextFormField(
                    controller: _stateTaxRateCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Flat State Tax Rate',
                      suffixText: '%',
                      helperText:
                          'For flat-rate states. Leave blank for graduated brackets.',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _stateUnemploymentRateCtrl,
                    decoration: const InputDecoration(
                      labelText: 'State Unemployment Rate',
                      suffixText: '%',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Breaks ──
                  _sectionHeader('Required Breaks'),
                  TextFormField(
                    controller: _mealBreakAfterCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Meal Break After (hours)',
                      helperText:
                          'Hours worked before a meal break is required',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _restBreakEveryCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Rest Break Every (hours)',
                      helperText: 'Paid rest break frequency',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Leave ──
                  _sectionHeader('Sick Leave'),
                  TextFormField(
                    controller: _sickLeaveAccrualCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Accrual Rate (hours per hours worked)',
                      helperText: 'e.g. 0.033 = 1 hr per 30 hrs worked',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _sickLeaveMaxCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Max Annual Hours',
                      helperText: 'Cap on annual sick leave accrual',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Toggles ──
                  _sectionHeader('Requirements'),
                  SwitchListTile(
                    title: const Text("Workers' Comp Required"),
                    value: _workersCompRequired,
                    onChanged: (v) =>
                        setState(() => _workersCompRequired = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    title: const Text('PTO Mandated'),
                    value: _ptoMandated,
                    onChanged: (v) =>
                        setState(() => _ptoMandated = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 24),

                  // ── Notes ──
                  _sectionHeader('Notes'),
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
