import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

class WebsiteForm extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;

  const WebsiteForm({super.key, required this.docId, required this.data});

  @override
  State<WebsiteForm> createState() => _WebsiteFormState();
}

class _WebsiteFormState extends State<WebsiteForm> {
  late final TextEditingController _nameCtl;
  late final TextEditingController _baseUrlCtl;
  late final TextEditingController _notesCtl;
  late final TextEditingController _delayCtl;
  late final TextEditingController _maxProductsCtl;
  late final TextEditingController _webstoreIdCtl;
  late final TextEditingController _communityIdCtl;
  late String _websiteType;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.data;
    final rl = e['rateLimits'] is Map
        ? Map<String, dynamic>.from(e['rateLimits'] as Map)
        : <String, dynamic>{};
    final ac = e['apiConfig'] is Map
        ? Map<String, dynamic>.from(e['apiConfig'] as Map)
        : <String, dynamic>{};
    _nameCtl = TextEditingController(text: (e['name'] ?? '').toString());
    _baseUrlCtl = TextEditingController(text: (e['baseUrl'] ?? '').toString());
    _notesCtl = TextEditingController(text: (e['notes'] ?? '').toString());
    _delayCtl = TextEditingController(text: (rl['interItemDelayMs'] ?? 3000).toString());
    _maxProductsCtl = TextEditingController(text: (rl['maxProductsPerRun'] ?? 200).toString());
    _webstoreIdCtl = TextEditingController(text: (ac['webstoreId'] ?? '').toString());
    _communityIdCtl = TextEditingController(text: (ac['communityId'] ?? '').toString());
    _websiteType = (e['websiteType'] ?? 'custom_html').toString();
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
    setState(() => _saving = true);
    try {
      final ac = <String, dynamic>{};
      if (_webstoreIdCtl.text.trim().isNotEmpty) ac['webstoreId'] = _webstoreIdCtl.text.trim();
      if (_communityIdCtl.text.trim().isNotEmpty) ac['communityId'] = _communityIdCtl.text.trim();

      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('saveBrandOwner');
      await callable.call({
        'brandOwnerId': widget.docId,
        'name': _nameCtl.text.trim(),
        'baseUrl': _baseUrlCtl.text.trim(),
        'websiteType': _websiteType,
        'rateLimits': {
          'interItemDelayMs': int.tryParse(_delayCtl.text.trim()) ?? 3000,
          'maxProductsPerRun': int.tryParse(_maxProductsCtl.text.trim()) ?? 200,
        },
        if (ac.isNotEmpty) 'apiConfig': ac,
        'notes': _notesCtl.text.trim(),
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Website updated')),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Website'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameCtl,
            decoration: const InputDecoration(labelText: 'Company Name', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _baseUrlCtl,
            decoration: const InputDecoration(labelText: 'Website URL', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _websiteType,
            decoration: const InputDecoration(labelText: 'Website Type', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'salesforce_lwr', child: Text('Salesforce LWR')),
              DropdownMenuItem(value: 'shopify', child: Text('Shopify')),
              DropdownMenuItem(value: 'woocommerce', child: Text('WooCommerce')),
              DropdownMenuItem(value: 'custom_html', child: Text('Custom HTML')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: (v) => setState(() => _websiteType = v!),
          ),
          const SizedBox(height: 16),
          const Text('Rate Limits', style: TextStyle(fontWeight: FontWeight.w600)),
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
          if (_websiteType == 'salesforce_lwr') ...[
            const SizedBox(height: 16),
            const Text('Salesforce API Config', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _webstoreIdCtl,
              decoration: const InputDecoration(labelText: 'Webstore ID', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _communityIdCtl,
              decoration: const InputDecoration(labelText: 'Community ID', border: OutlineInputBorder()),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _notesCtl,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()),
          ),
        ],
      ),
    );
  }
}
