import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kleenops_admin/services/ai_text_adapter.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:shared_widgets/fields/ai_text.dart' as shared;
import 'package:shared_widgets/tiles/selectable_row_tile.dart';
import '../services/setup_wizard_service.dart';

/// Dialog for the "Apply for EIN" wizard step.
class EinDialog extends StatefulWidget {
  final Map<String, dynamic> itemData;
  final SetupWizardService service;
  final bool isExisting;

  /// Optional company reference kept for call-site compatibility. Admin uses
  /// top-level collections, so the value is not used internally.
  final DocumentReference<Map<String, dynamic>>? companyRef;

  const EinDialog({
    super.key,
    required this.itemData,
    required this.service,
    required this.isExisting,
    this.companyRef,
  });

  @override
  State<EinDialog> createState() => _EinDialogState();
}

class _EinDialogState extends State<EinDialog> {
  late final TextEditingController _einCtrl;
  bool _dontHaveYet = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final data = (widget.itemData['data'] as Map<String, dynamic>?) ?? {};
    _einCtrl = TextEditingController(text: (data['ein'] ?? '').toString());
    _dontHaveYet = (data['mode'] as String?) == 'pending';
  }

  @override
  void dispose() {
    _einCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final ein = _einCtrl.text.trim();
    if (!_dontHaveYet && ein.isEmpty) return;
    setState(() => _saving = true);
    await widget.service.completeItem(
      'ein_application',
      data: {
        'ein': _dontHaveYet ? '' : ein,
        'mode': _dontHaveYet ? 'pending' : 'entered',
      },
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isExisting ? 'Enter EIN' : 'Apply for EIN (Tax ID)';
    final hint = widget.isExisting
        ? 'Enter the EIN this business was issued (format: 12-3456789).'
        : "If you've received your EIN, enter it here. Otherwise you can apply free at irs.gov/EIN and come back.";

    final canSave =
        !_saving && (_dontHaveYet || _einCtrl.text.trim().isNotEmpty);

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
          Text(hint,
              style: const TextStyle(fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 12),
          AITextField(
            labelText: 'EIN (12-3456789)',
            controller: _einCtrl,
            createTranscriber: createGoogleStreamingTranscriber,
            height: shared.StreamingSpeechFieldHeight.singleLine,
            maxLines: 1,
            enabled: !_dontHaveYet,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 4),
          SelectableRowTile<bool>(
            value: true,
            selected: _dontHaveYet,
            onTap: () => setState(() => _dontHaveYet = !_dontHaveYet),
            label: "I don't have one yet",
            subtitle:
                "We'll mark this as in progress — apply at irs.gov/EIN when you're ready.",
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
