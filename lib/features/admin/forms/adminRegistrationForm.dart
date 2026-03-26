import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/app/shared_widgets/forms/cancel_save_adapter.dart';

class AdminRegistrationFormScreen extends ConsumerStatefulWidget {
  const AdminRegistrationFormScreen({super.key});

  @override
  ConsumerState<AdminRegistrationFormScreen> createState() =>
      _AdminRegistrationFormState();
}

class _AdminRegistrationFormState
    extends ConsumerState<AdminRegistrationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _einCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _dunsCtrl = TextEditingController();
  final _sicCtrl = TextEditingController();
  final _naicsCtrl = TextEditingController();
  final _dateIncorporatedCtrl = TextEditingController();

  String _entityType = '';
  String _stateOfIncorporation = '';
  bool _loading = true;
  bool _saving = false;

  static const _entityTypes = [
    '',
    'LLC',
    'S-Corp',
    'C-Corp',
    'Sole Proprietorship',
    'Partnership',
    'Non-Profit',
  ];

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
    _loadExisting();
  }

  @override
  void dispose() {
    _einCtrl.dispose();
    _websiteCtrl.dispose();
    _dunsCtrl.dispose();
    _sicCtrl.dispose();
    _naicsCtrl.dispose();
    _dateIncorporatedCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    final companyRef = ref.read(companyIdProvider).value;
    if (companyRef == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final snap = await companyRef.get();
      final data = snap.data() ?? {};
      _einCtrl.text = (data['ein'] ?? '').toString();
      _entityType = (data['entityType'] ?? '').toString();
      _stateOfIncorporation = (data['stateOfIncorporation'] ?? '').toString();
      _dateIncorporatedCtrl.text = (data['dateIncorporated'] ?? '').toString();
      _websiteCtrl.text = (data['website'] ?? '').toString();
      _dunsCtrl.text = (data['dunsNumber'] ?? '').toString();
      _sicCtrl.text = (data['sicCode'] ?? '').toString();
      _naicsCtrl.text = (data['naicsCode'] ?? '').toString();

      if (!_entityTypes.contains(_entityType)) _entityType = '';
      if (!_usStates.contains(_stateOfIncorporation)) {
        _stateOfIncorporation = '';
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final companyRef = ref.read(companyIdProvider).value;
    if (companyRef == null) {
      if (mounted) setState(() => _saving = false);
      return;
    }

    try {
      await companyRef.update({
        'ein': _einCtrl.text.trim(),
        'entityType': _entityType,
        'stateOfIncorporation': _stateOfIncorporation,
        'dateIncorporated': _dateIncorporatedCtrl.text.trim(),
        'website': _websiteCtrl.text.trim(),
        'dunsNumber': _dunsCtrl.text.trim(),
        'sicCode': _sicCtrl.text.trim(),
        'naicsCode': _naicsCtrl.text.trim(),
      });
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const StandardAppBar(title: 'Edit Registration'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                children: [
                  TextFormField(
                    controller: _einCtrl,
                    decoration: const InputDecoration(
                      labelText: 'EIN / Tax ID',
                      hintText: 'XX-XXXXXXX',
                    ),
                    keyboardType: TextInputType.text,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _entityType,
                    decoration:
                        const InputDecoration(labelText: 'Entity Type'),
                    items: _entityTypes
                        .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(e.isEmpty ? '-- Select --' : e),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _entityType = v ?? ''),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _stateOfIncorporation,
                    decoration: const InputDecoration(
                        labelText: 'State of Incorporation'),
                    items: _usStates
                        .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(e.isEmpty ? '-- Select --' : e),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _stateOfIncorporation = v ?? ''),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _dateIncorporatedCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Date Incorporated',
                      hintText: 'YYYY-MM-DD',
                    ),
                    keyboardType: TextInputType.datetime,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _websiteCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Website'),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _dunsCtrl,
                    decoration:
                        const InputDecoration(labelText: 'DUNS Number'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _sicCtrl,
                    decoration:
                        const InputDecoration(labelText: 'SIC Code'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _naicsCtrl,
                    decoration:
                        const InputDecoration(labelText: 'NAICS Code'),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
      bottomNavigationBar: CancelSaveBar(
        onCancel: () => Navigator.of(context).pop(),
        onSave: _saving ? null : _save,
        isSaving: _saving,
      ),
    );
  }
}
