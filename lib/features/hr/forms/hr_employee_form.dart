// lib/features/hr/forms/hr_employee_form.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/forms/cancel_save_adapter.dart';
import 'package:kleenops_admin/features/finances/services/local_tax_lookup_service.dart';
import 'package:kleenops_admin/services/firestore_service.dart';
import 'package:shared_widgets/tabs/standard_tab.dart';

class HrEmployeeForm extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final String? docId;

  const HrEmployeeForm({
    super.key,
    required this.companyRef,
    this.docId,
  });

  @override
  State<HrEmployeeForm> createState() => _HrEmployeeFormState();
}

class _HrEmployeeFormState extends State<HrEmployeeForm>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _fs = FirestoreService();
  late final TabController _tabController;

  // ── Personal tab ──
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _preferredNameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _dobCtrl;
  late final TextEditingController _notesCtrl;

  // Address
  late final TextEditingController _streetCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _stateCtrl;
  late final TextEditingController _zipCtrl;

  // SSN (last 4 stored, full encrypted server-side)
  late final TextEditingController _ssnCtrl;

  // Emergency contact
  late final TextEditingController _emergencyNameCtrl;
  late final TextEditingController _emergencyPhoneCtrl;
  late final TextEditingController _emergencyRelationCtrl;

  DateTime? _dateOfBirth;

  // ── Employment tab ──
  late final TextEditingController _startDateCtrl;
  DateTime? _startDate;
  String? _selectedRoleId;
  String _employmentType = 'full-time';
  String _classification = 'w2';
  String _exemptStatus = 'non-exempt';
  String _workState = '';
  late final TextEditingController _workCityCtrl;
  late final TextEditingController _workZipCtrl;
  List<Map<String, dynamic>> _localTaxJurisdictions = [];

  // ── Pay tab ──
  late final TextEditingController _payRateCtrl;
  String _payType = 'hourly';
  String _payFrequency = 'biweekly';
  bool _overtimeEligible = true;
  late final TextEditingController _overtimeRateCtrl;

  // ── Tax tab (W-4 fields) ──
  String _federalFilingStatus = 'single';
  late final TextEditingController _federalAllowancesCtrl;
  late final TextEditingController _additionalFederalCtrl;
  String _stateFilingStatus = '';
  late final TextEditingController _stateAllowancesCtrl;
  late final TextEditingController _additionalStateCtrl;
  bool _w4OnFile = false;
  DateTime? _w4Date;
  bool _i9Verified = false;
  DateTime? _i9VerifiedDate;

  // ── Banking tab (multi-account split direct deposit) ──
  String _paymentMethod = 'direct_deposit';
  // Each entry: {bankName, routingNumber, accountNumber, accountType, allocation}
  // allocation: 'full', 'percentage', 'fixed'
  // allocationValue: double (percentage 0-100 or fixed dollar amount)
  final List<Map<String, dynamic>> _bankAccounts = [];

  // Legacy single-account controllers (used when only 1 account)
  late final TextEditingController _bankNameCtrl;
  late final TextEditingController _routingNumberCtrl;
  late final TextEditingController _accountNumberCtrl;
  late final TextEditingController _confirmAccountCtrl;
  String _bankAccountType = 'checking';

  // ── State ──
  bool _loading = false;
  bool _saving = false;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _roleDocs = [];

  bool get _isEditing => widget.docId != null;

  static const _usStates = [
    '', 'AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'FL', 'GA',
    'HI', 'ID', 'IL', 'IN', 'IA', 'KS', 'KY', 'LA', 'ME', 'MD',
    'MA', 'MI', 'MN', 'MS', 'MO', 'MT', 'NE', 'NV', 'NH', 'NJ',
    'NM', 'NY', 'NC', 'ND', 'OH', 'OK', 'OR', 'PA', 'RI', 'SC',
    'SD', 'TN', 'TX', 'UT', 'VT', 'VA', 'WA', 'WV', 'WI', 'WY', 'DC',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);

    // Personal
    _firstNameCtrl = TextEditingController();
    _lastNameCtrl = TextEditingController();
    _preferredNameCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _dobCtrl = TextEditingController();
    _notesCtrl = TextEditingController();
    _streetCtrl = TextEditingController();
    _cityCtrl = TextEditingController();
    _stateCtrl = TextEditingController();
    _zipCtrl = TextEditingController();
    _ssnCtrl = TextEditingController();
    _emergencyNameCtrl = TextEditingController();
    _emergencyPhoneCtrl = TextEditingController();
    _emergencyRelationCtrl = TextEditingController();

    // Employment
    _startDateCtrl = TextEditingController();
    _workCityCtrl = TextEditingController();
    _workZipCtrl = TextEditingController();

    // Pay
    _payRateCtrl = TextEditingController();
    _overtimeRateCtrl = TextEditingController(text: '1.5');

    // Tax
    _federalAllowancesCtrl = TextEditingController(text: '0');
    _additionalFederalCtrl = TextEditingController(text: '0');
    _stateAllowancesCtrl = TextEditingController(text: '0');
    _additionalStateCtrl = TextEditingController(text: '0');

    // Banking
    _bankNameCtrl = TextEditingController();
    _routingNumberCtrl = TextEditingController();
    _accountNumberCtrl = TextEditingController();
    _confirmAccountCtrl = TextEditingController();

    _loadRoles();
    if (_isEditing) {
      _loadExisting();
    }
  }

  Future<void> _loadRoles() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('role')
          .orderBy('name')
          .get();
      if (mounted) setState(() => _roleDocs = snap.docs);
    } catch (_) {}
  }

  Future<void> _loadExisting() async {
    setState(() => _loading = true);
    try {
      final snap =
          await FirebaseFirestore.instance.collection('member').doc(widget.docId).get();
      if (!snap.exists) return;
      final d = snap.data();
      if (d == null) return;

      // Personal
      _firstNameCtrl.text = (d['firstName'] ?? '').toString();
      _lastNameCtrl.text = (d['lastName'] ?? '').toString();
      _preferredNameCtrl.text = (d['preferredName'] ?? '').toString();
      _emailCtrl.text = (d['email'] ?? '').toString();
      _phoneCtrl.text = (d['phone'] ?? '').toString();
      _notesCtrl.text = (d['notes'] ?? '').toString();

      if (d['dateOfBirth'] is Timestamp) {
        _dateOfBirth = (d['dateOfBirth'] as Timestamp).toDate();
        _dobCtrl.text = DateFormat('yMMMd').format(_dateOfBirth!);
      }

      // Address
      final addr = d['address'];
      if (addr is Map) {
        _streetCtrl.text = (addr['street'] ?? '').toString();
        _cityCtrl.text = (addr['city'] ?? '').toString();
        _stateCtrl.text = (addr['state'] ?? '').toString();
        _zipCtrl.text = (addr['zip'] ?? '').toString();
      }

      // Emergency contact
      final ec = d['emergencyContact'];
      if (ec is Map) {
        _emergencyNameCtrl.text = (ec['name'] ?? '').toString();
        _emergencyPhoneCtrl.text = (ec['phone'] ?? '').toString();
        _emergencyRelationCtrl.text = (ec['relationship'] ?? '').toString();
      }

      // Employment
      _employmentType = (d['employmentType'] ?? 'full-time').toString();
      _classification = (d['classification'] ?? 'w2').toString();
      _exemptStatus = (d['exemptStatus'] ?? 'non-exempt').toString();
      _workState = (d['workState'] ?? '').toString();
      _workCityCtrl.text = (d['workCity'] ?? '').toString();
      _workZipCtrl.text = (d['workZip'] ?? '').toString();
      final jList = d['localTaxJurisdictions'] as List<dynamic>?;
      if (jList != null) {
        _localTaxJurisdictions = jList
            .whereType<Map>()
            .map((j) => Map<String, dynamic>.from(j))
            .toList();
      }

      final roleVal = d['roleId'];
      if (roleVal is DocumentReference) {
        _selectedRoleId = roleVal.id;
      } else if (roleVal is String && roleVal.isNotEmpty) {
        _selectedRoleId =
            roleVal.contains('/') ? roleVal.split('/').last : roleVal;
      }

      if (d['startDate'] is Timestamp) {
        _startDate = (d['startDate'] as Timestamp).toDate();
        _startDateCtrl.text = DateFormat('yMMMd').format(_startDate!);
      }

      // Pay
      _payRateCtrl.text = (d['payRate'] ?? '').toString();
      _payType = (d['payType'] ?? 'hourly').toString();
      _payFrequency = (d['payFrequency'] ?? 'biweekly').toString();
      _overtimeEligible = d['overtimeEligible'] ?? true;
      if (d['overtimeRate'] != null) {
        _overtimeRateCtrl.text = d['overtimeRate'].toString();
      }

      // Tax
      _federalFilingStatus =
          (d['federalFilingStatus'] ?? 'single').toString();
      _federalAllowancesCtrl.text =
          (d['federalAllowances'] ?? 0).toString();
      _additionalFederalCtrl.text =
          (d['additionalFederalWithholding'] ?? 0).toString();
      _stateFilingStatus = (d['stateFilingStatus'] ?? '').toString();
      _stateAllowancesCtrl.text =
          (d['stateAllowances'] ?? 0).toString();
      _additionalStateCtrl.text =
          (d['additionalStateWithholding'] ?? 0).toString();

      // W-4 / I-9
      _w4OnFile = d['w4OnFile'] == true;
      if (d['w4Date'] is Timestamp) {
        _w4Date = (d['w4Date'] as Timestamp).toDate();
      }
      _i9Verified = d['i9Verified'] == true;
      if (d['i9VerifiedDate'] is Timestamp) {
        _i9VerifiedDate = (d['i9VerifiedDate'] as Timestamp).toDate();
      }

      // SSN (last 4 only stored in Firestore)
      _ssnCtrl.text = (d['ssnLast4'] ?? '').toString();

      // Banking
      _paymentMethod = (d['paymentMethod'] ?? 'direct_deposit').toString();
      final banks = d['bankAccounts'];
      if (banks is List && banks.isNotEmpty) {
        _bankAccounts.clear();
        for (final b in banks) {
          if (b is Map) {
            _bankAccounts.add(Map<String, dynamic>.from(b));
          }
        }
        // Populate legacy controllers from primary account
        final primary = _bankAccounts.first;
        _bankNameCtrl.text = (primary['bankName'] ?? '').toString();
        _routingNumberCtrl.text = (primary['routingNumber'] ?? '').toString();
        _accountNumberCtrl.text = (primary['accountNumber'] ?? '').toString();
        _confirmAccountCtrl.text = (primary['accountNumber'] ?? '').toString();
        _bankAccountType =
            (primary['accountType'] ?? 'checking').toString();
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _preferredNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _dobCtrl.dispose();
    _notesCtrl.dispose();
    _streetCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _zipCtrl.dispose();
    _emergencyNameCtrl.dispose();
    _emergencyPhoneCtrl.dispose();
    _emergencyRelationCtrl.dispose();
    _ssnCtrl.dispose();
    _workCityCtrl.dispose();
    _workZipCtrl.dispose();
    _startDateCtrl.dispose();
    _payRateCtrl.dispose();
    _overtimeRateCtrl.dispose();
    _federalAllowancesCtrl.dispose();
    _additionalFederalCtrl.dispose();
    _stateAllowancesCtrl.dispose();
    _additionalStateCtrl.dispose();
    _bankNameCtrl.dispose();
    _routingNumberCtrl.dispose();
    _accountNumberCtrl.dispose();
    _confirmAccountCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({
    required DateTime? current,
    required TextEditingController ctrl,
    required ValueChanged<DateTime> onPicked,
    int pastYears = 20,
    int futureYears = 5,
  }) async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - pastYears),
      lastDate: DateTime(now.year + futureYears),
    );
    if (picked != null) {
      setState(() {
        onPicked(picked);
        ctrl.text = DateFormat('yMMMd').format(picked);
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    final firstName = _firstNameCtrl.text.trim();
    final lastName = _lastNameCtrl.text.trim();
    final displayName =
        [firstName, lastName].where((s) => s.isNotEmpty).join(' ');

    final data = <String, dynamic>{
      'firstName': firstName,
      'lastName': lastName,
      'name': displayName,
      // Employment
      'employmentType': _employmentType,
      'classification': _classification,
      'exemptStatus': _exemptStatus,
      // Pay
      'payType': _payType,
      'payFrequency': _payFrequency,
      'overtimeEligible': _overtimeEligible,
      // Tax
      'federalFilingStatus': _federalFilingStatus,
      // Banking
      'paymentMethod': _paymentMethod,
    };

    // ── Optional string fields ──
    void setOrDelete(String key, String value) {
      if (value.isNotEmpty) {
        data[key] = value;
      } else if (_isEditing) {
        data[key] = FieldValue.delete();
      }
    }

    setOrDelete('preferredName', _preferredNameCtrl.text.trim());
    setOrDelete('email', _emailCtrl.text.trim());
    setOrDelete('phone', _phoneCtrl.text.trim());
    setOrDelete('notes', _notesCtrl.text.trim());
    setOrDelete('workState', _workState);
    setOrDelete('workCity', _workCityCtrl.text.trim());
    setOrDelete('workZip', _workZipCtrl.text.trim());
    if (_localTaxJurisdictions.isNotEmpty) {
      data['localTaxJurisdictions'] = _localTaxJurisdictions;
    } else if (_isEditing) {
      data['localTaxJurisdictions'] = FieldValue.delete();
    }
    setOrDelete('stateFilingStatus', _stateFilingStatus);

    // ── Numeric fields ──
    final payRate = double.tryParse(_payRateCtrl.text.trim());
    if (payRate != null) {
      data['payRate'] = payRate;
    } else if (_isEditing) {
      data['payRate'] = FieldValue.delete();
    }

    final overtimeRate = double.tryParse(_overtimeRateCtrl.text.trim());
    if (_overtimeEligible && overtimeRate != null) {
      data['overtimeRate'] = overtimeRate;
    }

    final fedAllowances = int.tryParse(_federalAllowancesCtrl.text.trim());
    if (fedAllowances != null) data['federalAllowances'] = fedAllowances;

    final addlFed = double.tryParse(_additionalFederalCtrl.text.trim());
    if (addlFed != null && addlFed > 0) {
      data['additionalFederalWithholding'] = addlFed;
    }

    final stateAllowances = int.tryParse(_stateAllowancesCtrl.text.trim());
    if (stateAllowances != null) data['stateAllowances'] = stateAllowances;

    final addlState = double.tryParse(_additionalStateCtrl.text.trim());
    if (addlState != null && addlState > 0) {
      data['additionalStateWithholding'] = addlState;
    }

    // ── SSN (store last 4 only for display; full SSN handled server-side) ──
    final ssn = _ssnCtrl.text.trim();
    if (ssn.isNotEmpty) {
      data['ssnLast4'] = ssn.length > 4 ? ssn.substring(ssn.length - 4) : ssn;
    } else if (_isEditing) {
      data['ssnLast4'] = FieldValue.delete();
    }

    // ── W-4 / I-9 ──
    data['w4OnFile'] = _w4OnFile;
    if (_w4OnFile && _w4Date != null) {
      data['w4Date'] = Timestamp.fromDate(_w4Date!);
    }
    data['i9Verified'] = _i9Verified;
    if (_i9Verified && _i9VerifiedDate != null) {
      data['i9VerifiedDate'] = Timestamp.fromDate(_i9VerifiedDate!);
    }

    // ── Role ──
    if (_selectedRoleId != null) {
      data['roleId'] =
          FirebaseFirestore.instance.collection('role').doc(_selectedRoleId);
    } else if (_isEditing) {
      data['roleId'] = FieldValue.delete();
    }

    // ── Dates ──
    if (_startDate != null) {
      data['startDate'] = Timestamp.fromDate(_startDate!);
    } else if (_isEditing) {
      data['startDate'] = FieldValue.delete();
    }

    if (_dateOfBirth != null) {
      data['dateOfBirth'] = Timestamp.fromDate(_dateOfBirth!);
    } else if (_isEditing) {
      data['dateOfBirth'] = FieldValue.delete();
    }

    // ── Address ──
    final street = _streetCtrl.text.trim();
    final city = _cityCtrl.text.trim();
    final addrState = _stateCtrl.text.trim();
    final zip = _zipCtrl.text.trim();
    if (street.isNotEmpty || city.isNotEmpty || addrState.isNotEmpty || zip.isNotEmpty) {
      data['address'] = {
        'street': street,
        'city': city,
        'state': addrState,
        'zip': zip,
      };
    } else if (_isEditing) {
      data['address'] = FieldValue.delete();
    }

    // ── Emergency contact ──
    final ecName = _emergencyNameCtrl.text.trim();
    final ecPhone = _emergencyPhoneCtrl.text.trim();
    final ecRelation = _emergencyRelationCtrl.text.trim();
    if (ecName.isNotEmpty || ecPhone.isNotEmpty) {
      data['emergencyContact'] = {
        'name': ecName,
        'phone': ecPhone,
        'relationship': ecRelation,
      };
    } else if (_isEditing) {
      data['emergencyContact'] = FieldValue.delete();
    }

    // ── Banking (multi-account split deposit) ──
    if (_paymentMethod == 'direct_deposit') {
      // Sync primary controllers back to _bankAccounts list
      final bankName = _bankNameCtrl.text.trim();
      final routing = _routingNumberCtrl.text.trim();
      final account = _accountNumberCtrl.text.trim();
      if (bankName.isNotEmpty && routing.isNotEmpty && account.isNotEmpty) {
        if (_bankAccounts.isEmpty) {
          _bankAccounts.add({});
        }
        _bankAccounts[0] = {
          ..._bankAccounts[0],
          'bankName': bankName,
          'routingNumber': routing,
          'accountNumber': account,
          'accountType': _bankAccountType,
          'isPrimary': true,
        };
        // If only one account, set allocation to 'full'
        if (_bankAccounts.length == 1) {
          _bankAccounts[0]['allocation'] = 'full';
        }
      }
      if (_bankAccounts.isNotEmpty) {
        data['bankAccounts'] = _bankAccounts;
      }
    } else if (_isEditing) {
      data['bankAccounts'] = FieldValue.delete();
    }

    if (!_isEditing) {
      data['active'] = true;
    }

    try {
      await _fs.saveDocument(
        collectionRef: FirebaseFirestore.instance.collection('member'),
        data: data,
        docId: widget.docId,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save employee: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ─────────────────────────── BUILD ───────────────────────────

  @override
  Widget build(BuildContext context) {
    final title = _isEditing ? 'Edit Employee' : 'New Employee';

    return Scaffold(
      appBar: StandardAppBar(title: title),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  Container(
                    color: Colors.white,
                    child: StandardTabBar(
                      controller: _tabController,
                      isScrollable: true,
                      dividerColor: Colors.grey[300],
                      indicatorColor: Theme.of(context).primaryColor,
                      indicatorWeight: 3.0,
                      labelColor: Colors.black,
                      unselectedLabelColor: Colors.grey[600],
                      tabs: const [
                        Tab(text: 'Personal'),
                        Tab(text: 'Employment'),
                        Tab(text: 'Pay'),
                        Tab(text: 'Tax'),
                        Tab(text: 'Banking'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildPersonalTab(),
                        _buildEmploymentTab(),
                        _buildPayTab(),
                        _buildTaxTab(),
                        _buildBankingTab(),
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

  // ─────────────────────── TAB: Personal ───────────────────────

  Widget _buildPersonalTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        // ── Name fields ──
        _sectionHeader('Name'),
        TextFormField(
          controller: _firstNameCtrl,
          decoration: const InputDecoration(labelText: 'First Name'),
          textCapitalization: TextCapitalization.words,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'First name is required' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _lastNameCtrl,
          decoration: const InputDecoration(labelText: 'Last Name'),
          textCapitalization: TextCapitalization.words,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Last name is required' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _preferredNameCtrl,
          decoration: const InputDecoration(labelText: 'Preferred Name'),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 24),

        // ── Contact ──
        _sectionHeader('Contact'),
        TextFormField(
          controller: _emailCtrl,
          decoration: const InputDecoration(labelText: 'Email'),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _phoneCtrl,
          decoration: const InputDecoration(labelText: 'Phone'),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _dobCtrl,
          readOnly: true,
          decoration: const InputDecoration(
            labelText: 'Date of Birth',
            suffixIcon: Icon(Icons.calendar_today),
          ),
          onTap: () => _pickDate(
            current: _dateOfBirth,
            ctrl: _dobCtrl,
            onPicked: (d) => _dateOfBirth = d,
            pastYears: 80,
            futureYears: 0,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _ssnCtrl,
          decoration: const InputDecoration(
            labelText: 'SSN (last 4 digits)',
            hintText: '1234',
            prefixIcon: Icon(Icons.lock_outline),
            helperText: 'Only last 4 digits stored for identification',
          ),
          keyboardType: TextInputType.number,
          obscureText: true,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(4),
          ],
        ),
        const SizedBox(height: 24),

        // ── Address ──
        _sectionHeader('Address'),
        TextFormField(
          controller: _streetCtrl,
          decoration: const InputDecoration(labelText: 'Street'),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _cityCtrl,
                decoration: const InputDecoration(labelText: 'City'),
                textCapitalization: TextCapitalization.words,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 1,
              child: TextFormField(
                controller: _stateCtrl,
                decoration: const InputDecoration(labelText: 'State'),
                textCapitalization: TextCapitalization.characters,
                maxLength: 2,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _zipCtrl,
                decoration: const InputDecoration(labelText: 'Zip'),
                keyboardType: TextInputType.number,
                maxLength: 10,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ── Emergency Contact ──
        _sectionHeader('Emergency Contact'),
        TextFormField(
          controller: _emergencyNameCtrl,
          decoration: const InputDecoration(labelText: 'Contact Name'),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _emergencyPhoneCtrl,
          decoration: const InputDecoration(labelText: 'Contact Phone'),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _emergencyRelationCtrl,
          decoration: const InputDecoration(labelText: 'Relationship'),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 24),

        // ── Notes ──
        _sectionHeader('Notes'),
        TextFormField(
          controller: _notesCtrl,
          decoration: const InputDecoration(labelText: 'Notes'),
          textCapitalization: TextCapitalization.sentences,
          minLines: 2,
          maxLines: 4,
        ),
      ],
    );
  }

  // ─────────────────────── TAB: Employment ─────────────────────

  Widget _buildEmploymentTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        _sectionHeader('Classification'),
        DropdownButtonFormField<String>(
          initialValue: _employmentType,
          decoration: const InputDecoration(labelText: 'Employment Type'),
          items: const [
            DropdownMenuItem(value: 'full-time', child: Text('Full-Time')),
            DropdownMenuItem(value: 'part-time', child: Text('Part-Time')),
            DropdownMenuItem(value: 'contractor', child: Text('Contractor')),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _employmentType = v);
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _classification,
          decoration: const InputDecoration(labelText: 'Worker Classification'),
          items: const [
            DropdownMenuItem(value: 'w2', child: Text('W-2 Employee')),
            DropdownMenuItem(value: '1099', child: Text('1099 Contractor')),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _classification = v);
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _exemptStatus,
          decoration: const InputDecoration(labelText: 'FLSA Exempt Status'),
          items: const [
            DropdownMenuItem(value: 'exempt', child: Text('Exempt')),
            DropdownMenuItem(value: 'non-exempt', child: Text('Non-Exempt')),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _exemptStatus = v);
          },
        ),
        const SizedBox(height: 24),

        _sectionHeader('Work Location'),
        TextFormField(
          controller: _workZipCtrl,
          decoration: const InputDecoration(
            labelText: 'Work ZIP Code',
            prefixIcon: Icon(Icons.location_on_outlined),
            helperText: 'Enter ZIP to auto-detect state, city, and local taxes',
          ),
          keyboardType: TextInputType.number,
          maxLength: 5,
          buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (val) {
            if (val.length == 5) _lookupZip(val);
          },
        ),
        const SizedBox(height: 12),
        if (_localTaxJurisdictions.isNotEmpty) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Local Tax Jurisdictions',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.green[800],
                  ),
                ),
                const SizedBox(height: 4),
                ..._localTaxJurisdictions.map((j) {
                  final name = (j['name'] ?? '').toString();
                  final type = (j['type'] ?? '').toString();
                  final rate = j['rate'] ?? j['totalRate'];
                  final rateStr = rate != null
                      ? ' (${(rate * 100).toStringAsFixed(2)}%)'
                      : '';
                  return Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle,
                            size: 14, color: Colors.green[600]),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '$name ($type)$rateStr',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
        DropdownButtonFormField<String>(
          initialValue: _workState.isEmpty ? null : _workState,
          decoration: const InputDecoration(labelText: 'Work State'),
          items: _usStates
              .where((s) => s.isNotEmpty)
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (v) => setState(() => _workState = v ?? ''),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _workCityCtrl,
          decoration: const InputDecoration(
            labelText: 'Work City (for local tax)',
            helperText: 'Required if employee works in a city with local income tax (e.g., NYC, Philadelphia)',
          ),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 24),

        _sectionHeader('Role & Start Date'),
        DropdownButtonFormField<String>(
          initialValue: _selectedRoleId,
          decoration: const InputDecoration(labelText: 'Role'),
          items: _roleDocs.map((doc) {
            final name = (doc.data()['name'] ?? doc.id).toString();
            return DropdownMenuItem(value: doc.id, child: Text(name));
          }).toList(),
          onChanged: (val) => setState(() => _selectedRoleId = val),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _startDateCtrl,
          readOnly: true,
          decoration: const InputDecoration(
            labelText: 'Start Date',
            suffixIcon: Icon(Icons.calendar_today),
          ),
          onTap: () => _pickDate(
            current: _startDate,
            ctrl: _startDateCtrl,
            onPicked: (d) => _startDate = d,
          ),
        ),
      ],
    );
  }

  // ─────────────────────── TAB: Pay ────────────────────────────

  Widget _buildPayTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        _sectionHeader('Compensation'),
        TextFormField(
          controller: _payRateCtrl,
          decoration: InputDecoration(
            labelText: _payType == 'salary' ? 'Annual Salary' : 'Hourly Rate',
            prefixText: '\$ ',
          ),
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _payType,
          decoration: const InputDecoration(labelText: 'Pay Type'),
          items: const [
            DropdownMenuItem(value: 'hourly', child: Text('Hourly')),
            DropdownMenuItem(value: 'salary', child: Text('Salary')),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _payType = v);
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _payFrequency,
          decoration: const InputDecoration(labelText: 'Pay Frequency'),
          items: const [
            DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
            DropdownMenuItem(value: 'biweekly', child: Text('Bi-Weekly')),
            DropdownMenuItem(
                value: 'semimonthly', child: Text('Semi-Monthly')),
            DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _payFrequency = v);
          },
        ),
        const SizedBox(height: 24),

        _sectionHeader('Overtime'),
        SwitchListTile(
          title: const Text('Overtime Eligible'),
          subtitle: Text(
            _overtimeEligible
                ? 'Employee is eligible for overtime pay'
                : 'Exempt from overtime',
          ),
          value: _overtimeEligible,
          onChanged: (v) => setState(() => _overtimeEligible = v),
          contentPadding: EdgeInsets.zero,
        ),
        if (_overtimeEligible) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _overtimeRateCtrl,
            decoration: const InputDecoration(
              labelText: 'Overtime Multiplier',
              hintText: '1.5',
              helperText: 'e.g. 1.5 = time-and-a-half',
            ),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
          ),
        ],
      ],
    );
  }

  // ─────────────────────── TAB: Tax ────────────────────────────

  Widget _buildTaxTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        _sectionHeader('Federal W-4'),
        DropdownButtonFormField<String>(
          initialValue: _federalFilingStatus,
          decoration: const InputDecoration(labelText: 'Filing Status'),
          items: const [
            DropdownMenuItem(value: 'single', child: Text('Single')),
            DropdownMenuItem(
                value: 'married', child: Text('Married Filing Jointly')),
            DropdownMenuItem(
                value: 'head_of_household',
                child: Text('Head of Household')),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _federalFilingStatus = v);
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _federalAllowancesCtrl,
          decoration: const InputDecoration(
            labelText: 'Federal Allowances / Dependents',
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _additionalFederalCtrl,
          decoration: const InputDecoration(
            labelText: 'Additional Federal Withholding',
            prefixText: '\$ ',
            helperText: 'Extra amount to withhold per pay period',
          ),
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
          ],
        ),
        const SizedBox(height: 24),

        _sectionHeader('State Withholding'),
        if (_workState.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'State: $_workState',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ),
        TextFormField(
          controller: _stateAllowancesCtrl,
          decoration: const InputDecoration(
            labelText: 'State Allowances',
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _additionalStateCtrl,
          decoration: const InputDecoration(
            labelText: 'Additional State Withholding',
            prefixText: '\$ ',
            helperText: 'Extra amount to withhold per pay period',
          ),
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
          ],
        ),
        const SizedBox(height: 24),

        // ── Tax Document Compliance ──
        _sectionHeader('Tax Document Compliance'),
        SwitchListTile(
          title: const Text('W-4 on File'),
          subtitle: Text(
            _w4OnFile
                ? (_w4Date != null
                    ? 'Signed ${DateFormat('yMMMd').format(_w4Date!)}'
                    : 'On file')
                : 'Employee must complete Form W-4 before first paycheck',
            style: TextStyle(
              fontSize: 12,
              color: _w4OnFile ? Colors.green[700] : Colors.orange[700],
            ),
          ),
          value: _w4OnFile,
          onChanged: (v) {
            setState(() {
              _w4OnFile = v;
              if (v && _w4Date == null) _w4Date = DateTime.now();
              if (!v) _w4Date = null;
            });
          },
          contentPadding: EdgeInsets.zero,
          secondary: Icon(
            _w4OnFile ? Icons.check_circle : Icons.warning_amber,
            color: _w4OnFile ? Colors.green[600] : Colors.orange[600],
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text('I-9 Employment Verification'),
          subtitle: Text(
            _i9Verified
                ? (_i9VerifiedDate != null
                    ? 'Verified ${DateFormat('yMMMd').format(_i9VerifiedDate!)}'
                    : 'Verified')
                : 'Must be completed within 3 business days of hire',
            style: TextStyle(
              fontSize: 12,
              color: _i9Verified ? Colors.green[700] : Colors.orange[700],
            ),
          ),
          value: _i9Verified,
          onChanged: (v) {
            setState(() {
              _i9Verified = v;
              if (v && _i9VerifiedDate == null) {
                _i9VerifiedDate = DateTime.now();
              }
              if (!v) _i9VerifiedDate = null;
            });
          },
          contentPadding: EdgeInsets.zero,
          secondary: Icon(
            _i9Verified ? Icons.check_circle : Icons.warning_amber,
            color: _i9Verified ? Colors.green[600] : Colors.orange[600],
          ),
        ),
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
              Icon(Icons.info_outline, color: Colors.blue[800], size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Federal law requires a signed W-4 before the first paycheck and '
                  'Form I-9 completion within 3 business days of hire. '
                  'The payroll system will warn if these are not on file.',
                  style: TextStyle(fontSize: 13, color: Colors.blue[900]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────── TAB: Banking ────────────────────────

  Widget _buildBankingTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        _sectionHeader('Payment Method'),
        DropdownButtonFormField<String>(
          initialValue: _paymentMethod,
          decoration: const InputDecoration(labelText: 'Payment Method'),
          items: const [
            DropdownMenuItem(
                value: 'direct_deposit', child: Text('Direct Deposit')),
            DropdownMenuItem(
                value: 'paper_check', child: Text('Paper Check')),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _paymentMethod = v);
          },
        ),
        const SizedBox(height: 24),

        if (_paymentMethod == 'direct_deposit') ...[
          _sectionHeader('Bank Account'),
          TextFormField(
            controller: _bankNameCtrl,
            decoration: const InputDecoration(labelText: 'Bank Name'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _routingNumberCtrl,
            decoration: const InputDecoration(
              labelText: 'Routing Number',
              helperText: '9-digit ABA routing number',
            ),
            keyboardType: TextInputType.number,
            maxLength: 9,
            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) {
              if (_paymentMethod != 'direct_deposit') return null;
              if (v == null || v.trim().isEmpty) return null;
              if (v.trim().length != 9) return 'Must be 9 digits';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _accountNumberCtrl,
            decoration: const InputDecoration(labelText: 'Account Number'),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirmAccountCtrl,
            decoration:
                const InputDecoration(labelText: 'Confirm Account Number'),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) {
              if (_paymentMethod != 'direct_deposit') return null;
              if (_accountNumberCtrl.text.trim().isEmpty) return null;
              if (v != _accountNumberCtrl.text) {
                return 'Account numbers do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _bankAccountType,
            decoration: const InputDecoration(labelText: 'Account Type'),
            items: const [
              DropdownMenuItem(value: 'checking', child: Text('Checking')),
              DropdownMenuItem(value: 'savings', child: Text('Savings')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _bankAccountType = v);
            },
          ),
          const SizedBox(height: 24),

          // ── Additional accounts (split deposit) ──
          if (_bankAccounts.length > 1) ...[
            const SizedBox(height: 16),
            _sectionHeader('Split Deposit Accounts'),
            ...List.generate(_bankAccounts.length - 1, (i) {
              final idx = i + 1;
              final acct = _bankAccounts[idx];
              final allocationType =
                  (acct['allocation'] ?? 'remainder').toString();
              final allocValue =
                  (acct['allocationValue'] as num?)?.toDouble();

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Account ${idx + 1}: ${acct['bankName'] ?? ''}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 18, color: Colors.red),
                          onPressed: () {
                            setState(() => _bankAccounts.removeAt(idx));
                          },
                        ),
                      ],
                    ),
                    Text(
                      '${acct['accountType'] ?? 'checking'} ····${_maskAccount(acct['accountNumber'])}',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      allocationType == 'percentage'
                          ? 'Allocation: ${allocValue ?? 0}%'
                          : allocationType == 'fixed'
                              ? 'Allocation: \$${allocValue ?? 0}'
                              : 'Allocation: Remainder',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            }),
          ],

          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _showAddBankAccountDialog(),
            icon: const Icon(Icons.add, size: 18),
            label: Text(_bankAccounts.length < 1
                ? 'Add Bank Account'
                : 'Add Split Deposit Account'),
          ),
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
                Icon(Icons.lock_outline, color: Colors.blue[800], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bank account information is stored securely. '
                    'Split deposits allow you to direct a percentage or fixed amount '
                    'to additional accounts (e.g., savings). The primary account '
                    'receives the remainder.',
                    style: TextStyle(fontSize: 13, color: Colors.blue[900]),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.print, color: Colors.grey[600]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Employee will receive a paper check each pay period. No bank details required.',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ─────────────────────── Helpers ──────────────────────────────

  Future<void> _lookupZip(String zip) async {
    if (zip.length != 5) return;
    try {
      final service = LocalTaxLookupService();
      final result = await service.lookupByZip(zip);
      if (!mounted) return;
      if (result['found'] == true) {
        setState(() {
          final stateCode = (result['stateCode'] ?? '').toString();
          final cityName = (result['cityName'] ?? '').toString();
          if (stateCode.isNotEmpty) _workState = stateCode;
          if (cityName.isNotEmpty) _workCityCtrl.text = cityName;
          _localTaxJurisdictions = (result['jurisdictions']
                  as List<Map<String, dynamic>>?) ??
              [];
        });
        // Show info if local taxes found
        if (_localTaxJurisdictions.isNotEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${_localTaxJurisdictions.length} local tax jurisdiction(s) found for ZIP $zip',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (_) {
      // ZIP not in database — fallback to manual entry
    }
  }

  String _maskAccount(dynamic acctNum) {
    final s = (acctNum ?? '').toString();
    if (s.length <= 4) return s;
    return s.substring(s.length - 4);
  }

  Future<void> _showAddBankAccountDialog() async {
    final nameCtrl = TextEditingController();
    final routingCtrl = TextEditingController();
    final accountCtrl = TextEditingController();
    String acctType = 'checking';
    String allocationType = 'percentage';
    final allocValueCtrl = TextEditingController(text: '10');

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDState) => AlertDialog(
          title: const Text('Add Split Deposit Account'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Bank Name'),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: routingCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Routing Number'),
                  keyboardType: TextInputType.number,
                  maxLength: 9,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: accountCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Account Number'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: acctType,
                  decoration:
                      const InputDecoration(labelText: 'Account Type'),
                  items: const [
                    DropdownMenuItem(
                        value: 'checking', child: Text('Checking')),
                    DropdownMenuItem(
                        value: 'savings', child: Text('Savings')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDState(() => acctType = v);
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: allocationType,
                  decoration: const InputDecoration(
                      labelText: 'Allocation Type'),
                  items: const [
                    DropdownMenuItem(
                        value: 'percentage', child: Text('Percentage')),
                    DropdownMenuItem(
                        value: 'fixed',
                        child: Text('Fixed Dollar Amount')),
                    DropdownMenuItem(
                        value: 'remainder', child: Text('Remainder')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setDState(() => allocationType = v);
                    }
                  },
                ),
                if (allocationType != 'remainder') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: allocValueCtrl,
                    decoration: InputDecoration(
                      labelText: allocationType == 'percentage'
                          ? 'Percentage (1-100)'
                          : 'Dollar Amount',
                      prefixText:
                          allocationType == 'fixed' ? '\$ ' : null,
                      suffixText:
                          allocationType == 'percentage' ? '%' : null,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx2),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx2, {
                  'bankName': nameCtrl.text.trim(),
                  'routingNumber': routingCtrl.text.trim(),
                  'accountNumber': accountCtrl.text.trim(),
                  'accountType': acctType,
                  'allocation': allocationType,
                  'allocationValue':
                      double.tryParse(allocValueCtrl.text.trim()),
                  'isPrimary': false,
                });
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (result != null && result['bankName'] != null) {
      setState(() => _bankAccounts.add(result));
    }
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
