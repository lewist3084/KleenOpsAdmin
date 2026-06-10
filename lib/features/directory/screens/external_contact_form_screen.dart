// lib/features/directory/screens/external_contact_form_screen.dart
//
// Simple full-screen create/edit form for an external person (directory
// contact). Writes to company/{cid}/externalContact via
// DirectoryService.saveContact. Opened from the People-tab FAB (create) or a
// contact's edit affordance (edit).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kleenops_admin/app/shared_widgets/forms/form_ai_bottom_bar.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';

import '../models/external_contact.dart';
import '../providers/directory_providers.dart';

class ExternalContactFormScreen extends ConsumerStatefulWidget {
  const ExternalContactFormScreen({super.key, this.existing});

  /// When non-null the form edits an existing contact; otherwise it creates a
  /// new one.
  final ExternalContact? existing;

  @override
  ConsumerState<ExternalContactFormScreen> createState() =>
      _ExternalContactFormScreenState();
}

class _ExternalContactFormScreenState
    extends ConsumerState<ExternalContactFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtl;
  late final List<TextEditingController> _emails;
  late final List<TextEditingController> _phones;
  String? _organizationId;
  late bool _shared;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtl = TextEditingController(text: e?.name ?? '');
    _emails = _ctls(e?.emails);
    _phones = _ctls(e?.phones);
    if (_emails.isEmpty) _emails.add(TextEditingController());
    _organizationId = e?.organizationId;
    _shared = e?.shared ?? false;
  }

  List<TextEditingController> _ctls(List<String>? values) => (values ?? const [])
      .where((v) => v.trim().isNotEmpty)
      .map((v) => TextEditingController(text: v))
      .toList();

  @override
  void dispose() {
    _nameCtl.dispose();
    for (final c in _emails) {
      c.dispose();
    }
    for (final c in _phones) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> _collect(List<TextEditingController> ctls) => ctls
      .map((c) => c.text.trim())
      .where((v) => v.isNotEmpty)
      .toList();

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final companyRef = ref.read(companyIdProvider).value;
    if (companyRef == null) {
      SnackbarService.instance.showSnackBar(
        const SnackBar(content: Text('No company in context.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final myMemberId = ref.read(memberDocRefProvider).value?.id;
      await ref.read(directoryServiceProvider).saveContact(
            companyRef: companyRef,
            id: widget.existing?.id,
            name: _nameCtl.text.trim(),
            emails: _collect(_emails),
            phones: _collect(_phones),
            organizationId: _organizationId,
            ownerMemberId: myMemberId,
            shared: _shared,
          );
      if (!mounted) return;
      SnackbarService.instance.showSnackBar(
        SnackBar(content: Text(_isEdit ? 'Contact updated' : 'Contact added')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        SnackbarService.instance.showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orgs = ref.watch(organizationsProvider);
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        bottom: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Text(
                _isEdit ? 'Edit Person' : 'New Person',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 20),
              _ListSection(
                title: 'Emails',
                icon: Icons.email_outlined,
                hint: 'name@example.com',
                keyboardType: TextInputType.emailAddress,
                controllers: _emails,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 20),
              _ListSection(
                title: 'Phones',
                icon: Icons.phone_outlined,
                hint: '+1 555 123 4567',
                keyboardType: TextInputType.phone,
                controllers: _phones,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String?>(
                initialValue: _organizationId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Organization (optional)',
                  prefixIcon: Icon(Icons.business_outlined),
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('— None —'),
                  ),
                  for (final o in orgs)
                    DropdownMenuItem<String?>(
                      value: o.id,
                      child: Text(o.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setState(() => _organizationId = v),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Shared with company'),
                subtitle: const Text(
                    'When off, this contact is private to you.'),
                value: _shared,
                onChanged: (v) => setState(() => _shared = v),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: FormAiBottomBar(
        title: _isEdit ? 'Edit Person' : 'New Person',
        isSaving: _saving,
        onCancel: () => Navigator.of(context).maybePop(),
        onSave: _save,
      ),
    );
  }
}

/// Editable list of plain string values (add / remove rows).
class _ListSection extends StatelessWidget {
  const _ListSection({
    required this.title,
    required this.icon,
    required this.controllers,
    required this.onChanged,
    this.hint,
    this.keyboardType,
  });

  final String title;
  final IconData icon;
  final List<TextEditingController> controllers;
  final VoidCallback onChanged;
  final String? hint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
              onPressed: () {
                controllers.add(TextEditingController());
                onChanged();
              },
            ),
          ],
        ),
        for (int i = 0; i < controllers.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controllers[i],
                    keyboardType: keyboardType,
                    decoration: InputDecoration(
                      hintText: hint,
                      prefixIcon: Icon(icon),
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove',
                  icon: Icon(Icons.remove_circle_outline,
                      color: Colors.grey.shade500),
                  onPressed: () {
                    controllers.removeAt(i).dispose();
                    onChanged();
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }
}
