import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kleenops_admin/services/ai_text_adapter.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:shared_widgets/fields/ai_text.dart' as shared;
import 'package:shared_widgets/tiles/selectable_row_tile.dart';
import '../services/setup_wizard_service.dart';

/// Dialog for the "Set Industry Classification Codes" wizard step.
class NaicsSicDialog extends StatefulWidget {
  final Map<String, dynamic> itemData;
  final SetupWizardService service;
  final bool isExisting;

  /// Optional company reference kept for call-site compatibility. Admin uses
  /// top-level collections, so the value is not used internally.
  final DocumentReference<Map<String, dynamic>>? companyRef;

  const NaicsSicDialog({
    super.key,
    required this.itemData,
    required this.service,
    required this.isExisting,
    this.companyRef,
  });

  @override
  State<NaicsSicDialog> createState() => _NaicsSicDialogState();
}

class _NaicsSicDialogState extends State<NaicsSicDialog> {
  late final TextEditingController _naicsCtrl;
  late final TextEditingController _sicCtrl;
  bool _dontKnow = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final data = (widget.itemData['data'] as Map<String, dynamic>?) ?? {};
    _naicsCtrl =
        TextEditingController(text: (data['naics'] ?? '').toString());
    _sicCtrl = TextEditingController(text: (data['sic'] ?? '').toString());
    _dontKnow = (data['mode'] as String?) == 'unknown';
  }

  @override
  void dispose() {
    _naicsCtrl.dispose();
    _sicCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.service.completeItem(
      'naics_sic_codes',
      data: {
        'naics': _dontKnow ? '' : _naicsCtrl.text.trim(),
        'sic': _dontKnow ? '' : _sicCtrl.text.trim(),
        'mode': _dontKnow ? 'unknown' : 'entered',
      },
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isExisting
        ? 'Enter Industry Classification Code'
        : 'Set Industry Classification Codes';

    final canSave = !_saving &&
        (_dontKnow || _naicsCtrl.text.trim().isNotEmpty);

    return DialogAction(
      title: title,
      cancelText: 'Cancel',
      onCancel: () => Navigator.pop(context),
      actionText: _saving ? 'Saving…' : 'Save',
      onAction: canSave ? _save : null,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'NAICS (and the older SIC) codes describe what your business does. They show up on tax filings and licenses.',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Text(
              'Common cleaning codes:\n'
              '• NAICS 561720 — Janitorial Services\n'
              '• NAICS 561740 — Carpet & Upholstery Cleaning\n'
              '• SIC 7349 — Building Cleaning & Maintenance\n\n'
              'Look up codes at census.gov/naics.',
              style: TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
          const SizedBox(height: 12),
          AITextField(
            labelText: 'NAICS code (e.g. 561720)',
            controller: _naicsCtrl,
            createTranscriber: createGoogleStreamingTranscriber,
            height: shared.StreamingSpeechFieldHeight.singleLine,
            maxLines: 1,
            enabled: !_dontKnow,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          AITextField(
            labelText: 'SIC code (optional, e.g. 7349)',
            controller: _sicCtrl,
            createTranscriber: createGoogleStreamingTranscriber,
            height: shared.StreamingSpeechFieldHeight.singleLine,
            maxLines: 1,
            enabled: !_dontKnow,
          ),
          const SizedBox(height: 4),
          SelectableRowTile<bool>(
            value: true,
            selected: _dontKnow,
            onTap: () => setState(() => _dontKnow = !_dontKnow),
            label: "I don't know my code yet",
            subtitle:
                "We'll mark this as in progress so you can come back to it.",
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
