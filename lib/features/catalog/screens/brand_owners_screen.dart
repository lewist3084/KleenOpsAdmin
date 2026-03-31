import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

class BrandOwnersScreen extends StatelessWidget {
  const BrandOwnersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('brandOwner')
            .orderBy('name')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No brand owners yet. Tap + to add one.'));
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final name = (data['name'] ?? '').toString();
              final baseUrl = (data['baseUrl'] ?? '').toString();
              final websiteType = (data['websiteType'] ?? 'unknown').toString();
              final lastScraped = data['lastScrapedAt'];

              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.business)),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (baseUrl.isNotEmpty)
                        Text(baseUrl, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(websiteType, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                          if (lastScraped != null) ...[
                            const SizedBox(width: 8),
                            Text('Last scraped: ${_formatTimestamp(lastScraped)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ],
                      ),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _showEditDialog(context, doc.id, data),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(context, null, null),
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatTimestamp(dynamic ts) {
    if (ts is Timestamp) {
      final dt = ts.toDate();
      return '${dt.month}/${dt.day}/${dt.year}';
    }
    return '';
  }

  void _showEditDialog(BuildContext context, String? docId, Map<String, dynamic>? existing) {
    showDialog(
      context: context,
      builder: (ctx) => _BrandOwnerEditDialog(docId: docId, existing: existing),
    );
  }
}

class _BrandOwnerEditDialog extends StatefulWidget {
  final String? docId;
  final Map<String, dynamic>? existing;

  const _BrandOwnerEditDialog({this.docId, this.existing});

  @override
  State<_BrandOwnerEditDialog> createState() => _BrandOwnerEditDialogState();
}

class _BrandOwnerEditDialogState extends State<_BrandOwnerEditDialog> {
  late final TextEditingController _nameCtl;
  late final TextEditingController _baseUrlCtl;
  late final TextEditingController _notesCtl;
  late final TextEditingController _delayCtl;
  late final TextEditingController _maxProductsCtl;
  late final TextEditingController _webstoreIdCtl;
  late final TextEditingController _communityIdCtl;
  String _websiteType = 'salesforce_lwr';
  bool _saving = false;
  String? _error;

  static const _websiteTypes = [
    'salesforce_lwr',
    'shopify',
    'woocommerce',
    'custom_html',
    'other',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing ?? {};
    final rateLimits = e['rateLimits'] is Map ? Map<String, dynamic>.from(e['rateLimits'] as Map) : <String, dynamic>{};
    final apiConfig = e['apiConfig'] is Map ? Map<String, dynamic>.from(e['apiConfig'] as Map) : <String, dynamic>{};

    _nameCtl = TextEditingController(text: (e['name'] ?? '').toString());
    _baseUrlCtl = TextEditingController(text: (e['baseUrl'] ?? '').toString());
    _notesCtl = TextEditingController(text: (e['notes'] ?? '').toString());
    _delayCtl = TextEditingController(text: (rateLimits['interItemDelayMs'] ?? 3000).toString());
    _maxProductsCtl = TextEditingController(text: (rateLimits['maxProductsPerRun'] ?? 200).toString());
    _webstoreIdCtl = TextEditingController(text: (apiConfig['webstoreId'] ?? '').toString());
    _communityIdCtl = TextEditingController(text: (apiConfig['communityId'] ?? '').toString());
    _websiteType = (e['websiteType'] ?? 'salesforce_lwr').toString();
    if (!_websiteTypes.contains(_websiteType)) _websiteType = 'other';
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _baseUrlCtl.dispose();
    _notesCtl.dispose();
    _delayCtl.dispose();
    _maxProductsCtl.dispose();
    _webstoreIdCtl.dispose();
    _communityIdCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }

    setState(() { _saving = true; _error = null; });

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('saveBrandOwner');

      final Map<String, dynamic> apiConfig = {};
      if (_webstoreIdCtl.text.trim().isNotEmpty) apiConfig['webstoreId'] = _webstoreIdCtl.text.trim();
      if (_communityIdCtl.text.trim().isNotEmpty) apiConfig['communityId'] = _communityIdCtl.text.trim();

      await callable.call({
        if (widget.docId != null) 'brandOwnerId': widget.docId,
        'name': name,
        'baseUrl': _baseUrlCtl.text.trim(),
        'websiteType': _websiteType,
        'rateLimits': {
          'interItemDelayMs': int.tryParse(_delayCtl.text.trim()) ?? 3000,
          'maxProductsPerRun': int.tryParse(_maxProductsCtl.text.trim()) ?? 200,
        },
        if (apiConfig.isNotEmpty) 'apiConfig': apiConfig,
        'notes': _notesCtl.text.trim(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.docId != null ? 'Brand owner updated' : 'Brand owner created')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.docId != null;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(isEdit ? 'Edit Brand Owner' : 'New Brand Owner',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              TextField(
                controller: _nameCtl,
                decoration: const InputDecoration(
                  labelText: 'Company Name *',
                  hintText: 'e.g., Solenis',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _baseUrlCtl,
                decoration: const InputDecoration(
                  labelText: 'Website Base URL',
                  hintText: 'https://products.solenis.com',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.language),
                ),
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: _websiteType,
                decoration: const InputDecoration(
                  labelText: 'Website Type',
                  border: OutlineInputBorder(),
                ),
                items: _websiteTypes.map((t) => DropdownMenuItem(
                  value: t,
                  child: Text(t),
                )).toList(),
                onChanged: (v) => setState(() => _websiteType = v!),
              ),
              const SizedBox(height: 16),

              // Rate limits
              const Text('Rate Limits', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _delayCtl,
                      decoration: const InputDecoration(
                        labelText: 'Delay (ms)',
                        helperText: 'Between products',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _maxProductsCtl,
                      decoration: const InputDecoration(
                        labelText: 'Max Products',
                        helperText: 'Per scrape run',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // API Config (for Salesforce sites)
              if (_websiteType == 'salesforce_lwr') ...[
                const Text('Salesforce API Config', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: _webstoreIdCtl,
                  decoration: const InputDecoration(
                    labelText: 'Webstore ID',
                    hintText: '0ZEUX...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _communityIdCtl,
                  decoration: const InputDecoration(
                    labelText: 'Community ID',
                    hintText: '0DBUX...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              TextField(
                controller: _notesCtl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],

              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(isEdit ? 'Update' : 'Create'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
