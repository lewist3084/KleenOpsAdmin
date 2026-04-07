// lib/features/finances/forms/finance_payroll_run_form.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/forms/cancel_save_adapter.dart';
import 'package:kleenops_admin/features/finances/services/payroll_service.dart';

class FinancePayrollRunForm extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;

  const FinancePayrollRunForm({
    super.key,
    required this.companyRef,
  });

  @override
  State<FinancePayrollRunForm> createState() => _FinancePayrollRunFormState();
}

class _FinancePayrollRunFormState extends State<FinancePayrollRunForm> {
  final _formKey = GlobalKey<FormState>();
  final _payroll = PayrollService();

  late final TextEditingController _periodStartCtrl;
  late final TextEditingController _periodEndCtrl;
  late final TextEditingController _payDateCtrl;

  DateTime? _periodStart;
  DateTime? _periodEnd;
  DateTime? _payDate;

  bool _loading = true;
  bool _saving = false;

  // Members and their hours
  List<_MemberEntry> _members = [];

  @override
  void initState() {
    super.initState();
    _periodStartCtrl = TextEditingController();
    _periodEndCtrl = TextEditingController();
    _payDateCtrl = TextEditingController();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('member')
          .where('active', isEqualTo: true)
          .orderBy('name')
          .get();
      if (mounted) {
        setState(() {
          _members = snap.docs.map((doc) {
            final data = doc.data();
            return _MemberEntry(
              id: doc.id,
              name: (data['name'] ?? '').toString(),
              payType: (data['payType'] ?? 'hourly').toString(),
              regularHoursCtrl: TextEditingController(text: '0'),
              overtimeHoursCtrl: TextEditingController(text: '0'),
            );
          }).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _periodStartCtrl.dispose();
    _periodEndCtrl.dispose();
    _payDateCtrl.dispose();
    for (final m in _members) {
      m.regularHoursCtrl.dispose();
      m.overtimeHoursCtrl.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate({
    required DateTime? current,
    required TextEditingController ctrl,
    required ValueChanged<DateTime> onPicked,
  }) async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) {
      setState(() {
        onPicked(picked);
        ctrl.text = DateFormat('yMMMd').format(picked);
      });
    }
  }

  /// Loads hours from timeEntry documents that overlap the pay period.
  Future<void> _loadFromTimesheets() async {
    if (_periodStart == null || _periodEnd == null) return;

    try {
      // Find all time entries whose weekStart falls within the pay period
      // (or slightly before, since a week can span the boundary)
      final queryStart =
          _periodStart!.subtract(const Duration(days: 6));
      final snap = await FirebaseFirestore.instance
          .collection('timeEntry')
          .where('weekStart',
              isGreaterThanOrEqualTo: Timestamp.fromDate(queryStart))
          .where('weekStart',
              isLessThanOrEqualTo: Timestamp.fromDate(_periodEnd!))
          .get();

      // Aggregate hours per member across matching weeks
      final hoursAgg = <String, ({double regular, double overtime})>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final memberId = (data['memberId'] ?? '').toString();
        if (memberId.isEmpty) continue;
        final regular =
            (data['regularHours'] as num?)?.toDouble() ?? 0;
        final overtime =
            (data['overtimeHours'] as num?)?.toDouble() ?? 0;
        final existing = hoursAgg[memberId];
        hoursAgg[memberId] = (
          regular: (existing?.regular ?? 0) + regular,
          overtime: (existing?.overtime ?? 0) + overtime,
        );
      }

      // Apply to member controllers
      int populated = 0;
      for (final m in _members) {
        final hours = hoursAgg[m.id];
        if (hours != null) {
          m.regularHoursCtrl.text =
              hours.regular > 0 ? hours.regular.toStringAsFixed(1) : '0';
          m.overtimeHoursCtrl.text =
              hours.overtime > 0 ? hours.overtime.toStringAsFixed(1) : '0';
          populated++;
        }
      }

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(populated > 0
                ? 'Loaded hours for $populated employees from timesheets'
                : 'No timesheet entries found for this pay period'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading timesheets: $e')),
        );
      }
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_periodStart == null || _periodEnd == null || _payDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select all dates')),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    try {
      // Create the run
      final runId = await _payroll.createPayrollRun(
        companyRef: widget.companyRef,
        periodStart: _periodStart!,
        periodEnd: _periodEnd!,
        payDate: _payDate!,
      );

      // Build hours map
      final hoursMap = <String, Map<String, double>>{};
      for (final m in _members) {
        final regular =
            double.tryParse(m.regularHoursCtrl.text.trim()) ?? 0;
        final overtime =
            double.tryParse(m.overtimeHoursCtrl.text.trim()) ?? 0;
        // Include salary employees (they get auto-calculated) and
        // hourly employees with hours
        if (m.payType == 'salary' || regular > 0) {
          hoursMap[m.id] = {
            'regularHours': regular,
            'overtimeHours': overtime,
          };
        }
      }

      // Generate pay stubs
      await _payroll.generatePayStubs(
        companyRef: widget.companyRef,
        runId: runId,
        hoursMap: hoursMap,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Payroll run created with ${hoursMap.length} pay stubs')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create payroll run: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const StandardAppBar(title: 'New Payroll Run'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                children: [
                  // ── Dates ──
                  _sectionHeader('Pay Period'),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _periodStartCtrl,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Period Start',
                            suffixIcon: Icon(Icons.calendar_today, size: 18),
                          ),
                          onTap: () => _pickDate(
                            current: _periodStart,
                            ctrl: _periodStartCtrl,
                            onPicked: (d) => _periodStart = d,
                          ),
                          validator: (_) =>
                              _periodStart == null ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _periodEndCtrl,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Period End',
                            suffixIcon: Icon(Icons.calendar_today, size: 18),
                          ),
                          onTap: () => _pickDate(
                            current: _periodEnd,
                            ctrl: _periodEndCtrl,
                            onPicked: (d) => _periodEnd = d,
                          ),
                          validator: (_) =>
                              _periodEnd == null ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _payDateCtrl,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Pay Date',
                      suffixIcon: Icon(Icons.calendar_today, size: 18),
                    ),
                    onTap: () => _pickDate(
                      current: _payDate,
                      ctrl: _payDateCtrl,
                      onPicked: (d) => _payDate = d,
                    ),
                    validator: (_) =>
                        _payDate == null ? 'Required' : null,
                  ),
                  const SizedBox(height: 24),

                  // ── Employee hours ──
                  _sectionHeader(
                      'Employee Hours (${_members.length} active)'),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Text(
                            'Salary employees are auto-calculated. Enter hours for hourly employees or load from timesheets.',
                            style: TextStyle(
                                fontSize: 12, color: Colors.blue[800]),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: (_periodStart != null && _periodEnd != null)
                          ? _loadFromTimesheets
                          : null,
                      icon: const Icon(Icons.schedule, size: 18),
                      label: const Text('Load Hours from Timesheets'),
                    ),
                  ),
                  const SizedBox(height: 12),

                  ..._members.map((m) => _buildMemberRow(m)),
                ],
              ),
            ),
      bottomNavigationBar: CancelSaveBar(
        onCancel: () => Navigator.of(context).pop(),
        onSave: _saving ? null : _handleSave,
        isSaving: _saving,
        saveLabel: 'Generate Payroll',
      ),
    );
  }

  Widget _buildMemberRow(_MemberEntry m) {
    final isSalary = m.payType == 'salary';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  m.name,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isSalary ? Colors.purple[50] : Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        isSalary ? Colors.purple[200]! : Colors.blue[200]!,
                  ),
                ),
                child: Text(
                  isSalary ? 'Salary' : 'Hourly',
                  style: TextStyle(
                    fontSize: 11,
                    color:
                        isSalary ? Colors.purple[800] : Colors.blue[800],
                  ),
                ),
              ),
            ],
          ),
          if (!isSalary) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: m.regularHoursCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Regular Hrs',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 8, vertical: 10),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: m.overtimeHoursCtrl,
                    decoration: const InputDecoration(
                      labelText: 'OT Hrs',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 8, vertical: 10),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                  ),
                ),
              ],
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Auto-calculated from annual salary',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ),
        ],
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

class _MemberEntry {
  final String id;
  final String name;
  final String payType;
  final TextEditingController regularHoursCtrl;
  final TextEditingController overtimeHoursCtrl;

  _MemberEntry({
    required this.id,
    required this.name,
    required this.payType,
    required this.regularHoursCtrl,
    required this.overtimeHoursCtrl,
  });
}
