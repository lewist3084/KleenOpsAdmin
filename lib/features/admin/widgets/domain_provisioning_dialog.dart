import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import '../services/domain_provisioning_service.dart';
import '../services/setup_wizard_service.dart';

/// Dialog for the "Set Up a Website / Domain" wizard step.
///
/// Allows the user to search for domain availability, view suggestions,
/// and register a domain via Cloudflare.
class DomainProvisioningDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> itemData;

  const DomainProvisioningDialog({super.key, required this.itemData});

  @override
  ConsumerState<DomainProvisioningDialog> createState() =>
      _DomainProvisioningDialogState();
}

class _DomainProvisioningDialogState
    extends ConsumerState<DomainProvisioningDialog> {
  final _domainService = DomainProvisioningService.instance;
  final _wizardService = SetupWizardService.instance;

  final _domainCtrl = TextEditingController();

  _DomainStep _step = _DomainStep.search;
  bool _checking = false;
  bool _registering = false;
  String? _error;

  // Availability result
  bool? _available;
  String? _checkedDomain;
  String? _price;
  List<Map<String, dynamic>> _suggestions = [];

  // Existing domains
  List<Map<String, dynamic>> _existingDomains = [];
  bool _loadingExisting = true;

  @override
  void initState() {
    super.initState();
    _loadExistingDomains();
  }

  @override
  void dispose() {
    _domainCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExistingDomains() async {
    final companyRef = ref.read(companyIdProvider).asData?.value;
    if (companyRef == null) {
      setState(() => _loadingExisting = false);
      return;
    }

    try {
      final domains = await _domainService.listProvisioned(
        companyId: companyRef.id,
      );
      if (mounted) {
        setState(() {
          _existingDomains = domains;
          _loadingExisting = false;
          if (domains.isNotEmpty) _step = _DomainStep.done;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingExisting = false);
    }
  }

  Future<void> _checkAvailability() async {
    final companyRef = ref.read(companyIdProvider).asData?.value;
    if (companyRef == null) return;

    final raw = _domainCtrl.text.trim();
    if (raw.isEmpty) return;

    // Ensure it has a TLD
    final domain = raw.contains('.') ? raw : '$raw.com';

    setState(() {
      _checking = true;
      _error = null;
      _available = null;
      _suggestions = [];
    });

    try {
      final result = await _domainService.checkAvailability(
        companyId: companyRef.id,
        domainName: domain,
      );
      if (mounted) {
        setState(() {
          _checking = false;
          _checkedDomain = result['domain'] as String? ?? domain;
          _available = result['available'] as bool? ?? false;
          _price = result['price']?.toString();
          _suggestions = ((result['suggestions'] as List?) ?? [])
              .cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _checking = false;
          _error = 'Availability check failed. Please try again.';
        });
      }
    }
  }

  Future<void> _register(String domain) async {
    final companyRef = ref.read(companyIdProvider).asData?.value;
    if (companyRef == null) return;

    setState(() {
      _registering = true;
      _error = null;
    });

    try {
      // Fetch company data to use as the domain registrant (legal owner)
      final companySnap = await companyRef.get();
      final companyData = companySnap.data() ?? {};

      await _domainService.register(
        companyId: companyRef.id,
        domainName: domain,
        registrant: {
          'organization': companyData['name'] ?? '',
          'firstName': companyData['ownerFirstName'] ?? companyData['contactFirstName'] ?? '',
          'lastName': companyData['ownerLastName'] ?? companyData['contactLastName'] ?? '',
          'email': companyData['email'] ?? companyData['contactEmail'] ?? '',
          'phone': companyData['phone'] ?? companyData['contactPhone'] ?? '',
          'address1': companyData['address'] ?? companyData['streetAddress'] ?? '',
          'city': companyData['city'] ?? '',
          'state': companyData['state'] ?? '',
          'zip': companyData['zip'] ?? companyData['postalCode'] ?? '',
          'country': companyData['country'] ?? 'US',
        },
      );

      await _wizardService.completeItem('business_website', data: {
        'domainName': domain,
        'registrar': 'cloudflare',
        'registeredVia': 'automated',
        'registrantIsCustomer': true,
      });

      if (mounted) {
        setState(() {
          _registering = false;
          _step = _DomainStep.done;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _registering = false;
          _error = e.toString().contains('already-exists')
              ? 'This domain is already registered for your company.'
              : 'Registration failed. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingExisting) {
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
            child: Text('Register a Domain', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: switch (_step) {
            _DomainStep.search => _buildSearchStep(),
            _DomainStep.done => _buildDoneStep(),
          },
        ),
      ),
      actions: switch (_step) {
        _DomainStep.search => [
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
        ],
        _DomainStep.done => [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      },
    );
  }

  // ── Search step ───────────────────────────────────────────────

  Widget _buildSearchStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enter a domain name to check availability',
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _domainCtrl,
                decoration: const InputDecoration(
                  labelText: 'Domain Name',
                  hintText: 'acmecleaning.com',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _checkAvailability(),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: _checking ? null : _checkAvailability,
              child: _checking
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Check'),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: Colors.red[700], fontSize: 13)),
        ],

        // Availability result
        if (_available != null && _checkedDomain != null) ...[
          const SizedBox(height: 20),
          _DomainResultTile(
            domain: _checkedDomain!,
            available: _available!,
            price: _price,
            registering: _registering,
            onRegister: _available! ? () => _register(_checkedDomain!) : null,
          ),
        ],

        // Suggestions
        if (_suggestions.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Also available:',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 8),
          for (final suggestion in _suggestions)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _DomainResultTile(
                domain: suggestion['domain'] as String? ?? '',
                available: true,
                price: suggestion['price']?.toString(),
                registering: _registering,
                onRegister: () =>
                    _register(suggestion['domain'] as String? ?? ''),
              ),
            ),
        ],

        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.verified_user, size: 18, color: Colors.green[700]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'You are the legal owner of this domain. It is registered '
                  'under your business name and contact information. You can '
                  'transfer it to any registrar at any time if you ever leave KleenOps.',
                  style: TextStyle(fontSize: 12, color: Colors.green[800]),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
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
                  'Domains are registered at wholesale prices '
                  '(typically \$10-15/year). DNS is managed automatically.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Done step ─────────────────────────────────────────────────

  Widget _buildDoneStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_circle, size: 64, color: Colors.green[400]),
        const SizedBox(height: 16),
        const Text(
          'Domain Registered',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (_existingDomains.isNotEmpty)
          ...(_existingDomains.map((d) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  dense: true,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  leading: const Icon(Icons.language, color: Colors.green),
                  title: Text(
                    d['domainName'] as String? ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(d['status'] as String? ?? 'active'),
                ),
              )))
        else
          Text(
            'Your domain has been registered and is ready for use.',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
      ],
    );
  }
}

// ── Domain result tile ──────────────────────────────────────────

class _DomainResultTile extends StatelessWidget {
  final String domain;
  final bool available;
  final String? price;
  final bool registering;
  final VoidCallback? onRegister;

  const _DomainResultTile({
    required this.domain,
    required this.available,
    this.price,
    required this.registering,
    this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: available ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: available ? Colors.green.shade200 : Colors.red.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            available ? Icons.check_circle : Icons.cancel,
            color: available ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  domain,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                if (price != null)
                  Text(
                    '\$$price/year',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
              ],
            ),
          ),
          if (available && onRegister != null)
            FilledButton(
              onPressed: registering ? null : onRegister,
              child: registering
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Register'),
            ),
          if (!available)
            Text('Taken', style: TextStyle(color: Colors.red[700], fontSize: 13)),
        ],
      ),
    );
  }
}

enum _DomainStep { search, done }
