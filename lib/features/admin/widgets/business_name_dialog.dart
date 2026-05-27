import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kleenops_admin/services/ai_text_adapter.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:shared_widgets/fields/ai_text.dart' as shared;
import '../services/setup_wizard_service.dart';

/// Dialog for the "Choose Your Business Name" wizard step.
class BusinessNameDialog extends StatefulWidget {
  final Map<String, dynamic> itemData;
  final SetupWizardService service;
  final bool isExisting;

  /// Optional company reference kept for call-site compatibility. Admin uses
  /// top-level collections, so the value is not used internally.
  final DocumentReference<Map<String, dynamic>>? companyRef;

  const BusinessNameDialog({
    super.key,
    required this.itemData,
    required this.service,
    required this.isExisting,
    this.companyRef,
  });

  @override
  State<BusinessNameDialog> createState() => _BusinessNameDialogState();
}

class _BusinessNameDialogState extends State<BusinessNameDialog> {
  late final TextEditingController _ctrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final data = (widget.itemData['data'] as Map<String, dynamic>?) ?? {};
    _ctrl = TextEditingController(text: (data['name'] ?? '').toString());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _ctrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    await widget.service.completeItem(
      'business_name',
      data: {'name': name},
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final exists = widget.isExisting;
    final title = exists ? 'Enter Your Business Name' : 'Choose Your Business Name';
    final hint = exists
        ? 'Type your existing business name as it is registered.'
        : 'Brainstorm a name — use voice or AI to refine ideas, then pick one.';
    final fieldLabel = exists ? 'Business name' : 'Business name idea';

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
            labelText: fieldLabel,
            controller: _ctrl,
            createTranscriber: createGoogleStreamingTranscriber,
            height: shared.StreamingSpeechFieldHeight.singleLine,
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}
