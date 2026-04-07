// lib/features/admin/widgets/registered_agent_dialog.dart
//
// Dialog for the Registered Agent & Business Address wizard step.
// Explains why a registered agent is required for LLCs/Corps, and
// offers two paths: set up via KleenOps (Northwest) or bring your own.

import 'package:flutter/material.dart';
import '../services/setup_wizard_service.dart';

class RegisteredAgentDialog extends StatefulWidget {
  final Map<String, dynamic> itemData;

  const RegisteredAgentDialog({required this.itemData, super.key});

  @override
  State<RegisteredAgentDialog> createState() => _RegisteredAgentDialogState();
}

class _RegisteredAgentDialogState extends State<RegisteredAgentDialog> {
  final _service = SetupWizardService.instance;

  /// 'kleenops' = set up via Northwest through KleenOps
  /// 'own'      = user already has one / will set up their own
  String _choice = 'kleenops';

  final _agentNameCtrl = TextEditingController();
  final _agentAddressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final data = widget.itemData['data'] as Map<String, dynamic>? ?? {};
    _choice = (data['choice'] as String?) ?? 'kleenops';
    _agentNameCtrl.text = (data['agentName'] ?? '').toString();
    _agentAddressCtrl.text = (data['agentAddress'] ?? '').toString();
    _notesCtrl.text = (widget.itemData['notes'] ?? '').toString();
  }

  @override
  void dispose() {
    _agentNameCtrl.dispose();
    _agentAddressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.contact_mail_outlined),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Registered Agent & Business Address',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Disclaimer / Explanation ──────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 18, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Why do I need this?',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Every LLC, Corporation, and Partnership is legally '
                    'required to designate a registered agent in the '
                    'state where the business is formed.',
                    style: TextStyle(fontSize: 12.5, height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'A registered agent receives legal documents '
                    '(lawsuits, subpoenas, state notices) on your '
                    'behalf at a physical address. Without one, your '
                    'personal home address goes on public record.',
                    style: TextStyle(fontSize: 12.5, height: 1.4),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── What's included ──────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What you get:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 6),
                  _BulletPoint('Registered agent — legal address on your '
                      'state filing (required)'),
                  _BulletPoint('Professional business address — a real '
                      'street address for mail, invoices, and bank accounts'),
                  _BulletPoint('Mail scanning — documents opened and '
                      'emailed to you digitally'),
                  _BulletPoint('Privacy — your home address stays off '
                      'public records'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Option 1: KleenOps / Northwest ───────────
            _OptionCard(
              selected: _choice == 'kleenops',
              onTap: () => setState(() => _choice = 'kleenops'),
              icon: Icons.rocket_launch_outlined,
              color: const Color(0xFF002E5D),
              title: 'Set up through KleenOps',
              subtitle: 'Powered by Northwest Registered Agent',
              cost: '\$125/yr',
              description:
                  'We\'ll handle the registration for you. Includes '
                  'registered agent service, business mailing address, '
                  'and mail scanning.',
            ),

            const SizedBox(height: 8),

            // ── Option 2: Bring your own ─────────────────
            _OptionCard(
              selected: _choice == 'own',
              onTap: () => setState(() => _choice = 'own'),
              icon: Icons.edit_outlined,
              color: Colors.grey.shade700,
              title: 'I already have one',
              subtitle: 'Enter your registered agent details',
              description:
                  'If you\'ve already set up a registered agent '
                  'or prefer to use a different provider.',
            ),

            // ── "Own" details fields ─────────────────────
            if (_choice == 'own') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _agentNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Registered Agent Name',
                  hintText: 'e.g. Northwest Registered Agent',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _agentAddressCtrl,
                decoration: const InputDecoration(
                  labelText: 'Agent / Business Address',
                  hintText: '123 Main St, Suite 100, City, ST 12345',
                  border: OutlineInputBorder(),
                ),
                minLines: 2,
                maxLines: 3,
              ),
            ],

            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'Any additional details...',
                border: OutlineInputBorder(),
              ),
              minLines: 2,
              maxLines: 4,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            _service.skipItem('registered_agent');
            Navigator.pop(context);
          },
          child: const Text('Skip'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving
              ? null
              : () async {
                  setState(() => _saving = true);
                  await _service.completeItem(
                    'registered_agent',
                    data: {
                      'choice': _choice,
                      'provider': _choice == 'kleenops'
                          ? 'Northwest Registered Agent'
                          : 'Other',
                      'annualCost':
                          _choice == 'kleenops' ? 125.0 : null,
                      'agentName': _choice == 'own'
                          ? _agentNameCtrl.text.trim()
                          : 'Northwest Registered Agent',
                      'agentAddress': _choice == 'own'
                          ? _agentAddressCtrl.text.trim()
                          : null,
                      'notes': _notesCtrl.text.trim(),
                    },
                  );
                  if (context.mounted) Navigator.pop(context);
                },
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Mark Complete'),
        ),
      ],
    );
  }
}

// ── Option card ───────────────────────────────────────────────────────────

class _OptionCard extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String? cost;
  final String description;

  const _OptionCard({
    required this.selected,
    required this.onTap,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.description,
    this.cost,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 4),
              child: Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 20,
                color: selected ? color : Colors.grey.shade400,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 18, color: color),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: color,
                          ),
                        ),
                      ),
                      if (cost != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            cost!,
                            style: TextStyle(
                              color: Colors.green.shade800,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bullet point ──────────────────────────────────────────────────────────

class _BulletPoint extends StatelessWidget {
  final String text;
  const _BulletPoint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('  \u2022  ', style: TextStyle(fontSize: 12)),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 12, height: 1.3)),
          ),
        ],
      ),
    );
  }
}
