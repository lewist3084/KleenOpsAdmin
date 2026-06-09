// lib/features/organizations/screens/organization_registry_screen.dart
//
// Overlord view of the top-level `organization` registry — the global,
// cross-company body of external organizations (vendors / merchants / email
// correspondents) maintained by the reconcileGlobalOrg Cloud Function. Lets a
// platform admin search, curate canonical fields (which locks them against
// reconciliation via `curatedFields`), run a backfill, and merge duplicates.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/tiles/standard_bubble_tile.dart';

class OrganizationRegistryScreen extends StatefulWidget {
  const OrganizationRegistryScreen({super.key});

  @override
  State<OrganizationRegistryScreen> createState() =>
      _OrganizationRegistryScreenState();
}

class _OrganizationRegistryScreenState
    extends State<OrganizationRegistryScreen> {
  final _searchCtl = TextEditingController();
  String _query = '';
  bool _backfilling = false;
  bool _migrating = false;

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _migrateVendors() async {
    final companyId = await showDialog<String>(
      context: context,
      builder: (_) => const _CompanyPickerDialog(),
    );
    if (companyId == null) return;
    setState(() => _migrating = true);
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('vendorMigrateToOrganizations');
      final res = await callable.call({'companyId': companyId});
      final data = (res.data as Map?) ?? {};
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Vendors migrated: ${data['migrated'] ?? 0} '
              '(${data['refsRepointed'] ?? 0} refs, '
              '${data['contactsStamped'] ?? 0} contacts)'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Vendor migration failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _migrating = false);
    }
  }

  Future<void> _runBackfill() async {
    setState(() => _backfilling = true);
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('organizationRegistryBackfill');
      final res = await callable.call();
      final data = (res.data as Map?) ?? {};
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Backfill complete: ${data['processed'] ?? 0} processed, '
              '${data['errors'] ?? 0} errors'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Backfill failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _backfilling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtl,
                    decoration: InputDecoration(
                      hintText: 'Search organizations…',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      border: const OutlineInputBorder(),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchCtl.clear();
                                setState(() => _query = '');
                              },
                            ),
                    ),
                    onChanged: (v) =>
                        setState(() => _query = v.trim().toLowerCase()),
                  ),
                ),
                const SizedBox(width: 8),
                _backfilling
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : IconButton(
                        tooltip: 'Reconcile all company orgs into the registry',
                        icon: const Icon(Icons.sync),
                        onPressed: _runBackfill,
                      ),
                _migrating
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : IconButton(
                        tooltip: "Migrate a company's vendors into organizations",
                        icon: const Icon(Icons.drive_file_move_outline),
                        onPressed: _migrateVendors,
                      ),
              ],
            ),
          ),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('organization')
          .orderBy('nameLower')
          .limit(500)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        var docs = snapshot.data!.docs;
        if (_query.isNotEmpty) {
          docs = docs.where((d) {
            final data = d.data();
            final name = (data['name'] ?? '').toString().toLowerCase();
            final domains =
                (data['domains'] as List?)?.join(' ').toLowerCase() ?? '';
            return name.contains(_query) || domains.contains(_query);
          }).toList();
        }
        if (docs.isEmpty) {
          return const Center(
            child: Text('No organizations in the registry yet.\n'
                'Run a backfill or let email/transactions populate it.',
                textAlign: TextAlign.center),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final name = (data['name'] ?? '').toString();
            final domains =
                (data['domains'] as List?)?.whereType<String>().toList() ??
                    const [];
            final companyCount = (data['companyCount'] as num?)?.toInt() ?? 0;
            final category = (data['category'] ?? '').toString();
            final logoUrl = (data['logoUrl'] ?? '').toString();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: StandardBubbleTile(
                title: name.isEmpty ? '(unnamed)' : name,
                description: domains.isNotEmpty ? domains.join(', ') : null,
                leadingChild: logoUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(logoUrl,
                            width: 32,
                            height: 32,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.business)),
                      )
                    : null,
                leadingIcon: logoUrl.isEmpty ? Icons.business : null,
                metaWidget: Row(
                  children: [
                    if (category.isNotEmpty)
                      _chip(category, Colors.blue),
                    if (category.isNotEmpty) const SizedBox(width: 6),
                    Text('$companyCount ${companyCount == 1 ? 'company' : 'companies'}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _showEditDialog(doc.id, data),
                ),
                onTap: () => _showEditDialog(doc.id, data),
              ),
            );
          },
        );
      },
    );
  }

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(text,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      );

  void _showEditDialog(String docId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (_) => _OrgRegistryEditDialog(docId: docId, existing: data),
    );
  }
}

/// Curate canonical fields. Saving locks the edited fields (`curatedFields`)
/// so the reconcile function won't overwrite them, and offers a merge action.
class _OrgRegistryEditDialog extends StatefulWidget {
  const _OrgRegistryEditDialog({required this.docId, required this.existing});
  final String docId;
  final Map<String, dynamic> existing;

  @override
  State<_OrgRegistryEditDialog> createState() => _OrgRegistryEditDialogState();
}

class _OrgRegistryEditDialogState extends State<_OrgRegistryEditDialog> {
  late final TextEditingController _nameCtl;
  late final TextEditingController _categoryCtl;
  late final TextEditingController _websiteCtl;
  late final TextEditingController _logoCtl;
  late final TextEditingController _primaryDomainCtl;
  late final TextEditingController _domainsCtl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtl = TextEditingController(text: (e['name'] ?? '').toString());
    _categoryCtl = TextEditingController(text: (e['category'] ?? '').toString());
    _websiteCtl = TextEditingController(text: (e['website'] ?? '').toString());
    _logoCtl = TextEditingController(text: (e['logoUrl'] ?? '').toString());
    _primaryDomainCtl =
        TextEditingController(text: (e['primaryDomain'] ?? '').toString());
    final domains =
        (e['domains'] as List?)?.whereType<String>().toList() ?? const [];
    _domainsCtl = TextEditingController(text: domains.join(', '));
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _categoryCtl.dispose();
    _websiteCtl.dispose();
    _logoCtl.dispose();
    _primaryDomainCtl.dispose();
    _domainsCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // Editing a field in the overlord curates (locks) it against reconcile.
      final curated = <String>{
        ...((widget.existing['curatedFields'] as List?)
                ?.whereType<String>() ??
            const []),
        'name',
      };
      final category = _categoryCtl.text.trim();
      final website = _websiteCtl.text.trim();
      final logo = _logoCtl.text.trim();
      final primaryDomain = _primaryDomainCtl.text.trim().toLowerCase();
      if (category.isNotEmpty) curated.add('category');
      if (website.isNotEmpty) curated.add('website');
      if (logo.isNotEmpty) curated.add('logoUrl');

      final domains = _domainsCtl.text
          .split(',')
          .map((s) => s.trim().toLowerCase())
          .where((s) => s.isNotEmpty)
          .toList();

      await FirebaseFirestore.instance
          .collection('organization')
          .doc(widget.docId)
          .set({
        'name': name,
        'nameLower': name.toLowerCase(),
        'category': category,
        'website': website,
        'logoUrl': logo,
        'primaryDomain': primaryDomain,
        'domains': domains,
        'curatedFields': curated.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Organization updated')));
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _merge() async {
    final survivorId = await showDialog<String>(
      context: context,
      builder: (_) => _MergePickerDialog(excludeId: widget.docId),
    );
    if (survivorId == null) return;
    setState(() => _saving = true);
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('organizationRegistryMerge');
      // This org is the duplicate; the chosen org survives.
      final res = await callable
          .call({'survivorId': survivorId, 'dupeId': widget.docId});
      final data = (res.data as Map?) ?? {};
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Merged. Repointed ${data['repointed'] ?? 0} companies.')));
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final companyCount =
        (widget.existing['companyCount'] as num?)?.toInt() ?? 0;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Edit Organization',
                  style:
                      TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('$companyCount linked ${companyCount == 1 ? 'company' : 'companies'} · '
                  'edits lock fields against auto-reconcile',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 20),
              _field(_nameCtl, 'Name *', Icons.business),
              const SizedBox(height: 12),
              _field(_categoryCtl, 'Category', Icons.category_outlined,
                  hint: 'Supplier / SaaS / Utility / Fuel…'),
              const SizedBox(height: 12),
              _field(_primaryDomainCtl, 'Primary domain', Icons.language,
                  hint: 'acme.com'),
              const SizedBox(height: 12),
              _field(_domainsCtl, 'Domains (comma-separated)', Icons.dns_outlined),
              const SizedBox(height: 12),
              _field(_websiteCtl, 'Website', Icons.link),
              const SizedBox(height: 12),
              _field(_logoCtl, 'Logo URL', Icons.image_outlined),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.merge_type, size: 18),
                    label: const Text('Merge into…'),
                    onPressed: _saving ? null : _merge,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon,
          {String? hint}) =>
      TextField(
        controller: c,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          prefixIcon: Icon(icon),
        ),
      );
}

/// Pick a company to run the vendor → organization migration against.
class _CompanyPickerDialog extends StatefulWidget {
  const _CompanyPickerDialog();

  @override
  State<_CompanyPickerDialog> createState() => _CompanyPickerDialogState();
}

class _CompanyPickerDialogState extends State<_CompanyPickerDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text('Migrate which company’s vendors?',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search companies…',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) =>
                    setState(() => _query = v.trim().toLowerCase()),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('company')
                    .orderBy('name')
                    .limit(500)
                    .snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  var docs = snap.data!.docs;
                  if (_query.isNotEmpty) {
                    docs = docs
                        .where((d) => (d.data()['name'] ?? '')
                            .toString()
                            .toLowerCase()
                            .contains(_query))
                        .toList();
                  }
                  return ListView(
                    children: docs
                        .map((d) => ListTile(
                              leading: const Icon(Icons.business),
                              title: Text((d.data()['name'] ?? d.id).toString()),
                              onTap: () => Navigator.pop(context, d.id),
                            ))
                        .toList(),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pick the surviving organization to merge the current (duplicate) into.
class _MergePickerDialog extends StatefulWidget {
  const _MergePickerDialog({required this.excludeId});
  final String excludeId;

  @override
  State<_MergePickerDialog> createState() => _MergePickerDialogState();
}

class _MergePickerDialogState extends State<_MergePickerDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text('Merge into which organization?',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search…',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) =>
                    setState(() => _query = v.trim().toLowerCase()),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('organization')
                    .orderBy('nameLower')
                    .limit(500)
                    .snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  var docs = snap.data!.docs
                      .where((d) => d.id != widget.excludeId)
                      .toList();
                  if (_query.isNotEmpty) {
                    docs = docs
                        .where((d) => (d.data()['name'] ?? '')
                            .toString()
                            .toLowerCase()
                            .contains(_query))
                        .toList();
                  }
                  return ListView(
                    children: docs
                        .map((d) => ListTile(
                              leading: const Icon(Icons.business),
                              title: Text((d.data()['name'] ?? '').toString()),
                              subtitle: Text(((d.data()['domains'] as List?)
                                          ?.join(', ') ??
                                      '')
                                  .toString()),
                              onTap: () => Navigator.pop(context, d.id),
                            ))
                        .toList(),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
