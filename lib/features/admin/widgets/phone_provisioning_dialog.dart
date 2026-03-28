import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import '../services/phone_provisioning_service.dart';
import '../services/setup_wizard_service.dart';

/// Dialog for the "Get a Business Phone Number" wizard step.
///
/// Allows the user to search for available numbers by area code,
/// preview results, provision a number, and configure call forwarding.
class PhoneProvisioningDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> itemData;

  const PhoneProvisioningDialog({super.key, required this.itemData});

  @override
  ConsumerState<PhoneProvisioningDialog> createState() =>
      _PhoneProvisioningDialogState();
}

class _PhoneProvisioningDialogState
    extends ConsumerState<PhoneProvisioningDialog> {
  final _phoneService = PhoneProvisioningService.instance;
  final _wizardService = SetupWizardService.instance;

  final _areaCodeCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _forwardToCtrl = TextEditingController();
  final _labelCtrl = TextEditingController(text: 'Business Line');

  List<Map<String, dynamic>> _searchResults = [];
  Map<String, dynamic>? _selectedNumber;
  bool _searching = false;
  bool _provisioning = false;
  String? _error;
  _DialogStep _step = _DialogStep.search;

  // If already provisioned, show current number
  List<Map<String, dynamic>> _existingNumbers = [];
  bool _loadingExisting = true;

  @override
  void initState() {
    super.initState();
    _loadExistingNumbers();
  }

  @override
  void dispose() {
    _areaCodeCtrl.dispose();
    _stateCtrl.dispose();
    _forwardToCtrl.dispose();
    _labelCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExistingNumbers() async {
    final companyRef = ref.read(companyIdProvider).asData?.value;
    if (companyRef == null) {
      setState(() => _loadingExisting = false);
      return;
    }

    try {
      final numbers = await _phoneService.listProvisioned(
        companyId: companyRef.id,
      );
      if (mounted) {
        setState(() {
          _existingNumbers = numbers;
          _loadingExisting = false;
          if (numbers.isNotEmpty) _step = _DialogStep.done;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingExisting = false);
    }
  }

  Future<void> _search() async {
    final companyRef = ref.read(companyIdProvider).asData?.value;
    if (companyRef == null) return;

    setState(() {
      _searching = true;
      _error = null;
      _searchResults = [];
      _selectedNumber = null;
    });

    try {
      final results = await _phoneService.searchAvailable(
        companyId: companyRef.id,
        areaCode:
            _areaCodeCtrl.text.trim().isNotEmpty ? _areaCodeCtrl.text.trim() : null,
        state: _stateCtrl.text.trim().isNotEmpty ? _stateCtrl.text.trim() : null,
      );
      if (mounted) {
        setState(() {
          _searchResults = results;
          _searching = false;
          if (results.isEmpty) _error = 'No numbers found. Try a different area code.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searching = false;
          _error = 'Search failed. Please try again.';
        });
      }
    }
  }

  Future<void> _provision() async {
    final companyRef = ref.read(companyIdProvider).asData?.value;
    if (companyRef == null || _selectedNumber == null) return;

    setState(() {
      _provisioning = true;
      _error = null;
    });

    try {
      await _phoneService.provision(
        companyId: companyRef.id,
        phoneNumber: _selectedNumber!['phoneNumber'] as String,
        forwardTo: _forwardToCtrl.text.trim().isNotEmpty
            ? _forwardToCtrl.text.trim()
            : null,
        label: _labelCtrl.text.trim().isNotEmpty
            ? _labelCtrl.text.trim()
            : null,
      );

      // Mark wizard step complete
      await _wizardService.completeItem('business_phone', data: {
        'number': _selectedNumber!['phoneNumber'],
        'forwardTo': _forwardToCtrl.text.trim(),
        'label': _labelCtrl.text.trim(),
        'provisionedVia': 'twilio',
      });

      if (mounted) {
        setState(() {
          _provisioning = false;
          _step = _DialogStep.done;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _provisioning = false;
          _error = e.toString().contains('already-exists')
              ? 'This number was already provisioned.'
              : e.toString().contains('unavailable')
                  ? 'This number is no longer available. Please search again.'
                  : 'Provisioning failed. Please try again.';
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
          Icon(Icons.phone_outlined, color: Theme.of(context).primaryColor),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Get a Business Phone Number', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: switch (_step) {
            _DialogStep.search => _buildSearchStep(),
            _DialogStep.configure => _buildConfigureStep(),
            _DialogStep.done => _buildDoneStep(),
          },
        ),
      ),
      actions: switch (_step) {
        _DialogStep.search => [
          TextButton(
            onPressed: () {
              _wizardService.skipItem('business_phone');
              Navigator.pop(context);
            },
            child: const Text('Skip'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          if (_selectedNumber != null)
            FilledButton(
              onPressed: () => setState(() => _step = _DialogStep.configure),
              child: const Text('Next'),
            ),
        ],
        _DialogStep.configure => [
          TextButton(
            onPressed: () => setState(() => _step = _DialogStep.search),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: _provisioning ? null : _provision,
            child: _provisioning
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Provision Number'),
          ),
        ],
        _DialogStep.done => [
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
          'Search for an available number',
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _areaCodeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Area Code',
                  hintText: '801',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                maxLength: 3,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _stateCtrl,
                decoration: const InputDecoration(
                  labelText: 'State (2-letter)',
                  hintText: 'UT',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.characters,
                maxLength: 2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _searching ? null : _search,
            icon: _searching
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search),
            label: Text(_searching ? 'Searching...' : 'Search Available Numbers'),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: Colors.red[700], fontSize: 13)),
        ],
        if (_searchResults.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            '${_searchResults.length} numbers found',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 250),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _searchResults.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final number = _searchResults[index];
                final phone = number['phoneNumber'] as String? ?? '';
                final locality = number['locality'] as String? ?? '';
                final region = number['region'] as String? ?? '';
                final isSelected = _selectedNumber == number;

                return ListTile(
                  dense: true,
                  selected: isSelected,
                  selectedTileColor: Theme.of(context).primaryColor.withValues(alpha: 0.08),
                  leading: Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
                  ),
                  title: Text(
                    _formatPhoneNumber(phone),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  subtitle: (locality.isNotEmpty || region.isNotEmpty)
                      ? Text('$locality${locality.isNotEmpty && region.isNotEmpty ? ', ' : ''}$region')
                      : null,
                  onTap: () => setState(() => _selectedNumber = number),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  // ── Configure step ────────────────────────────────────────────

  Widget _buildConfigureStep() {
    final phone = _selectedNumber?['phoneNumber'] as String? ?? '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.phone, color: Theme.of(context).primaryColor),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Selected Number',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(
                    _formatPhoneNumber(phone),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _labelCtrl,
          decoration: const InputDecoration(
            labelText: 'Label',
            hintText: 'Business Line, Sales, Support...',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _forwardToCtrl,
          decoration: const InputDecoration(
            labelText: 'Forward Calls To (optional)',
            hintText: '+15551234567',
            helperText: 'Your personal number — calls will ring there until you set up VoIP.',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.phone,
        ),
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
                  'You own this number. It is registered under your '
                  'business account and can be transferred to any carrier '
                  'at any time if you ever leave KleenOps.',
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
                  'Approximately \$1.15/month plus usage. '
                  'Supports voice calls and SMS.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: Colors.red[700], fontSize: 13)),
        ],
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
          'Business Phone Ready',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (_existingNumbers.isNotEmpty)
          ...(_existingNumbers.map((n) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  dense: true,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  leading: const Icon(Icons.phone, color: Colors.green),
                  title: Text(
                    _formatPhoneNumber(n['number'] as String? ?? ''),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(n['label'] as String? ?? 'Business Line'),
                ),
              )))
        else
          Text(
            'Your number has been provisioned and is ready to use.',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────

  String _formatPhoneNumber(String raw) {
    // Format +15551234567 → (555) 123-4567
    final digits = raw.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length == 11 && digits.startsWith('1')) {
      final area = digits.substring(1, 4);
      final prefix = digits.substring(4, 7);
      final line = digits.substring(7);
      return '($area) $prefix-$line';
    }
    return raw;
  }
}

enum _DialogStep { search, configure, done }
