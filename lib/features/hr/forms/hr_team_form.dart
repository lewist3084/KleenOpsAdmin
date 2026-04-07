import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:shared_widgets/services/firestore_service.dart';
import 'package:kleenops_admin/app/shared_widgets/forms/cancel_save_adapter.dart';
import 'package:shared_widgets/containers/container_action.dart';

class HrTeamFormArgs {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final DocumentReference<Map<String, dynamic>>? teamRef;

  const HrTeamFormArgs({
    required this.companyRef,
    this.teamRef,
  });
}

enum HrTeamFormResult { saved }

class HrTeamForm extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final DocumentReference<Map<String, dynamic>>? teamRef;

  const HrTeamForm({
    super.key,
    required this.companyRef,
    this.teamRef,
  });

  @override
  State<HrTeamForm> createState() => _HrTeamFormState();
}

class _HrTeamFormState extends State<HrTeamForm> {
  final _formKey = GlobalKey<FormState>();
  final _fs = FirestoreService();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _frontWindowCtrl;
  late final TextEditingController _pacingIntervalCtrl;
  late final TextEditingController _rearWindowCtrl;
  late final TextEditingController _scheduleForecastCtrl;

  bool _pacing = false;
  bool _priority = false;
  bool _loading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _descriptionCtrl = TextEditingController();
    _frontWindowCtrl = TextEditingController();
    _pacingIntervalCtrl = TextEditingController();
    _rearWindowCtrl = TextEditingController();
    _scheduleForecastCtrl = TextEditingController();
    if (widget.teamRef != null) {
      _loadExisting();
    }
  }

  Future<void> _loadExisting() async {
    setState(() => _loading = true);
    try {
      final snap = await widget.teamRef!.get();
      if (!snap.exists) return;
      final data = snap.data();
      if (data == null) return;

      _nameCtrl.text = (data['name'] ?? data['team'] ?? '').toString();
      _descriptionCtrl.text = (data['description'] ?? '').toString();
      _frontWindowCtrl.text = _stringValue(data['frontWindow']);
      _pacingIntervalCtrl.text = _stringValue(data['pacingInterval']);
      _rearWindowCtrl.text = _stringValue(data['rearWindow']);
      _scheduleForecastCtrl.text = _stringValue(data['scheduleForecast']);
      _pacing = data['pacing'] as bool? ?? false;
      _priority = data['priority'] as bool? ?? false;
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _stringValue(dynamic value) {
    if (value == null) return '';
    if (value is num) return value.toString();
    return value.toString();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    _frontWindowCtrl.dispose();
    _pacingIntervalCtrl.dispose();
    _rearWindowCtrl.dispose();
    _scheduleForecastCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.teamRef == null ? 'Add Team' : 'Edit Team';

    return Scaffold(
      appBar: StandardAppBar(title: title),
      body: Form(
        key: _formKey,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ContainerActionWidget(
                      title: 'Team Details',
                      actionText: '',
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Team Name',
                            ),
                            textCapitalization: TextCapitalization.words,
                            validator: (value) {
                              if (value == null ||
                                  value.trim().isEmpty) {
                                return 'Team name is required.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _descriptionCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Description',
                            ),
                            textCapitalization: TextCapitalization.sentences,
                            minLines: 2,
                            maxLines: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ContainerActionWidget(
                      title: 'Pacing & Windows',
                      actionText: '',
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          CheckboxListTile(
                            value: _pacing,
                            onChanged: (value) =>
                                setState(() => _pacing = value ?? false),
                            title: const Text('Pacing'),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                          CheckboxListTile(
                            value: _priority,
                            onChanged: (value) =>
                                setState(() => _priority = value ?? false),
                            title: const Text('Priority'),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                          const SizedBox(height: 8),
                          _numberField(
                            controller: _frontWindowCtrl,
                            label: 'Front Window',
                          ),
                          const SizedBox(height: 16),
                          _numberField(
                            controller: _pacingIntervalCtrl,
                            label: 'Pacing Interval',
                          ),
                          const SizedBox(height: 16),
                          _numberField(
                            controller: _rearWindowCtrl,
                            label: 'Rear Window',
                          ),
                          const SizedBox(height: 16),
                          _numberField(
                            controller: _scheduleForecastCtrl,
                            label: 'Schedule Forecast',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ),
      bottomNavigationBar: CancelSaveBar(
        onCancel: () => Navigator.of(context).pop(),
        onSave: _saving ? null : _handleSave,
      ),
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return null;
        }
        if (int.tryParse(value.trim()) == null) {
          return 'Enter a valid number.';
        }
        return null;
      },
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    final name = _nameCtrl.text.trim();
    final description = _descriptionCtrl.text.trim();
    final frontWindow = _parseInt(_frontWindowCtrl.text);
    final pacingInterval = _parseInt(_pacingIntervalCtrl.text);
    final rearWindow = _parseInt(_rearWindowCtrl.text);
    final scheduleForecast = _parseInt(_scheduleForecastCtrl.text);

    final data = <String, dynamic>{
      'name': name,
      'pacing': _pacing,
      'priority': _priority,
    };

    if (description.isNotEmpty) {
      data['description'] = description;
    } else if (widget.teamRef != null) {
      data['description'] = FieldValue.delete();
    }

    _assignOptionalInt(data, 'frontWindow', frontWindow);
    _assignOptionalInt(data, 'pacingInterval', pacingInterval);
    _assignOptionalInt(data, 'rearWindow', rearWindow);
    _assignOptionalInt(data, 'scheduleForecast', scheduleForecast);

    try {
      await _fs.saveDocument(
        collectionRef: FirebaseFirestore.instance.collection('team'),
        data: data,
        docId: widget.teamRef?.id,
      );
      if (!mounted) return;
      Navigator.of(context).pop(HrTeamFormResult.saved);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save team: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  int? _parseInt(String? text) {
    if (text == null) return null;
    final value = text.trim();
    if (value.isEmpty) return null;
    return int.tryParse(value);
  }

  void _assignOptionalInt(
    Map<String, dynamic> target,
    String key,
    int? value,
  ) {
    if (value != null) {
      target[key] = value;
    } else if (widget.teamRef != null) {
      target[key] = FieldValue.delete();
    }
  }
}

