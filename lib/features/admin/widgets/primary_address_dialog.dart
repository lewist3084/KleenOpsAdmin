import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';
import 'package:kleenops_admin/services/ai_text_adapter.dart';
import 'package:kleenops_admin/widgets/fields/google_address.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:shared_widgets/utils/google_api_key.dart';
import '../services/setup_wizard_service.dart';

/// Dialog for the "Set Business Address" wizard step.
class PrimaryAddressDialog extends StatefulWidget {
  final Map<String, dynamic> itemData;
  final SetupWizardService service;

  /// Optional company reference kept for call-site compatibility. Admin uses
  /// top-level collections, so the value is not used internally.
  final DocumentReference<Map<String, dynamic>>? companyRef;

  const PrimaryAddressDialog({
    super.key,
    required this.itemData,
    required this.service,
    this.companyRef,
  });

  @override
  State<PrimaryAddressDialog> createState() => _PrimaryAddressDialogState();
}

class _PrimaryAddressDialogState extends State<PrimaryAddressDialog> {
  late final TextEditingController _addressCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _stateCtrl;
  late final TextEditingController _zipCtrl;
  late final TextEditingController _virtualNotesCtrl;
  double? _lat;
  double? _lng;
  String? _placeId;
  bool _wantVirtual = false;
  bool _saving = false;

  static const Map<String, String> _kVirtualProviderUrls = {
    'northwest': 'https://www.northwestregisteredagent.com/business-address',
    'incfile': 'https://bizee.com/virtual-address-for-business',
    'earth_class_mail': 'https://www.earthclassmail.com/',
    'anytime_mailbox': 'https://www.anytimemailbox.com/',
  };

  @override
  void initState() {
    super.initState();
    final data = (widget.itemData['data'] as Map<String, dynamic>?) ?? {};
    _addressCtrl =
        TextEditingController(text: (data['address'] ?? '').toString());
    _cityCtrl = TextEditingController(text: (data['city'] ?? '').toString());
    _stateCtrl = TextEditingController(text: (data['state'] ?? '').toString());
    _zipCtrl = TextEditingController(text: (data['zip'] ?? '').toString());
    _virtualNotesCtrl = TextEditingController(
        text: (data['virtualNotes'] ?? '').toString());
    _lat = (data['lat'] as num?)?.toDouble();
    _lng = (data['lng'] as num?)?.toDouble();
    _placeId = data['placeId'] as String?;
    _wantVirtual = data['mode'] == 'virtual';
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _zipCtrl.dispose();
    _virtualNotesCtrl.dispose();
    super.dispose();
  }

  void _applyGooglePlace(Map<String, dynamic> m) {
    _lat = (m['lat'] as num?)?.toDouble();
    _lng = (m['lng'] as num?)?.toDouble();
    _placeId = m['placeId'] as String?;
    final comps = (m['components'] as Map?) ?? const {};
    final city = comps['city'] as String?;
    final state = comps['state'] as String?;
    final zip = comps['zip'] as String? ?? comps['postal_code'] as String?;
    setState(() {
      if (city != null && city.isNotEmpty) _cityCtrl.text = city;
      if (state != null && state.isNotEmpty) _stateCtrl.text = state;
      if (zip != null && zip.isNotEmpty) _zipCtrl.text = zip;
    });
  }

  Future<void> _save() async {
    final address = _addressCtrl.text.trim();
    if (address.isEmpty && !_wantVirtual) return;
    setState(() => _saving = true);
    await widget.service.completeItem('primary_address', data: {
      'mode': _wantVirtual ? 'virtual' : 'entered',
      'address': address,
      'city': _cityCtrl.text.trim(),
      'state': _stateCtrl.text.trim(),
      'zip': _zipCtrl.text.trim(),
      if (_lat != null) 'lat': _lat,
      if (_lng != null) 'lng': _lng,
      if (_placeId != null) 'placeId': _placeId,
      'wantVirtual': _wantVirtual,
      if (_wantVirtual) 'virtualNotes': _virtualNotesCtrl.text.trim(),
    });
    if (mounted) Navigator.pop(context);
  }

  Widget _virtualProviderTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required String urlKey,
  }) {
    return InkWell(
      onTap: () {
        final url = _kVirtualProviderUrls[urlKey];
        if (url == null) return;
        SnackbarService.instance.showSnackBar(
          SnackBar(
            content: Text('Visit $url to register a virtual business address.'),
            duration: const Duration(seconds: 5),
          ),
        );
      },
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 22, color: Colors.grey.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
            ),
            Icon(Icons.open_in_new,
                size: 16, color: Colors.grey.shade500),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSave = !_saving &&
        (_addressCtrl.text.trim().isNotEmpty ||
            (_wantVirtual && _virtualNotesCtrl.text.trim().isNotEmpty));

    return DialogAction(
      title: 'Enter or Purchase Business Address',
      cancelText: 'Cancel',
      onCancel: () => Navigator.pop(context),
      actionText: _saving ? 'Saving…' : 'Save',
      onAction: canSave ? _save : null,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Use the address you already have — start typing and pick from Google\'s suggestions.',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          GoogleAddressField(
            apiKey: kGoogleApiKey,
            controller: _addressCtrl,
            labelText: 'Business address',
            onSelected: (m) {
              _applyGooglePlace(m);
              setState(() {});
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cityCtrl,
                  decoration: const InputDecoration(
                    labelText: 'City',
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.next,
                  onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 70,
                child: TextField(
                  controller: _stateCtrl,
                  decoration: const InputDecoration(
                    labelText: 'State',
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.next,
                  onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 90,
                child: TextField(
                  controller: _zipCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Zip',
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.done,
                  onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Or purchase a business location',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Use a professional virtual address so your home stays private.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _wantVirtual,
                onChanged: (v) => setState(() => _wantVirtual = v),
              ),
            ],
          ),
          if (_wantVirtual) ...[
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _virtualProviderTile(
                    icon: Icons.business_center_outlined,
                    label: 'Northwest Registered Agent',
                    subtitle: 'Virtual address + RA — about \$125 / yr',
                    urlKey: 'northwest',
                  ),
                  const Divider(height: 1),
                  _virtualProviderTile(
                    icon: Icons.business_outlined,
                    label: 'Bizee (Incfile)',
                    subtitle: 'Virtual address — about \$29 / mo',
                    urlKey: 'incfile',
                  ),
                  const Divider(height: 1),
                  _virtualProviderTile(
                    icon: Icons.markunread_mailbox_outlined,
                    label: 'Earth Class Mail',
                    subtitle: 'Mail scanning + virtual address',
                    urlKey: 'earth_class_mail',
                  ),
                  const Divider(height: 1),
                  _virtualProviderTile(
                    icon: Icons.local_post_office_outlined,
                    label: 'Anytime Mailbox',
                    subtitle: 'Local virtual mailbox addresses',
                    urlKey: 'anytime_mailbox',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            AITextField(
              labelText: 'Notes (provider, plan, status)',
              controller: _virtualNotesCtrl,
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
