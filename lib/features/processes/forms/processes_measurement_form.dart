import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/forms/cancel_save_adapter.dart';
import 'package:kleenops_admin/widgets/layout/bookended_canvas.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';

class ProcessesMeasurementForm extends ConsumerStatefulWidget {
  final DocumentReference companyId;
  final String? docId;

  const ProcessesMeasurementForm({
    super.key,
    required this.companyId,
    this.docId,
  });

  @override
  ConsumerState<ProcessesMeasurementForm> createState() =>
      _ProcessesMeasurementFormState();
}

class _ProcessesMeasurementFormState
    extends ConsumerState<ProcessesMeasurementForm> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.docId != null) {
      _loadExisting();
    } else {
      _loading = false;
    }
  }

  Future<void> _loadExisting() async {
    final doc = await widget.companyId
        .collection('processMeasurement')
        .doc(widget.docId)
        .get();
    if (doc.exists) {
      final data = doc.data()!;
      _nameController.text = data['name'] as String? ?? '';
      _descriptionController.text = data['description'] as String? ?? '';
    }
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final desc = _descriptionController.text.trim();
    if (name.isEmpty) {
      SnackbarService.instance.showSnackBar(
        SnackBar(duration: const Duration(seconds: 5), content: const Text('Name is required')),
      );
      return;
    }
    setState(() => _saving = true);
    final data = {'name': name, 'description': desc};
    final collection = widget.companyId.collection('processMeasurement');
    if (widget.docId == null) {
      await collection.add(data);
    } else {
      await collection.doc(widget.docId).set(data, SetOptions(merge: true));
    }
    if (mounted) Navigator.of(context).pop();
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      body: BookendedCanvas(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                textInputAction: TextInputAction.next,
                onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                textInputAction: TextInputAction.done,
                onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CancelSaveBar(
            onCancel: () => Navigator.of(context).pop(),
            onSave: _saving ? null : _save,
            reserveNavBarSpace: false,
          ),
          const DetailsAppBar(title: 'Measurement'),
          const HomeNavBarAdapter(),
        ],
      ),
    );
  }
}
