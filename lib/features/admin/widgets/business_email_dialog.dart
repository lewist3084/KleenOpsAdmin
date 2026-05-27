import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kleenops_admin/services/ai_text_adapter.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:shared_widgets/fields/ai_text.dart' as shared;
import 'package:shared_widgets/tiles/selectable_row_tile.dart';
import '../services/setup_wizard_service.dart';

/// Dialog for the "Set Up Business Email" wizard step.
///
/// Free-form when the user owns their domain; standard-format picker when the
/// domain was purchased through us.
class BusinessEmailDialog extends StatefulWidget {
  final Map<String, dynamic> itemData;
  final Map<String, dynamic> domainItemData;
  final SetupWizardService service;
  final bool isExisting;

  /// Optional company reference kept for call-site compatibility. Admin uses
  /// top-level collections, so the value is not used internally.
  final DocumentReference<Map<String, dynamic>>? companyRef;

  const BusinessEmailDialog({
    super.key,
    required this.itemData,
    required this.domainItemData,
    required this.service,
    required this.isExisting,
    this.companyRef,
  });

  @override
  State<BusinessEmailDialog> createState() => _BusinessEmailDialogState();
}

class _BusinessEmailDialogState extends State<BusinessEmailDialog> {
  late final TextEditingController _emailCtrl;
  String? _format; // 'first.last' | 'first_last' | 'first-last' | 'firstlast' | 'flast'
  bool _saving = false;

  static const Map<String, String> _formatExamples = {
    'first.last': 'first.last',
    'first_last': 'first_last',
    'first-last': 'first-last',
    'firstlast': 'firstlast',
    'flast': 'flast',
  };

  @override
  void initState() {
    super.initState();
    final data = (widget.itemData['data'] as Map<String, dynamic>?) ?? {};
    _emailCtrl =
        TextEditingController(text: (data['email'] ?? '').toString());
    _format = data['format'] as String?;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  String? get _domain {
    final data =
        (widget.domainItemData['data'] as Map<String, dynamic>?) ?? {};
    final raw = (data['domain'] as String?)?.trim();
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }

  String? get _domainSource {
    final data =
        (widget.domainItemData['data'] as Map<String, dynamic>?) ?? {};
    return data['source'] as String?;
  }

  Future<void> _saveEntered() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;
    setState(() => _saving = true);
    await widget.service.completeItem(
      'business_email',
      data: {'email': email, 'mode': 'entered'},
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _saveFormat() async {
    if (_format == null) return;
    setState(() => _saving = true);
    await widget.service.completeItem(
      'business_email',
      data: {'format': _format, 'mode': 'standard'},
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final source = _domainSource;
    final purchased = source == 'purchased';
    final domain = _domain ?? 'yourdomain.com';

    if (!purchased) {
      // Entered-domain (or no choice yet) flow: free-form email entry.
      final hint = source == null
          ? 'Tip: complete the domain step first so your email can live on your own domain.'
          : 'Enter the business email address you use on this domain.';
      return DialogAction(
        title: widget.isExisting ? 'Enter Business Email' : 'Set Up Business Email',
        cancelText: 'Cancel',
        onCancel: () => Navigator.pop(context),
        actionText: _saving ? 'Saving…' : 'Save',
        onAction: (_saving || _emailCtrl.text.trim().isEmpty) ? null : _saveEntered,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(hint,
                style:
                    const TextStyle(fontSize: 13, color: Colors.black54)),
            const SizedBox(height: 12),
            AITextField(
              labelText: 'Business email (e.g. you@$domain)',
              controller: _emailCtrl,
              createTranscriber: createGoogleStreamingTranscriber,
              height: shared.StreamingSpeechFieldHeight.singleLine,
              maxLines: 1,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      );
    }

    // Purchased-domain flow: pick a standard email-address format.
    return DialogAction(
      title: 'Standard Email Format',
      cancelText: 'Cancel',
      onCancel: () => Navigator.pop(context),
      actionText: _saving ? 'Saving…' : 'Save',
      onAction: (_format == null || _saving) ? null : _saveFormat,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Pick how addresses on @$domain should be formatted. You can change this later.",
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          for (final entry in _formatExamples.entries)
            SelectableRowTile<String>(
              value: entry.key,
              control: SelectControl.radio,
              selected: _format == entry.key,
              onTap: () => setState(() => _format = entry.key),
              label: '${entry.value}@$domain',
              contentPadding: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }
}
