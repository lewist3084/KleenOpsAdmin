import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kleenops_admin/services/ai_text_adapter.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:shared_widgets/fields/ai_text.dart' as shared;
import 'package:shared_widgets/tiles/selectable_row_tile.dart';
import '../services/setup_wizard_service.dart';

/// Dialog for the optional "Get a DUNS Number" wizard step.
class DunsDialog extends StatefulWidget {
  final Map<String, dynamic> itemData;
  final SetupWizardService service;
  final bool isExisting;

  /// Optional company reference kept for call-site compatibility. Admin uses
  /// top-level collections, so the value is not used internally.
  final DocumentReference<Map<String, dynamic>>? companyRef;

  const DunsDialog({
    super.key,
    required this.itemData,
    required this.service,
    required this.isExisting,
    this.companyRef,
  });

  @override
  State<DunsDialog> createState() => _DunsDialogState();
}

class _DunsDialogState extends State<DunsDialog> {
  late final TextEditingController _dunsCtrl;
  String _status = 'have'; // 'have' | 'help' | 'skip'
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final data = (widget.itemData['data'] as Map<String, dynamic>?) ?? {};
    _dunsCtrl = TextEditingController(text: (data['duns'] ?? '').toString());
    final stored = data['status'] as String?;
    if (stored == 'have' || stored == 'help' || stored == 'skip') {
      _status = stored!;
    }
  }

  @override
  void dispose() {
    _dunsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_status == 'have' && _dunsCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    await widget.service.completeItem(
      'duns_number',
      data: {
        'duns': _status == 'have' ? _dunsCtrl.text.trim() : '',
        'status': _status,
      },
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isExisting
        ? 'Enter DUNS Number (Optional)'
        : 'Get a DUNS Number (Optional)';

    final canSave = !_saving &&
        (_status != 'have' || _dunsCtrl.text.trim().isNotEmpty);

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
            "A DUNS number is a 9-digit business ID used for government contracts and some vendor registrations. It's free from Dun & Bradstreet.",
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          SelectableRowTile<String>(
            value: 'have',
            control: SelectControl.radio,
            selected: _status == 'have',
            onTap: () => setState(() => _status = 'have'),
            label: 'I already have one',
            contentPadding: EdgeInsets.zero,
          ),
          SelectableRowTile<String>(
            value: 'help',
            control: SelectControl.radio,
            selected: _status == 'help',
            onTap: () => setState(() => _status = 'help'),
            label: "I'd like help getting one",
            contentPadding: EdgeInsets.zero,
          ),
          SelectableRowTile<String>(
            value: 'skip',
            control: SelectControl.radio,
            selected: _status == 'skip',
            onTap: () => setState(() => _status = 'skip'),
            label: "Don't need one",
            contentPadding: EdgeInsets.zero,
          ),
          if (_status == 'have') ...[
            const SizedBox(height: 8),
            AITextField(
              labelText: 'DUNS number (9 digits)',
              controller: _dunsCtrl,
              createTranscriber: createGoogleStreamingTranscriber,
              height: shared.StreamingSpeechFieldHeight.singleLine,
              maxLines: 1,
              onChanged: (_) => setState(() {}),
            ),
          ],
          if (_status == 'help') ...[
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
                "We'll walk you through requesting a free DUNS number from Dun & Bradstreet. Guided flow coming soon.",
                style: TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
