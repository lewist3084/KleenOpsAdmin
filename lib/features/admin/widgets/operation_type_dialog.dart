import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kleenops_admin/services/ai_text_adapter.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:shared_widgets/tiles/selectable_row_tile.dart';
import '../services/setup_wizard_service.dart';

const Map<String, String> kOperationTypeLabels = {
  'grounds': 'Grounds maintenance',
  'janitorial': 'Janitorial activities',
  'building_maintenance': 'Building maintenance',
};

/// Dialog for the "What does your business do?" wizard step.
class OperationTypeDialog extends StatefulWidget {
  final Map<String, dynamic> itemData;
  final SetupWizardService service;

  /// Optional company reference kept for call-site compatibility. Admin uses
  /// top-level collections, so the value is not used internally.
  final DocumentReference<Map<String, dynamic>>? companyRef;

  const OperationTypeDialog({
    super.key,
    required this.itemData,
    required this.service,
    this.companyRef,
  });

  @override
  State<OperationTypeDialog> createState() => _OperationTypeDialogState();
}

class _OperationTypeDialogState extends State<OperationTypeDialog> {
  final Set<String> _selected = <String>{};
  bool _other = false;
  late final TextEditingController _otherCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final data = (widget.itemData['data'] as Map<String, dynamic>?) ?? {};
    final types = (data['types'] as List?)?.cast<String>() ?? const [];
    _selected.addAll(types.where(kOperationTypeLabels.containsKey));
    _other = data['other'] == true ||
        ((data['otherText'] as String?)?.isNotEmpty ?? false);
    _otherCtrl =
        TextEditingController(text: (data['otherText'] ?? '').toString());
  }

  @override
  void dispose() {
    _otherCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final otherText = _otherCtrl.text.trim();
    if (_selected.isEmpty && !(_other && otherText.isNotEmpty)) return;
    setState(() => _saving = true);
    await widget.service.completeItem('operation_type', data: {
      'types': _selected.toList()..sort(),
      'other': _other,
      'otherText': _other ? otherText : '',
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final canSave = !_saving &&
        (_selected.isNotEmpty ||
            (_other && _otherCtrl.text.trim().isNotEmpty));

    return DialogAction(
      title: 'What does your business do?',
      cancelText: 'Cancel',
      onCancel: () => Navigator.pop(context),
      actionText: _saving ? 'Saving…' : 'Save',
      onAction: canSave ? _save : null,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select the activities your business performs. You can pick more than one.',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          for (final entry in kOperationTypeLabels.entries)
            Builder(builder: (_) {
              final isSelected = _selected.contains(entry.key);
              return SelectableRowTile<String>(
                value: entry.key,
                selected: isSelected,
                onTap: () => setState(() {
                  if (isSelected) {
                    _selected.remove(entry.key);
                  } else {
                    _selected.add(entry.key);
                  }
                }),
                label: entry.value,
                contentPadding: EdgeInsets.zero,
              );
            }),
          SelectableRowTile<bool>(
            value: true,
            selected: _other,
            onTap: () => setState(() => _other = !_other),
            label: 'Other',
            contentPadding: EdgeInsets.zero,
          ),
          if (_other) ...[
            const SizedBox(height: 8),
            AITextField(
              labelText: 'Describe your business',
              controller: _otherCtrl,
              createTranscriber: createGoogleStreamingTranscriber,
              minLines: 1,
              maxLines: 3,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ],
      ),
    );
  }
}
