// lib/features/purchasing/forms/vendor_form.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:shared_widgets/services/firestore_service.dart';
import 'package:kleenops_admin/app/shared_widgets/forms/cancel_save_adapter.dart';

class VendorForm extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyId;
  final DocumentReference<Map<String, dynamic>> vendorRef;

  const VendorForm({
    super.key,
    required this.companyId,
    required this.vendorRef,
  });

  @override
  State<VendorForm> createState() => _VendorFormState();
}

class _VendorFormState extends State<VendorForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  bool _saving = false;
  late final String _aiContextKey =
      'purchasing_vendor_contact_form:${widget.vendorRef.id}';

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final col  = widget.companyId.collection('contact');
    final meta = await FirestoreService().buildCreateMeta(col);
    await col.add({
      'name': _nameController.text.trim(),
      'companyCompanyId': widget.vendorRef,
      // Store the company id as a camel-case text reference
      'companyIdCamelText': widget.companyId.id,
      ...meta,
    });

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const StandardAppBar(title: 'New Contact'),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Name'),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please enter a name';
              }
              return null;
            },
          ),
        ),
      ),
      bottomNavigationBar: CancelSaveBar(
        onCancel: () => Navigator.of(context).pop(),
        onSave: _saving ? null : _save,
        isSaving: _saving,
      ),
    );
  }
}
