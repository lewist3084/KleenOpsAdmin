// lib/features/hr/dialogs/add_role_dialog.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:shared_widgets/services/firestore_service.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';

class AddRoleDialog extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;

  const AddRoleDialog({
    super.key,
    required this.companyRef,
  });

  /// Shows the dialog and returns `true` if a role was created.
  static Future<bool?> show(
    BuildContext context, {
    required DocumentReference<Map<String, dynamic>> companyRef,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AddRoleDialog(companyRef: companyRef),
    );
  }

  @override
  State<AddRoleDialog> createState() => _AddRoleDialogState();
}

class _AddRoleDialogState extends State<AddRoleDialog> {
  final _nameCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() => _saving = true);
    try {
      await FirestoreService().saveDocument(
        collectionRef: FirebaseFirestore.instance.collection('role'),
        data: {'name': name},
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add role: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DialogAction(
      title: 'Add Role',
      content: TextField(
        controller: _nameCtrl,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Role Name',
          hintText: 'Enter role name',
        ),
        onSubmitted: (_) => _save(),
      ),
      cancelText: 'Cancel',
      onCancel: () => Navigator.of(context).pop(false),
      actionText: 'Save',
      onAction: _saving ? null : _save,
    );
  }
}
