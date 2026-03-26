import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:kleenops_admin/features/finances/services/finance_account_service.dart';

/// Shows a dialog allowing the user to create a child account under [parentAccountRef].
Future<void> showAddChildAccountDialog({
  required BuildContext context,
  required DocumentReference<Map<String, dynamic>> companyRef,
  required DocumentReference<Map<String, dynamic>> parentAccountRef,
}) async {
  final ctrl = TextEditingController();
  final formKey = GlobalKey<FormState>();

  await showDialog(
    context: context,
    builder: (c) {
      return DialogAction(
        title: 'Add Child Account',
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            decoration: const InputDecoration(labelText: 'Name'),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Enter name' : null,
          ),
        ),
        cancelText: 'Cancel',
        onCancel: () => Navigator.pop(c),
        actionText: 'Add',
        onAction: () async {
          if (formKey.currentState?.validate() != true) return;

          final accountService = FinanceAccountService();
          await accountService.createAccount(
            companyRef: companyRef,
            name: ctrl.text,
            parentAccountRef: parentAccountRef,
          );
          if (!c.mounted) return;
          Navigator.pop(c);
        },
      );
    },
  );
}
