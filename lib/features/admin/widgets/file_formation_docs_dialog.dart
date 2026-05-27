import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kleenops_admin/services/ai_text_adapter.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import '../services/setup_wizard_service.dart';

/// Dialog for the "File Formation Documents" wizard step.
class FileFormationDocsDialog extends StatefulWidget {
  final Map<String, dynamic> itemData;
  final SetupWizardService service;
  final bool isExisting;

  /// Optional company reference kept for call-site compatibility. Admin uses
  /// top-level collections, so the value is not used internally.
  final DocumentReference<Map<String, dynamic>>? companyRef;

  const FileFormationDocsDialog({
    super.key,
    required this.itemData,
    required this.service,
    required this.isExisting,
    this.companyRef,
  });

  @override
  State<FileFormationDocsDialog> createState() =>
      _FileFormationDocsDialogState();
}

class _FileFormationDocsDialogState extends State<FileFormationDocsDialog> {
  late final TextEditingController _notesCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final data = (widget.itemData['data'] as Map<String, dynamic>?) ?? {};
    _notesCtrl =
        TextEditingController(text: (data['notes'] ?? '').toString());
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.service.completeItem(
      'file_formation_docs',
      data: {'notes': _notesCtrl.text.trim()},
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isExisting
        ? 'Upload Formation Documents'
        : 'File Formation Documents';
    final hint = widget.isExisting
        ? 'Upload your existing Articles of Organization / Incorporation.'
        : "Upload your Articles of Organization / Incorporation once you've filed them with the state.";

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
          Text(hint,
              style: const TextStyle(fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300, width: 1.5),
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.shade50,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.upload_file_outlined,
                    size: 32, color: Colors.grey.shade500),
                const SizedBox(height: 8),
                Text(
                  'Document upload coming soon',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AITextField(
            labelText: 'Notes (filing date, state ID, etc.)',
            controller: _notesCtrl,
            createTranscriber: createGoogleStreamingTranscriber,
            minLines: 2,
            maxLines: 4,
          ),
        ],
      ),
    );
  }
}
