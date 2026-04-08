// lib/features/hr/forms/hr_onboarding_profile_form.dart
//
// Create / edit an OnboardingProfile under company/{cid}/onboardingProfile.
// A profile bundles classification + default assignment + module access +
// schedule + a link to an existing onboardingTemplate. HR picks one at scan
// time and the cloud function applies its fields to the new member doc.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:kleenops_admin/app/shared_widgets/forms/cancel_save_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:shared_widgets/services/firestore_service.dart';

/// Module access flags. Same shape the cloud function writes onto member docs.
const List<String> kProfileAccessFlagKeys = [
  'tasks',
  'facilities',
  'marketplace',
  'objects',
  'processes',
  'scheduling',
  'hr',
  'supervision',
  'training',
  'quality',
  'safety',
  'inventory',
  'purchasing',
  'occupancy',
  'voc',
  'sales',
  'finance',
  'administration',
];

const Map<String, bool> _defaultAccessFlags = {
  'tasks': true,
  'facilities': false,
  'marketplace': false,
  'objects': false,
  'processes': false,
  'scheduling': false,
  'hr': false,
  'supervision': false,
  'training': false,
  'quality': false,
  'safety': false,
  'inventory': false,
  'purchasing': false,
  'occupancy': false,
  'voc': false,
  'sales': false,
  'finance': false,
  'administration': false,
};

class HrOnboardingProfileForm extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final String? docId;

  const HrOnboardingProfileForm({
    super.key,
    required this.companyRef,
    this.docId,
  });

  @override
  State<HrOnboardingProfileForm> createState() =>
      _HrOnboardingProfileFormState();
}

class _HrOnboardingProfileFormState extends State<HrOnboardingProfileForm> {
  final _formKey = GlobalKey<FormState>();
  final _fs = FirestoreService();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _weeklyHoursCtrl;

  String? _employmentType;
  String? _classification;
  String? _exemptStatus;
  String? _payType;
  DocumentReference<Map<String, dynamic>>? _defaultRoleRef;
  DocumentReference<Map<String, dynamic>>? _defaultTeamRef;
  DocumentReference<Map<String, dynamic>>? _onboardingTemplateRef;
  bool _benefitsEligible = false;
  Map<String, bool> _accessFlags = Map.from(_defaultAccessFlags);

  bool _loading = false;
  bool _saving = false;
  bool get _isEditing => widget.docId != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _descCtrl = TextEditingController();
    _weeklyHoursCtrl = TextEditingController();
    if (_isEditing) {
      _loadExisting();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _weeklyHoursCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    setState(() => _loading = true);
    try {
      final snap = await widget.companyRef
          .collection('onboardingProfile')
          .doc(widget.docId)
          .get();
      if (!snap.exists) return;
      final d = snap.data();
      if (d == null) return;

      _nameCtrl.text = (d['name'] ?? '').toString();
      _descCtrl.text = (d['description'] ?? '').toString();
      _employmentType = d['employmentType'] as String?;
      _classification = d['classification'] as String?;
      _exemptStatus = d['exemptStatus'] as String?;
      _payType = d['payType'] as String?;
      _defaultRoleRef = d['defaultRoleId'] is DocumentReference
          ? (d['defaultRoleId'] as DocumentReference)
              .withConverter<Map<String, dynamic>>(
              fromFirestore: (s, _) => s.data()!,
              toFirestore: (m, _) => m,
            )
          : null;
      _defaultTeamRef = d['defaultTeamId'] is DocumentReference
          ? (d['defaultTeamId'] as DocumentReference)
              .withConverter<Map<String, dynamic>>(
              fromFirestore: (s, _) => s.data()!,
              toFirestore: (m, _) => m,
            )
          : null;
      _onboardingTemplateRef = d['onboardingTemplateRef'] is DocumentReference
          ? (d['onboardingTemplateRef'] as DocumentReference)
              .withConverter<Map<String, dynamic>>(
              fromFirestore: (s, _) => s.data()!,
              toFirestore: (m, _) => m,
            )
          : null;
      _benefitsEligible = d['benefitsEligible'] == true;
      final hours = d['weeklyHours'];
      if (hours is num) _weeklyHoursCtrl.text = hours.toString();
      final flags = d['accessFlags'];
      if (flags is Map) {
        _accessFlags = {
          for (final k in kProfileAccessFlagKeys)
            k: flags[k] == true || (_defaultAccessFlags[k] ?? false),
        };
        // Honor false values explicitly written in the doc.
        for (final k in kProfileAccessFlagKeys) {
          if (flags.containsKey(k)) _accessFlags[k] = flags[k] == true;
        }
      }
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    final hoursText = _weeklyHoursCtrl.text.trim();
    final weeklyHours =
        hoursText.isEmpty ? null : num.tryParse(hoursText);

    final data = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'employmentType': _employmentType,
      'classification': _classification,
      'exemptStatus': _exemptStatus,
      'payType': _payType,
      'defaultRoleId': _defaultRoleRef,
      'defaultTeamId': _defaultTeamRef,
      'onboardingTemplateRef': _onboardingTemplateRef,
      'benefitsEligible': _benefitsEligible,
      'weeklyHours': weeklyHours,
      'accessFlags': _accessFlags,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (!_isEditing) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    try {
      await _fs.saveDocument(
        collectionRef: widget.companyRef.collection('onboardingProfile'),
        data: data,
        docId: widget.docId,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEditing ? 'Edit Profile' : 'New Onboarding Profile';

    return Scaffold(
      appBar: StandardAppBar(title: title),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  _SectionHeader(text: 'Basics'),
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Profile Name',
                      hintText: 'e.g. Hourly Part-Time',
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Name is required'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 1,
                    maxLines: 3,
                  ),

                  const SizedBox(height: 24),
                  _SectionHeader(text: 'Classification'),
                  _DropdownField(
                    label: 'Employment Type',
                    value: _employmentType,
                    items: const [
                      DropdownMenuItem(value: 'fullTime', child: Text('Full-Time')),
                      DropdownMenuItem(value: 'partTime', child: Text('Part-Time')),
                      DropdownMenuItem(value: 'contractor', child: Text('Contractor')),
                    ],
                    onChanged: (v) => setState(() => _employmentType = v),
                  ),
                  const SizedBox(height: 12),
                  _DropdownField(
                    label: 'Tax Classification',
                    value: _classification,
                    items: const [
                      DropdownMenuItem(value: 'w2', child: Text('W-2 Employee')),
                      DropdownMenuItem(value: '1099', child: Text('1099 Contractor')),
                    ],
                    onChanged: (v) => setState(() => _classification = v),
                  ),
                  const SizedBox(height: 12),
                  _DropdownField(
                    label: 'Exempt Status',
                    value: _exemptStatus,
                    items: const [
                      DropdownMenuItem(value: 'exempt', child: Text('Exempt')),
                      DropdownMenuItem(value: 'nonExempt', child: Text('Non-Exempt')),
                    ],
                    onChanged: (v) => setState(() => _exemptStatus = v),
                  ),
                  const SizedBox(height: 12),
                  _DropdownField(
                    label: 'Pay Type',
                    value: _payType,
                    items: const [
                      DropdownMenuItem(value: 'hourly', child: Text('Hourly')),
                      DropdownMenuItem(value: 'salary', child: Text('Salary')),
                    ],
                    onChanged: (v) => setState(() => _payType = v),
                  ),

                  const SizedBox(height: 24),
                  _SectionHeader(text: 'Default Assignment'),
                  _RefDropdown(
                    label: 'Default Role',
                    collectionRef: widget.companyRef.collection('role'),
                    value: _defaultRoleRef,
                    onChanged: (ref) => setState(() => _defaultRoleRef = ref),
                  ),
                  const SizedBox(height: 12),
                  _RefDropdown(
                    label: 'Default Team',
                    collectionRef: widget.companyRef.collection('team'),
                    value: _defaultTeamRef,
                    onChanged: (ref) => setState(() => _defaultTeamRef = ref),
                  ),

                  const SizedBox(height: 24),
                  _SectionHeader(text: 'Module Access'),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Modules the new hire can use after scan-in.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  _AccessFlagsGrid(
                    flags: _accessFlags,
                    onToggle: (key, value) =>
                        setState(() => _accessFlags[key] = value),
                  ),

                  const SizedBox(height: 24),
                  _SectionHeader(text: 'Schedule & Benefits'),
                  TextFormField(
                    controller: _weeklyHoursCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Default Weekly Hours',
                      hintText: 'e.g. 20 or 40',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.isEmpty) return null;
                      final n = num.tryParse(t);
                      if (n == null || n < 0) {
                        return 'Enter a valid number';
                      }
                      return null;
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Benefits Eligible'),
                    subtitle: const Text(
                      'Pre-flag the new hire as eligible for benefits enrollment.',
                    ),
                    value: _benefitsEligible,
                    onChanged: (v) => setState(() => _benefitsEligible = v),
                  ),

                  const SizedBox(height: 24),
                  _SectionHeader(text: 'Onboarding Step Template'),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Apply this onboarding checklist to new hires using this profile.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  _RefDropdown(
                    label: 'Step Template (optional)',
                    collectionRef: FirebaseFirestore.instance
                        .collection('onboardingTemplate'),
                    value: _onboardingTemplateRef,
                    onChanged: (ref) =>
                        setState(() => _onboardingTemplateRef = ref),
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
}

// ─────────────────────────── Helpers ───────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.grey[700],
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final String? value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      items: items,
      onChanged: onChanged,
    );
  }
}

class _RefDropdown extends StatelessWidget {
  final String label;
  final Query<Map<String, dynamic>> collectionRef;
  final DocumentReference<Map<String, dynamic>>? value;
  final ValueChanged<DocumentReference<Map<String, dynamic>>?> onChanged;

  const _RefDropdown({
    required this.label,
    required this.collectionRef,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
      future: collectionRef.get(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            child: const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final docs = snap.data!.docs;
        DocumentReference<Map<String, dynamic>>? selected = value;
        if (selected != null &&
            !docs.any((d) => d.reference.path == selected!.path)) {
          selected = null;
        }
        return DropdownButtonFormField<DocumentReference<Map<String, dynamic>>?>(
          initialValue: selected,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          items: [
            const DropdownMenuItem<
                DocumentReference<Map<String, dynamic>>?>(
              value: null,
              child: Text('— None —'),
            ),
            ...docs.map((doc) {
              final data = doc.data();
              final name = (data['name'] as String?)?.trim();
              final label = (name == null || name.isEmpty) ? doc.id : name;
              return DropdownMenuItem<
                  DocumentReference<Map<String, dynamic>>?>(
                value: doc.reference,
                child: Text(label),
              );
            }),
          ],
          onChanged: onChanged,
        );
      },
    );
  }
}

class _AccessFlagsGrid extends StatelessWidget {
  final Map<String, bool> flags;
  final void Function(String key, bool value) onToggle;

  const _AccessFlagsGrid({
    required this.flags,
    required this.onToggle,
  });

  String _label(String key) {
    if (key == 'voc') return 'VOC';
    if (key == 'hr') return 'HR';
    return key[0].toUpperCase() + key.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: kProfileAccessFlagKeys.map((key) {
        final on = flags[key] == true;
        return SizedBox(
          width: (MediaQuery.of(context).size.width - 48) / 2,
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(
              _label(key),
              style: const TextStyle(fontSize: 13),
            ),
            value: on,
            onChanged: (v) => onToggle(key, v),
          ),
        );
      }).toList(),
    );
  }
}
