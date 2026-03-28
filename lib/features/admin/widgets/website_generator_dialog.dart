import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/website_service.dart';
import '../services/domain_provisioning_service.dart';
import '../services/setup_wizard_service.dart';

/// Dialog for the "Set Up a Website / Domain" wizard step.
///
/// If a domain is already registered, offers to generate and deploy
/// a landing page website to Cloudflare Pages.
class WebsiteGeneratorDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> itemData;

  const WebsiteGeneratorDialog({super.key, required this.itemData});

  @override
  ConsumerState<WebsiteGeneratorDialog> createState() =>
      _WebsiteGeneratorDialogState();
}

class _WebsiteGeneratorDialogState
    extends ConsumerState<WebsiteGeneratorDialog> {
  final _websiteService = WebsiteService.instance;
  final _domainService = DomainProvisioningService.instance;
  final _wizardService = SetupWizardService.instance;

  final _primaryColorCtrl = TextEditingController(text: '#2563eb');
  final _aboutCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController(text: 'Monday - Friday, 8am - 6pm');

  _WebsiteStep _step = _WebsiteStep.loading;
  bool _deploying = false;
  String? _error;

  List<Map<String, dynamic>> _domains = [];
  Map<String, dynamic>? _selectedDomain;
  Map<String, dynamic>? _deployResult;
  Map<String, dynamic>? _existingWebsite;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _primaryColorCtrl.dispose();
    _aboutCtrl.dispose();
    _hoursCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final companyRef = ref.read(companyIdProvider).asData?.value;
    if (companyRef == null) {
      setState(() => _step = _WebsiteStep.noDomain);
      return;
    }

    try {
      final domains = await _domainService.listProvisioned(
        companyId: companyRef.id,
      );
      final status = await _websiteService.getStatus(
        companyId: companyRef.id,
      );

      if (mounted) {
        setState(() {
          _domains = domains;
          if (status['deployed'] == true) {
            _existingWebsite = status;
            _step = _WebsiteStep.done;
          } else if (domains.isEmpty) {
            _step = _WebsiteStep.noDomain;
          } else {
            _selectedDomain = domains.first;
            _step = _WebsiteStep.configure;
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _step = _WebsiteStep.noDomain);
    }
  }

  Future<void> _deploy() async {
    final companyRef = ref.read(companyIdProvider).asData?.value;
    if (companyRef == null) return;

    setState(() {
      _deploying = true;
      _error = null;
    });

    try {
      final result = await _websiteService.generateAndDeploy(
        companyId: companyRef.id,
        domainDocId: _selectedDomain?['id'] as String?,
        options: {
          'primaryColor': _primaryColorCtrl.text.trim().isNotEmpty
              ? _primaryColorCtrl.text.trim()
              : '#2563eb',
          'aboutText': _aboutCtrl.text.trim().isNotEmpty
              ? _aboutCtrl.text.trim()
              : null,
          'businessHours': _hoursCtrl.text.trim().isNotEmpty
              ? _hoursCtrl.text.trim()
              : null,
        },
      );

      await _wizardService.completeItem('business_website', data: {
        'websiteUrl': result['customDomain'] ?? result['deploymentUrl'],
        'pagesDevUrl': result['pagesDevUrl'],
        'projectName': result['projectName'],
      });

      if (mounted) {
        setState(() {
          _deploying = false;
          _deployResult = result;
          _step = _WebsiteStep.done;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _deploying = false;
          _error = 'Deployment failed. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_step == _WebsiteStep.loading) {
      return const AlertDialog(
        content: SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.language, color: Theme.of(context).primaryColor),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Generate Your Website', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: switch (_step) {
            _WebsiteStep.loading => const SizedBox.shrink(),
            _WebsiteStep.noDomain => _buildNoDomainStep(),
            _WebsiteStep.configure => _buildConfigureStep(),
            _WebsiteStep.done => _buildDoneStep(),
          },
        ),
      ),
      actions: switch (_step) {
        _WebsiteStep.loading => [],
        _WebsiteStep.noDomain => [
          TextButton(
            onPressed: () {
              _wizardService.skipItem('business_website');
              Navigator.pop(context);
            },
            child: const Text('Skip'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
        _WebsiteStep.configure => [
          TextButton(
            onPressed: () {
              _wizardService.skipItem('business_website');
              Navigator.pop(context);
            },
            child: const Text('Skip'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _deploying ? null : _deploy,
            child: _deploying
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Generate & Deploy'),
          ),
        ],
        _WebsiteStep.done => [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      },
    );
  }

  Widget _buildNoDomainStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.domain_disabled, size: 48, color: Colors.grey[400]),
        const SizedBox(height: 16),
        const Text(
          'Domain Required',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          'Register a domain first, then come back here to generate your website.',
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildConfigureStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'We\'ll generate a professional landing page from your business info. '
          'You can customize a few things below.',
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
        const SizedBox(height: 20),

        // Domain selector
        if (_domains.length > 1) ...[
          DropdownButtonFormField<Map<String, dynamic>>(
            initialValue: _selectedDomain,
            decoration: const InputDecoration(
              labelText: 'Domain',
              border: OutlineInputBorder(),
            ),
            items: _domains
                .map((d) => DropdownMenuItem(
                      value: d,
                      child: Text(d['domainName'] as String? ?? ''),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _selectedDomain = v),
          ),
          const SizedBox(height: 16),
        ] else if (_selectedDomain != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.language, color: Theme.of(context).primaryColor),
                const SizedBox(width: 10),
                Text(
                  _selectedDomain!['domainName'] as String? ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Brand color
        TextField(
          controller: _primaryColorCtrl,
          decoration: const InputDecoration(
            labelText: 'Brand Color',
            hintText: '#2563eb',
            helperText: 'Hex color code for buttons and accents.',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),

        // About text
        TextField(
          controller: _aboutCtrl,
          decoration: const InputDecoration(
            labelText: 'About Your Business (optional)',
            hintText: 'Tell customers what makes you different...',
            border: OutlineInputBorder(),
          ),
          minLines: 2,
          maxLines: 4,
        ),
        const SizedBox(height: 16),

        // Business hours
        TextField(
          controller: _hoursCtrl,
          decoration: const InputDecoration(
            labelText: 'Business Hours',
            hintText: 'Monday - Friday, 8am - 6pm',
            border: OutlineInputBorder(),
          ),
        ),

        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: Colors.red[700], fontSize: 13)),
        ],

        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 18, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your website is generated from the business info in your setup wizard '
                  '(name, logo, phone, email, address). You can update it anytime by '
                  're-deploying. Hosting is free via Cloudflare Pages.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDoneStep() {
    final websiteUrl = _deployResult?['customDomain'] ??
        _existingWebsite?['customDomain'] ??
        _deployResult?['pagesDevUrl'] ??
        _existingWebsite?['deploymentUrl'] ??
        '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_circle, size: 64, color: Colors.green[400]),
        const SizedBox(height: 16),
        const Text(
          'Website Live',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        if (websiteUrl.toString().isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                const Icon(Icons.language, size: 32, color: Colors.green),
                const SizedBox(height: 8),
                SelectableText(
                  websiteUrl.toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final url = websiteUrl.toString().startsWith('http')
                          ? websiteUrl.toString()
                          : 'https://$websiteUrl';
                      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                    },
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Visit Your Website'),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          'Your website is live and hosted for free. You can re-deploy '
          'anytime to update the content.',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

enum _WebsiteStep { loading, noDomain, configure, done }
