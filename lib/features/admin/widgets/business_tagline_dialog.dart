import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kleenops_admin/services/ai_text_adapter.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import '../services/setup_wizard_service.dart';

/// Dialog for the "Create a Tagline / Mission" wizard step.
class BusinessTaglineDialog extends StatefulWidget {
  final Map<String, dynamic> itemData;
  final SetupWizardService service;
  final bool isExisting;

  /// Optional company reference kept for call-site compatibility. Admin uses
  /// top-level collections, so the value is not used internally.
  final DocumentReference<Map<String, dynamic>>? companyRef;

  const BusinessTaglineDialog({
    super.key,
    required this.itemData,
    required this.service,
    required this.isExisting,
    this.companyRef,
  });

  @override
  State<BusinessTaglineDialog> createState() => _BusinessTaglineDialogState();
}

class _BusinessTaglineDialogState extends State<BusinessTaglineDialog> {
  late final TextEditingController _ctrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final data = (widget.itemData['data'] as Map<String, dynamic>?) ?? {};
    _ctrl = TextEditingController(text: (data['tagline'] ?? '').toString());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = _ctrl.text.trim();
    if (value.isEmpty) return;
    setState(() => _saving = true);
    await widget.service.completeItem(
      'business_tagline',
      data: {'tagline': value},
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final exists = widget.isExisting;
    final title = exists
        ? 'Refine Your Tagline / Mission'
        : 'Create a Tagline / Mission';
    final hint = exists
        ? 'Enter or refine the tagline / mission you already use.'
        : 'Write a short statement that defines your business — voice and AI can help.';

    return DialogAction(
      title: title,
      cancelText: 'Cancel',
      onCancel: () => Navigator.pop(context),
      actionText: _saving ? 'Saving…' : 'Save',
      onAction: _saving ? null : _save,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hint,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          AITextField(
            labelText: 'Tagline / mission',
            controller: _ctrl,
            createTranscriber: createGoogleStreamingTranscriber,
            minLines: 2,
            maxLines: 5,
          ),
        ],
      ),
    );
  }
}
