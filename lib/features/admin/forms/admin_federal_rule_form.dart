// lib/features/admin/forms/admin_federal_rule_form.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/forms/cancel_save_adapter.dart';
import 'package:shared_widgets/services/firestore_service.dart';

class AdminFederalRuleForm extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;

  const AdminFederalRuleForm({
    super.key,
    required this.companyRef,
  });

  @override
  State<AdminFederalRuleForm> createState() => _AdminFederalRuleFormState();
}

class _AdminFederalRuleFormState extends State<AdminFederalRuleForm> {
  final _formKey = GlobalKey<FormState>();
  final _fs = FirestoreService();

  late final TextEditingController _federalMinWageCtrl;
  late final TextEditingController _overtimeThresholdCtrl;
  late final TextEditingController _ficaRateCtrl;
  late final TextEditingController _ssRateCtrl;
  late final TextEditingController _ssWageCapCtrl;
  late final TextEditingController _medicareRateCtrl;
  late final TextEditingController _addlMedicareThresholdCtrl;
  late final TextEditingController _addlMedicareRateCtrl;
  late final TextEditingController _futaRateCtrl;
  late final TextEditingController _futaWageCapCtrl;
  late final TextEditingController _acaBenefitsThresholdCtrl;
  late final TextEditingController _effectiveYearCtrl;

  bool _loading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _federalMinWageCtrl = TextEditingController(text: '7.25');
    _overtimeThresholdCtrl = TextEditingController(text: '40');
    _ficaRateCtrl = TextEditingController(text: '0.0765');
    _ssRateCtrl = TextEditingController(text: '0.062');
    _ssWageCapCtrl = TextEditingController(text: '168600');
    _medicareRateCtrl = TextEditingController(text: '0.0145');
    _addlMedicareThresholdCtrl = TextEditingController(text: '200000');
    _addlMedicareRateCtrl = TextEditingController(text: '0.009');
    _futaRateCtrl = TextEditingController(text: '0.006');
    _futaWageCapCtrl = TextEditingController(text: '7000');
    _acaBenefitsThresholdCtrl = TextEditingController(text: '30');
    _effectiveYearCtrl = TextEditingController(
        text: DateTime.now().year.toString());
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('federalRule')
          .doc('current')
          .get();
      if (!snap.exists) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final d = snap.data();
      if (d == null) return;

      _federalMinWageCtrl.text =
          (d['federalMinimumWage'] ?? '7.25').toString();
      _overtimeThresholdCtrl.text =
          (d['overtimeThresholdWeekly'] ?? '40').toString();
      _ficaRateCtrl.text = (d['ficaRate'] ?? '0.0765').toString();
      _ssRateCtrl.text = (d['socialSecurityRate'] ?? '0.062').toString();
      _ssWageCapCtrl.text =
          (d['socialSecurityWageCap'] ?? '168600').toString();
      _medicareRateCtrl.text =
          (d['medicareRate'] ?? '0.0145').toString();
      _addlMedicareThresholdCtrl.text =
          (d['additionalMedicareThreshold'] ?? '200000').toString();
      _addlMedicareRateCtrl.text =
          (d['additionalMedicareRate'] ?? '0.009').toString();
      _futaRateCtrl.text = (d['futaRate'] ?? '0.006').toString();
      _futaWageCapCtrl.text =
          (d['futaWageCap'] ?? '7000').toString();
      _acaBenefitsThresholdCtrl.text =
          (d['acaBenefitsThreshold'] ?? '30').toString();
      _effectiveYearCtrl.text =
          (d['effectiveYear'] ?? DateTime.now().year).toString();
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _federalMinWageCtrl.dispose();
    _overtimeThresholdCtrl.dispose();
    _ficaRateCtrl.dispose();
    _ssRateCtrl.dispose();
    _ssWageCapCtrl.dispose();
    _medicareRateCtrl.dispose();
    _addlMedicareThresholdCtrl.dispose();
    _addlMedicareRateCtrl.dispose();
    _futaRateCtrl.dispose();
    _futaWageCapCtrl.dispose();
    _acaBenefitsThresholdCtrl.dispose();
    _effectiveYearCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    final data = <String, dynamic>{
      'federalMinimumWage':
          double.tryParse(_federalMinWageCtrl.text.trim()) ?? 7.25,
      'overtimeThresholdWeekly':
          int.tryParse(_overtimeThresholdCtrl.text.trim()) ?? 40,
      'ficaRate':
          double.tryParse(_ficaRateCtrl.text.trim()) ?? 0.0765,
      'socialSecurityRate':
          double.tryParse(_ssRateCtrl.text.trim()) ?? 0.062,
      'socialSecurityWageCap':
          int.tryParse(_ssWageCapCtrl.text.trim()) ?? 168600,
      'medicareRate':
          double.tryParse(_medicareRateCtrl.text.trim()) ?? 0.0145,
      'additionalMedicareThreshold':
          int.tryParse(_addlMedicareThresholdCtrl.text.trim()) ?? 200000,
      'additionalMedicareRate':
          double.tryParse(_addlMedicareRateCtrl.text.trim()) ?? 0.009,
      'futaRate':
          double.tryParse(_futaRateCtrl.text.trim()) ?? 0.006,
      'futaWageCap':
          int.tryParse(_futaWageCapCtrl.text.trim()) ?? 7000,
      'acaBenefitsThreshold':
          int.tryParse(_acaBenefitsThresholdCtrl.text.trim()) ?? 30,
      'effectiveYear':
          int.tryParse(_effectiveYearCtrl.text.trim()) ??
              DateTime.now().year,
    };

    try {
      await _fs.saveDocument(
        collectionRef: FirebaseFirestore.instance.collection('federalRule'),
        data: data,
        docId: 'current',
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save federal rules: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const StandardAppBar(title: 'Federal Regulations'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                children: [
                  _sectionHeader('Wages & Overtime'),
                  _numField(_federalMinWageCtrl, 'Federal Minimum Wage',
                      prefix: '\$ '),
                  const SizedBox(height: 12),
                  _numField(_overtimeThresholdCtrl,
                      'Overtime Threshold (hrs/week)'),
                  const SizedBox(height: 24),

                  _sectionHeader('FICA (Social Security + Medicare)'),
                  _numField(_ficaRateCtrl, 'Combined FICA Rate',
                      helper: 'Decimal, e.g. 0.0765 = 7.65%'),
                  const SizedBox(height: 12),
                  _numField(_ssRateCtrl, 'Social Security Rate',
                      helper: '0.062 = 6.2%'),
                  const SizedBox(height: 12),
                  _numField(_ssWageCapCtrl, 'SS Wage Cap',
                      prefix: '\$ ',
                      helper: 'Annual earnings cap for SS tax'),
                  const SizedBox(height: 12),
                  _numField(_medicareRateCtrl, 'Medicare Rate',
                      helper: '0.0145 = 1.45%'),
                  const SizedBox(height: 12),
                  _numField(_addlMedicareThresholdCtrl,
                      'Additional Medicare Threshold',
                      prefix: '\$ ',
                      helper: 'Annual income above which additional Medicare applies'),
                  const SizedBox(height: 12),
                  _numField(_addlMedicareRateCtrl,
                      'Additional Medicare Rate',
                      helper: '0.009 = 0.9%'),
                  const SizedBox(height: 24),

                  _sectionHeader('FUTA (Unemployment)'),
                  _numField(_futaRateCtrl, 'FUTA Rate',
                      helper: '0.006 = 0.6%'),
                  const SizedBox(height: 12),
                  _numField(_futaWageCapCtrl, 'FUTA Wage Cap',
                      prefix: '\$ ',
                      helper: 'First \$7,000 of each employee\'s wages'),
                  const SizedBox(height: 24),

                  _sectionHeader('ACA / Benefits'),
                  _numField(_acaBenefitsThresholdCtrl,
                      'ACA Benefits Threshold (hrs/week)',
                      helper:
                          'Employees averaging this many hours must be offered coverage'),
                  const SizedBox(height: 24),

                  _sectionHeader('Effective Period'),
                  _numField(_effectiveYearCtrl, 'Effective Year'),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      border: Border.all(color: Colors.blue[200]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline,
                            color: Colors.blue[800], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'These rates are used during payroll processing to calculate '
                            'employer and employee tax obligations. Update annually when '
                            'IRS publishes new rates.',
                            style: TextStyle(
                                fontSize: 13, color: Colors.blue[900]),
                          ),
                        ),
                      ],
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

  Widget _numField(
    TextEditingController ctrl,
    String label, {
    String? prefix,
    String? helper,
  }) {
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefix,
        helperText: helper,
        helperMaxLines: 2,
      ),
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
      ],
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
