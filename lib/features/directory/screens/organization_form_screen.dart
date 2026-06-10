// lib/features/directory/screens/organization_form_screen.dart
//
// Full-screen create/edit form for a directory Organization. Rich fields
// (websites, domains, phones, locations, contacts) are captured as arrays and
// stored directly on the company/{cid}/organization doc via
// DirectoryService.saveOrganization. The overlord reconcile (reconcileGlobalOrg)
// then carries name/website/locations up to the top-level organization
// registry. Opened from the Organizations-tab FAB (create) or an org tile's
// edit affordance (edit).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kleenops_admin/app/shared_widgets/forms/form_ai_bottom_bar.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';

import '../models/organization.dart';
import '../providers/directory_providers.dart';

class OrganizationFormScreen extends ConsumerStatefulWidget {
  const OrganizationFormScreen({super.key, this.existing});

  /// When non-null the form edits an existing organization; otherwise it
  /// creates a new one.
  final Organization? existing;

  @override
  ConsumerState<OrganizationFormScreen> createState() =>
      _OrganizationFormScreenState();
}

class _OrganizationFormScreenState
    extends ConsumerState<OrganizationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtl;
  late final List<TextEditingController> _websites;
  late final List<TextEditingController> _domains;
  late final List<TextEditingController> _phones;
  late final List<_LocationControllers> _locations;
  late final List<_ContactControllers> _contacts;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtl = TextEditingController(text: e?.name ?? '');
    _websites = _stringControllers(e?.websites);
    _domains = _stringControllers(e?.domains);
    _phones = _stringControllers(e?.phones);
    _locations = (e?.locations ?? const [])
        .map((m) => _LocationControllers.fromMap(m))
        .toList();
    _contacts = (e?.contacts ?? const [])
        .map((m) => _ContactControllers.fromMap(m))
        .toList();
  }

  List<TextEditingController> _stringControllers(List<String>? values) {
    final list = (values ?? const [])
        .where((v) => v.trim().isNotEmpty)
        .map((v) => TextEditingController(text: v))
        .toList();
    return list;
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    for (final c in _websites) {
      c.dispose();
    }
    for (final c in _domains) {
      c.dispose();
    }
    for (final c in _phones) {
      c.dispose();
    }
    for (final l in _locations) {
      l.dispose();
    }
    for (final c in _contacts) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> _collectStrings(List<TextEditingController> ctls) => ctls
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
      final domains = _collectStrings(_domains)
          .map((d) => d.toLowerCase())
          .toList();
      await ref.read(directoryServiceProvider).saveOrganization(
            companyRef: companyRef,
            id: widget.existing?.id,
            name: _nameCtl.text.trim(),
            domains: domains,
            phones: _collectStrings(_phones),
            websites: _collectStrings(_websites),
            locations: _locations
                .map((l) => l.toMap())
                .where((m) => m.isNotEmpty)
                .toList(),
            contacts: _contacts
                .map((c) => c.toMap())
                .where((m) => m.isNotEmpty)
                .toList(),
          );
      if (!mounted) return;
      SnackbarService.instance.showSnackBar(
        SnackBar(
          content: Text(_isEdit ? 'Organization updated' : 'Organization added'),
        ),
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
                _isEdit ? 'Edit Organization' : 'New Organization',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  prefixIcon: Icon(Icons.business),
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 20),
              _StringListSection(
                title: 'Websites',
                icon: Icons.link,
                hint: 'https://example.com',
                keyboardType: TextInputType.url,
                controllers: _websites,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 20),
              _StringListSection(
                title: 'Email domains',
                icon: Icons.dns_outlined,
                hint: 'example.com',
                helper: 'Used to match incoming mail and the global registry.',
                controllers: _domains,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 20),
              _StringListSection(
                title: 'Phones',
                icon: Icons.phone_outlined,
                hint: '+1 555 123 4567',
                keyboardType: TextInputType.phone,
                controllers: _phones,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 24),
              _SectionHeader(
                title: 'Locations',
                onAdd: () =>
                    setState(() => _locations.add(_LocationControllers())),
              ),
              for (int i = 0; i < _locations.length; i++)
                _LocationCard(
                  key: ValueKey(_locations[i]),
                  controllers: _locations[i],
                  onRemove: () => setState(() {
                    _locations.removeAt(i).dispose();
                  }),
                ),
              const SizedBox(height: 24),
              _SectionHeader(
                title: 'Contacts',
                onAdd: () =>
                    setState(() => _contacts.add(_ContactControllers())),
              ),
              for (int i = 0; i < _contacts.length; i++)
                _ContactCard(
                  key: ValueKey(_contacts[i]),
                  controllers: _contacts[i],
                  onRemove: () => setState(() {
                    _contacts.removeAt(i).dispose();
                  }),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: FormAiBottomBar(
        title: _isEdit ? 'Edit Organization' : 'New Organization',
        isSaving: _saving,
        onCancel: () => Navigator.of(context).maybePop(),
        onSave: _save,
      ),
    );
  }
}

/// An editable list of plain string values (add / remove rows).
class _StringListSection extends StatelessWidget {
  const _StringListSection({
    required this.title,
    required this.icon,
    required this.controllers,
    required this.onChanged,
    this.hint,
    this.helper,
    this.keyboardType,
  });

  final String title;
  final IconData icon;
  final List<TextEditingController> controllers;
  final VoidCallback onChanged;
  final String? hint;
  final String? helper;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: title,
          onAdd: () {
            controllers.add(TextEditingController());
            onChanged();
          },
        ),
        if (helper != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(helper!,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onAdd});
  final String title;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        TextButton.icon(
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add'),
          onPressed: onAdd,
        ),
      ],
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({super.key, required this.controllers, required this.onRemove});
  final _LocationControllers controllers;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    Widget field(TextEditingController c, String label,
            {TextInputType? kb}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TextField(
            controller: c,
            keyboardType: kb,
            decoration: InputDecoration(
              labelText: label,
              isDense: true,
              border: const OutlineInputBorder(),
            ),
          ),
        );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.place_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(child: field(controllers.label, 'Label (e.g. HQ)')),
                IconButton(
                  tooltip: 'Remove location',
                  icon: Icon(Icons.delete_outline, color: Colors.grey.shade500),
                  onPressed: onRemove,
                ),
              ],
            ),
            field(controllers.address, 'Street address'),
            Row(
              children: [
                Expanded(child: field(controllers.city, 'City')),
                const SizedBox(width: 8),
                Expanded(child: field(controllers.state, 'State')),
              ],
            ),
            Row(
              children: [
                Expanded(
                    child: field(controllers.postalCode, 'Postal code')),
                const SizedBox(width: 8),
                Expanded(child: field(controllers.country, 'Country')),
              ],
            ),
            field(controllers.phone, 'Phone', kb: TextInputType.phone),
          ],
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({super.key, required this.controllers, required this.onRemove});
  final _ContactControllers controllers;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    Widget field(TextEditingController c, String label,
            {TextInputType? kb}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TextField(
            controller: c,
            keyboardType: kb,
            decoration: InputDecoration(
              labelText: label,
              isDense: true,
              border: const OutlineInputBorder(),
            ),
          ),
        );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.person_outline, size: 18),
                const SizedBox(width: 8),
                Expanded(child: field(controllers.name, 'Name')),
                IconButton(
                  tooltip: 'Remove contact',
                  icon: Icon(Icons.delete_outline, color: Colors.grey.shade500),
                  onPressed: onRemove,
                ),
              ],
            ),
            field(controllers.title, 'Title / role'),
            field(controllers.email, 'Email', kb: TextInputType.emailAddress),
            field(controllers.phone, 'Phone', kb: TextInputType.phone),
          ],
        ),
      ),
    );
  }
}

class _LocationControllers {
  final TextEditingController label;
  final TextEditingController address;
  final TextEditingController city;
  final TextEditingController state;
  final TextEditingController postalCode;
  final TextEditingController country;
  final TextEditingController phone;

  _LocationControllers()
      : label = TextEditingController(),
        address = TextEditingController(),
        city = TextEditingController(),
        state = TextEditingController(),
        postalCode = TextEditingController(),
        country = TextEditingController(),
        phone = TextEditingController();

  _LocationControllers.fromMap(Map<String, dynamic> m)
      : label = TextEditingController(text: (m['label'] ?? '').toString()),
        address = TextEditingController(text: (m['address'] ?? '').toString()),
        city = TextEditingController(text: (m['city'] ?? '').toString()),
        state = TextEditingController(text: (m['state'] ?? '').toString()),
        postalCode =
            TextEditingController(text: (m['postalCode'] ?? '').toString()),
        country = TextEditingController(text: (m['country'] ?? '').toString()),
        phone = TextEditingController(text: (m['phone'] ?? '').toString());

  Map<String, dynamic> toMap() {
    final m = <String, dynamic>{};
    void put(String k, TextEditingController c) {
      final v = c.text.trim();
      if (v.isNotEmpty) m[k] = v;
    }

    put('label', label);
    put('address', address);
    put('city', city);
    put('state', state);
    put('postalCode', postalCode);
    put('country', country);
    put('phone', phone);
    return m;
  }

  void dispose() {
    label.dispose();
    address.dispose();
    city.dispose();
    state.dispose();
    postalCode.dispose();
    country.dispose();
    phone.dispose();
  }
}

class _ContactControllers {
  final TextEditingController name;
  final TextEditingController title;
  final TextEditingController email;
  final TextEditingController phone;

  _ContactControllers()
      : name = TextEditingController(),
        title = TextEditingController(),
        email = TextEditingController(),
        phone = TextEditingController();

  _ContactControllers.fromMap(Map<String, dynamic> m)
      : name = TextEditingController(text: (m['name'] ?? '').toString()),
        title = TextEditingController(text: (m['title'] ?? '').toString()),
        email = TextEditingController(text: (m['email'] ?? '').toString()),
        phone = TextEditingController(text: (m['phone'] ?? '').toString());

  Map<String, dynamic> toMap() {
    final m = <String, dynamic>{};
    void put(String k, TextEditingController c) {
      final v = c.text.trim();
      if (v.isNotEmpty) m[k] = v;
    }

    put('name', name);
    put('title', title);
    put('email', email);
    put('phone', phone);
    return m;
  }

  void dispose() {
    name.dispose();
    title.dispose();
    email.dispose();
    phone.dispose();
  }
}
