import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:shared_widgets/labels/text_info_checkbox.dart';
import '../services/setup_wizard_service.dart';

// ── Entity type constants (kept local — admin's setup_wizard_data does not
// expose these). Values mirror kleenops/lib/features/admin/data/setup_wizard_data.dart.
const String kEntityLlc = 'llc';
const String kEntitySCorp = 's_corp';
const String kEntityCCorp = 'c_corp';
const String kEntitySoleProp = 'sole_prop';
const String kEntityPartnership = 'partnership';

const Map<String, String> kEntityTypeLabels = {
  kEntityLlc: 'LLC',
  kEntitySCorp: 'S-Corp',
  kEntityCCorp: 'C-Corp',
  kEntitySoleProp: 'Sole Proprietorship',
  kEntityPartnership: 'Partnership',
};

/// Dialog for the "Choose Your Entity Type" wizard step.
class EntityTypeDialog extends StatefulWidget {
  final Map<String, dynamic> itemData;
  final SetupWizardService service;
  final bool isExisting;

  /// Optional company reference kept for call-site compatibility. Admin uses
  /// top-level collections, so the value is not used internally.
  final DocumentReference<Map<String, dynamic>>? companyRef;

  const EntityTypeDialog({
    super.key,
    required this.itemData,
    required this.service,
    required this.isExisting,
    this.companyRef,
  });

  @override
  State<EntityTypeDialog> createState() => _EntityTypeDialogState();
}

class _EntityTypeDialogState extends State<EntityTypeDialog> {
  String? _entity;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final data = (widget.itemData['data'] as Map<String, dynamic>?) ?? {};
    _entity = data['entity'] as String?;
  }

  Future<void> _save() async {
    if (_entity == null) return;
    setState(() => _saving = true);
    await widget.service.completeItem(
      'entity_type',
      data: {
        'entity': _entity,
        'entityLabel': kEntityTypeLabels[_entity!] ?? _entity,
      },
    );
    if (mounted) Navigator.pop(context);
  }

  void _showEntityInfo(String key) {
    final info = _kEntityTypeInfo[key];
    if (info == null) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => DialogAction(
        title: info.label,
        cancelText: 'Close',
        onCancel: () => Navigator.pop(ctx),
        showActionButton: false,
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(info.definition,
                  style: const TextStyle(fontSize: 14, height: 1.35)),
              const SizedBox(height: 16),
              const Text('Pros',
                  style:
                      TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              for (final p in info.pros)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text('• $p',
                      style: const TextStyle(fontSize: 13, height: 1.3)),
                ),
              const SizedBox(height: 12),
              const Text('Cons',
                  style:
                      TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              for (final c in info.cons)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text('• $c',
                      style: const TextStyle(fontSize: 13, height: 1.3)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isExisting ? 'Enter Entity Type' : 'Choose Your Entity Type';
    final hint = widget.isExisting
        ? 'Select the entity type this business is registered as.'
        : 'Pick the entity structure you want to form. This affects the next steps.';

    return DialogAction(
      title: title,
      cancelText: 'Cancel',
      onCancel: () => Navigator.pop(context),
      actionText: _saving ? 'Saving…' : 'Save',
      onAction: (_entity == null || _saving) ? null : _save,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(hint,
              style: const TextStyle(fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 8),
          for (final entry in kEntityTypeLabels.entries)
            TextInfoCheckbox(
              text: entry.value,
              value: _entity == entry.key,
              onChanged: _saving
                  ? null
                  : (checked) => setState(
                        () => _entity = (checked ?? false) ? entry.key : null,
                      ),
              onInfoPressed: () => _showEntityInfo(entry.key),
            ),
        ],
      ),
    );
  }
}

class _EntityTypeInfo {
  const _EntityTypeInfo({
    required this.label,
    required this.definition,
    required this.pros,
    required this.cons,
  });
  final String label;
  final String definition;
  final List<String> pros;
  final List<String> cons;
}

const Map<String, _EntityTypeInfo> _kEntityTypeInfo = {
  kEntityLlc: _EntityTypeInfo(
    label: 'LLC (Limited Liability Company)',
    definition:
        'A hybrid structure that gives owners ("members") personal liability '
        'protection like a corporation, while taxes flow through to the '
        'owners\' personal returns by default.',
    pros: [
      'Personal assets shielded from most business debts and lawsuits.',
      'Flexible: 1 owner or many, member- or manager-run.',
      'Pass-through taxation — no separate corporate tax by default.',
      'Less paperwork than a corporation.',
    ],
    cons: [
      'Self-employment tax on most member earnings.',
      'Rules and fees vary by state.',
      'Harder to raise outside investment than a C-Corp.',
    ],
  ),
  kEntitySCorp: _EntityTypeInfo(
    label: 'S-Corporation',
    definition:
        'A corporation (or LLC) that has elected pass-through taxation under '
        'IRS Subchapter S. Owners are paid a "reasonable salary" plus '
        'distributions, which can lower self-employment tax.',
    pros: [
      'Personal liability protection.',
      'Can reduce self-employment tax via salary + distribution split.',
      'Pass-through taxation — no double tax.',
    ],
    cons: [
      'Must run real payroll for owner-employees.',
      'Strict eligibility: ≤100 U.S.-individual shareholders, one class of stock.',
      'More IRS scrutiny on what counts as a "reasonable salary."',
    ],
  ),
  kEntityCCorp: _EntityTypeInfo(
    label: 'C-Corporation',
    definition:
        'A separate legal entity that pays its own corporate income tax. '
        'The default structure for venture-backed companies and businesses '
        'that plan to issue stock to outside investors.',
    pros: [
      'Strongest liability protection.',
      'Unlimited shareholders, multiple stock classes.',
      'Easiest structure for raising venture capital.',
      'Wider range of deductible employee benefits.',
    ],
    cons: [
      'Double taxation: corporate tax + tax on shareholder dividends.',
      'Most paperwork: board, bylaws, minutes, annual filings.',
      'Higher setup and compliance cost.',
    ],
  ),
  kEntitySoleProp: _EntityTypeInfo(
    label: 'Sole Proprietorship',
    definition:
        'You and the business are legally the same person. No formation '
        'paperwork required — just start operating (a DBA may be needed to '
        'use a trade name).',
    pros: [
      'Easiest and cheapest to start.',
      'Full control — no partners or board.',
      'Profits taxed once on your personal return.',
    ],
    cons: [
      'No liability shield — your personal assets are exposed.',
      'Harder to get loans or investment.',
      'All net profit is subject to self-employment tax.',
    ],
  ),
  kEntityPartnership: _EntityTypeInfo(
    label: 'Partnership',
    definition:
        'Two or more people sharing ownership of a business. A general '
        'partnership forms automatically when two people go into business '
        'together; LP and LLP variants offer some liability protection.',
    pros: [
      'Simple to form and operate.',
      'Pass-through taxation — profits taxed on partners\' returns.',
      'Shared workload, capital, and decision-making.',
    ],
    cons: [
      'General partners are personally liable for business debts.',
      'Partners are bound by each other\'s business actions.',
      'Disputes between partners can derail the business.',
    ],
  ),
};
