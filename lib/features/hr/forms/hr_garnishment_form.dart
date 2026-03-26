// lib/features/hr/forms/hr_garnishment_form.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/forms/cancel_save_adapter.dart';

/// Form for adding/editing wage garnishments on an employee.
///
/// Garnishment types: child_support, tax_levy, creditor, student_loan, bankruptcy, other
/// Stored in company/{id}/member/{memberId} field 'garnishments' (array).
class HrGarnishmentForm extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final String memberId;
  final String memberName;
  final int? editIndex; // null = new, int = index in array to edit

  const HrGarnishmentForm({
    super.key,
    required this.companyRef,
    required this.memberId,
    required this.memberName,
    this.editIndex,
  });

  @override
  State<HrGarnishmentForm> createState() => _HrGarnishmentFormState();
}

class _HrGarnishmentFormState extends State<HrGarnishmentForm> {
  final _formKey = GlobalKey<FormState>();

  String _type = 'child_support';
  final _caseNumberCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  String _amountType = 'fixed'; // 'fixed' or 'percentage'
  final _maxTotalCtrl = TextEditingController();
  final _payeeCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  bool _active = true;
  bool _saving = false;

  bool get _isEditing => widget.editIndex != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) _loadExisting();
  }

  Future<void> _loadExisting() async {
    final snap = await FirebaseFirestore.instance
        .collection('member')
        .doc(widget.memberId)
        .get();
    final data = snap.data();
    if (data == null) return;
    final garnishments = data['garnishments'] as List<dynamic>? ?? [];
    if (widget.editIndex! >= garnishments.length) return;
    final g = garnishments[widget.editIndex!] as Map<String, dynamic>;

    setState(() {
      _type = (g['type'] ?? 'child_support').toString();
      _caseNumberCtrl.text = (g['caseNumber'] ?? '').toString();
      _amountCtrl.text = (g['amount'] ?? '').toString();
      _amountType = (g['amountType'] ?? 'fixed').toString();
      _maxTotalCtrl.text = (g['maxTotal'] ?? '').toString();
      _payeeCtrl.text = (g['payee'] ?? '').toString();
      _notesCtrl.text = (g['notes'] ?? '').toString();
      _active = g['active'] ?? true;
      if (g['startDate'] is Timestamp) {
        _startDate = (g['startDate'] as Timestamp).toDate();
      }
      if (g['endDate'] is Timestamp) {
        _endDate = (g['endDate'] as Timestamp).toDate();
      }
    });
  }

  @override
  void dispose() {
    _caseNumberCtrl.dispose();
    _amountCtrl.dispose();
    _maxTotalCtrl.dispose();
    _payeeCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    final garnishment = <String, dynamic>{
      'type': _type,
      'caseNumber': _caseNumberCtrl.text.trim(),
      'amount': double.tryParse(_amountCtrl.text.trim()) ?? 0,
      'amountType': _amountType,
      'payee': _payeeCtrl.text.trim(),
      'notes': _notesCtrl.text.trim(),
      'active': _active,
    };

    final maxTotal = double.tryParse(_maxTotalCtrl.text.trim());
    if (maxTotal != null && maxTotal > 0) {
      garnishment['maxTotal'] = maxTotal;
    }
    if (_startDate != null) {
      garnishment['startDate'] = Timestamp.fromDate(_startDate!);
    }
    if (_endDate != null) {
      garnishment['endDate'] = Timestamp.fromDate(_endDate!);
    }

    try {
      final memberRef =
          FirebaseFirestore.instance.collection('member').doc(widget.memberId);
      final snap = await memberRef.get();
      final data = snap.data() ?? {};
      final garnishments =
          List<dynamic>.from(data['garnishments'] as List? ?? []);

      if (_isEditing && widget.editIndex! < garnishments.length) {
        garnishments[widget.editIndex!] = garnishment;
      } else {
        garnishments.add(garnishment);
      }

      await memberRef.update({'garnishments': garnishments});

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate({
    required DateTime? current,
    required ValueChanged<DateTime> onPicked,
  }) async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) setState(() => onPicked(picked));
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEditing ? 'Edit Garnishment' : 'Add Garnishment';

    return Scaffold(
      appBar: StandardAppBar(title: title),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          children: [
            Text(
              'Employee: ${widget.memberName}',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(
                  labelText: 'Garnishment Type'),
              items: const [
                DropdownMenuItem(
                    value: 'child_support',
                    child: Text('Child Support')),
                DropdownMenuItem(
                    value: 'tax_levy', child: Text('Tax Levy (IRS/State)')),
                DropdownMenuItem(
                    value: 'creditor',
                    child: Text('Creditor Garnishment')),
                DropdownMenuItem(
                    value: 'student_loan',
                    child: Text('Student Loan')),
                DropdownMenuItem(
                    value: 'bankruptcy', child: Text('Bankruptcy')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _type = v);
              },
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _caseNumberCtrl,
              decoration: const InputDecoration(
                labelText: 'Case / Order Number',
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _amountCtrl,
                    decoration: InputDecoration(
                      labelText: _amountType == 'fixed'
                          ? 'Amount per Pay Period (\$)'
                          : 'Percentage of Disposable Income (%)',
                      prefixText: _amountType == 'fixed' ? '\$ ' : null,
                      suffixText: _amountType == 'percentage' ? '%' : null,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Amount is required';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _amountType,
                    decoration: const InputDecoration(
                        labelText: 'Type'),
                    items: const [
                      DropdownMenuItem(
                          value: 'fixed', child: Text('\$ Fixed')),
                      DropdownMenuItem(
                          value: 'percentage', child: Text('% of pay')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _amountType = v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _maxTotalCtrl,
              decoration: const InputDecoration(
                labelText: 'Maximum Total Amount (optional)',
                prefixText: '\$ ',
                helperText:
                    'Garnishment stops when this total is reached',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _payeeCtrl,
              decoration: const InputDecoration(
                labelText: 'Payee / Agency',
                helperText: 'Who receives the garnishment payment',
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),

            // Start date
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _startDate != null
                    ? 'Start: ${DateFormat('yMMMd').format(_startDate!)}'
                    : 'Start Date',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _pickDate(
                current: _startDate,
                onPicked: (d) => _startDate = d,
              ),
            ),

            // End date
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _endDate != null
                    ? 'End: ${DateFormat('yMMMd').format(_endDate!)}'
                    : 'End Date (optional)',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _pickDate(
                current: _endDate,
                onPicked: (d) => _endDate = d,
              ),
            ),

            SwitchListTile(
              title: const Text('Active'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
              contentPadding: EdgeInsets.zero,
            ),

            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(labelText: 'Notes'),
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
            ),

            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                border: Border.all(color: Colors.amber[200]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.gavel, color: Colors.amber[800], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Garnishments are automatically deducted during payroll processing. '
                      'Federal limits: max 25% of disposable earnings for creditors, '
                      '50-65% for child support depending on circumstances.',
                      style:
                          TextStyle(fontSize: 13, color: Colors.amber[900]),
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
      ),
    );
  }
}
