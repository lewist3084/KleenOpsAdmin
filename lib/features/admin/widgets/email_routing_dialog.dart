import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import '../services/email_routing_service.dart';
import '../services/domain_provisioning_service.dart';
import '../services/setup_wizard_service.dart';

/// Dialog for the "Set Up Business Email" wizard step.
///
/// Requires a domain to be registered first. Creates email routing
/// rules (e.g. info@domain.com → personal email) and sets up
/// SendGrid for outbound sending.
class EmailRoutingDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> itemData;

  const EmailRoutingDialog({super.key, required this.itemData});

  @override
  ConsumerState<EmailRoutingDialog> createState() => _EmailRoutingDialogState();
}

class _EmailRoutingDialogState extends ConsumerState<EmailRoutingDialog> {
  final _emailService = EmailRoutingService.instance;
  final _domainService = DomainProvisioningService.instance;
  final _wizardService = SetupWizardService.instance;

  final _localPartCtrl = TextEditingController(text: 'info');
  final _forwardToCtrl = TextEditingController();

  _EmailStep _step = _EmailStep.loading;
  bool _creating = false;
  bool _settingUpSendGrid = false;
  String? _error;

  // Domain state
  List<Map<String, dynamic>> _domains = [];
  Map<String, dynamic>? _selectedDomain;

  // Existing routes
  List<Map<String, dynamic>> _existingRoutes = [];

  // SMTP credentials (shown after generation)
  Map<String, dynamic>? _smtpCredentials;
  bool _generatingSmtp = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _localPartCtrl.dispose();
    _forwardToCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final companyRef = ref.read(companyIdProvider).asData?.value;
    if (companyRef == null) {
      setState(() => _step = _EmailStep.noDomain);
      return;
    }

    try {
      final domains = await _domainService.listProvisioned(
        companyId: companyRef.id,
      );
      final routes = await _emailService.listRoutes(
        companyId: companyRef.id,
      );

      if (mounted) {
        setState(() {
          _domains = domains;
          _existingRoutes = routes;
          if (domains.isEmpty) {
            _step = _EmailStep.noDomain;
          } else if (routes.isNotEmpty) {
            _step = _EmailStep.done;
          } else {
            _selectedDomain = domains.first;
            _step = _EmailStep.configure;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _step = _EmailStep.noDomain;
          _error = 'Failed to load domain data.';
        });
      }
    }
  }

  Future<void> _createRoute() async {
    final companyRef = ref.read(companyIdProvider).asData?.value;
    if (companyRef == null || _selectedDomain == null) return;

    final localPart = _localPartCtrl.text.trim();
    final forwardTo = _forwardToCtrl.text.trim();
    if (localPart.isEmpty || forwardTo.isEmpty) {
      setState(() => _error = 'Both fields are required.');
      return;
    }

    setState(() {
      _creating = true;
      _error = null;
    });

    try {
      // Enable routing if not already enabled
      final domainDocId = _selectedDomain!['id'] as String;
      if (_selectedDomain!['emailRoutingEnabled'] != true) {
        await _emailService.enableRouting(
          companyId: companyRef.id,
          domainDocId: domainDocId,
        );
      }

      // Create the route
      final result = await _emailService.createRoute(
        companyId: companyRef.id,
        domainDocId: domainDocId,
        fromAddress: localPart,
        toAddress: forwardTo,
        label: localPart,
      );

      _existingRoutes.add(result);

      // Set up SendGrid outbound + inbound if not done
      if (_selectedDomain!['sendgridDomainId'] == null) {
        setState(() {
          _creating = false;
          _settingUpSendGrid = true;
        });
        try {
          // Outbound: verify domain in SendGrid for sending
          await _emailService.verifySendDomain(
            companyId: companyRef.id,
            domainDocId: domainDocId,
          );
          // Inbound: set up SendGrid Inbound Parse to capture emails in the app
          await _emailService.setupInboundParse(
            companyId: companyRef.id,
            domainDocId: domainDocId,
          );
        } catch (e) {
          // Non-fatal — can be set up later
          debugPrint('SendGrid setup deferred: $e');
        }
        if (mounted) setState(() => _settingUpSendGrid = false);
      }

      // Mark wizard step complete
      await _wizardService.completeItem('business_email', data: {
        'primaryEmail': result['address'],
        'forwardTo': forwardTo,
        'domainName': _selectedDomain!['domainName'],
      });

      if (mounted) {
        setState(() {
          _creating = false;
          _step = _EmailStep.done;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _creating = false;
          _error = 'Failed to create email route. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.email_outlined, color: Theme.of(context).primaryColor),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Set Up Business Email', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: switch (_step) {
            _EmailStep.loading => const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              ),
            _EmailStep.noDomain => _buildNoDomainStep(),
            _EmailStep.configure => _buildConfigureStep(),
            _EmailStep.done => _buildDoneStep(),
          },
        ),
      ),
      actions: switch (_step) {
        _EmailStep.loading => [],
        _EmailStep.noDomain => [
          TextButton(
            onPressed: () {
              _wizardService.skipItem('business_email');
              Navigator.pop(context);
            },
            child: const Text('Skip'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
        _EmailStep.configure => [
          TextButton(
            onPressed: () {
              _wizardService.skipItem('business_email');
              Navigator.pop(context);
            },
            child: const Text('Skip'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: (_creating || _settingUpSendGrid) ? null : _createRoute,
            child: (_creating || _settingUpSendGrid)
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create Email'),
          ),
        ],
        _EmailStep.done => [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      },
    );
  }

  // ── No domain step ────────────────────────────────────────────

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
          'You need to register a domain first before setting up email. '
          'Complete the "Set Up a Website / Domain" step, then come back here.',
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
          textAlign: TextAlign.center,
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: Colors.red[700], fontSize: 13)),
        ],
      ],
    );
  }

  // ── Configure step ────────────────────────────────────────────

  Widget _buildConfigureStep() {
    final domainName =
        _selectedDomain?['domainName'] as String? ?? 'yourdomain.com';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Create email addresses on your domain',
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),

        // Domain selector (if multiple)
        if (_domains.length > 1) ...[
          const SizedBox(height: 16),
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
        ],

        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _localPartCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email Prefix',
                  hintText: 'info',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                ' @$domainName',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: ['info', 'admin', 'support', 'hello'].map((prefix) {
            return ActionChip(
              label: Text(prefix),
              onPressed: () => setState(() => _localPartCtrl.text = prefix),
            );
          }).toList(),
        ),

        const SizedBox(height: 16),
        TextField(
          controller: _forwardToCtrl,
          decoration: const InputDecoration(
            labelText: 'Forward To',
            hintText: 'your.personal@gmail.com',
            helperText: 'Emails will be forwarded to this address.',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.emailAddress,
        ),

        if (_settingUpSendGrid) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(
                'Setting up outbound sending...',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
          ),
        ],

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
                  'Incoming emails will be forwarded to your personal address. '
                  'Outbound sending is configured automatically via SendGrid. '
                  'No additional cost for email routing.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── SMTP key generation ─────────────────────────────────────

  Future<void> _generateSmtpKey() async {
    final companyRef = ref.read(companyIdProvider).asData?.value;
    if (companyRef == null || _selectedDomain == null) return;

    setState(() => _generatingSmtp = true);

    try {
      final result = await _emailService.createSmtpKey(
        companyId: companyRef.id,
        domainDocId: _selectedDomain!['id'] as String,
      );
      if (mounted) {
        setState(() {
          _smtpCredentials = result;
          _generatingSmtp = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _generatingSmtp = false);
      }
    }
  }

  // ── Done step ─────────────────────────────────────────────────

  Widget _buildDoneStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Success header
        Row(
          children: [
            Icon(Icons.check_circle, size: 32, color: Colors.green[400]),
            const SizedBox(width: 12),
            const Text(
              'Business Email Ready',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Active routes
        if (_existingRoutes.isNotEmpty)
          ...(_existingRoutes.map((r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  dense: true,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  leading: const Icon(Icons.email, color: Colors.green),
                  title: Text(
                    r['address'] as String? ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text('Forwards to ${r['forwardTo'] ?? ''}'),
                ),
              ))),

        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 16),

        // Outbound sending setup
        const Text(
          'Send Email As Your Business',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          'To reply to emails as your business address (instead of your personal email), '
          'add it as a "Send mail as" account in Gmail or Outlook.',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        const SizedBox(height: 12),

        if (_smtpCredentials == null) ...[
          // Generate button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _generatingSmtp ? null : _generateSmtpKey,
              icon: _generatingSmtp
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.key),
              label: Text(_generatingSmtp
                  ? 'Generating...'
                  : 'Generate Outbound Email Credentials'),
            ),
          ),
        ] else ...[
          // SMTP credentials card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blueGrey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SMTP Settings',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 12),
                _SmtpRow(label: 'Server', value: 'smtp.sendgrid.net'),
                _SmtpRow(label: 'Port', value: '587'),
                _SmtpRow(label: 'Username', value: 'apikey'),
                if (_smtpCredentials!['password'] != null)
                  _SmtpRow(
                    label: 'Password',
                    value: _smtpCredentials!['password'] as String,
                    sensitive: true,
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'Password was already generated. If lost, generate a new one.',
                      style: TextStyle(color: Colors.orange[700], fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          if (_smtpCredentials!['password'] != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, size: 16, color: Colors.amber[800]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Save this password now. It will not be shown again.',
                      style: TextStyle(fontSize: 12, color: Colors.amber[900], fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],

        const SizedBox(height: 16),

        // Setup instructions
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gmail Setup',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey[700]),
              ),
              const SizedBox(height: 6),
              Text(
                '1. Open Gmail Settings (gear icon)\n'
                '2. Go to "Accounts and Import"\n'
                '3. Click "Add another email address" under "Send mail as"\n'
                '4. Enter your business email address\n'
                '5. Uncheck "Treat as an alias"\n'
                '6. Enter the SMTP settings above\n'
                '7. Verify with the confirmation code Gmail sends',
                style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.5),
              ),
              const SizedBox(height: 10),
              Text(
                'Outlook Setup',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey[700]),
              ),
              const SizedBox(height: 6),
              Text(
                '1. Go to Settings > Mail > Sync email\n'
                '2. Under "Send email from", click "Add another email address"\n'
                '3. Enter your business email and the SMTP settings above',
                style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _EmailStep { loading, noDomain, configure, done }

class _SmtpRow extends StatelessWidget {
  final String label;
  final String value;
  final bool sensitive;

  const _SmtpRow({
    required this.label,
    required this.value,
    this.sensitive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                color: sensitive ? Colors.deepOrange[700] : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
