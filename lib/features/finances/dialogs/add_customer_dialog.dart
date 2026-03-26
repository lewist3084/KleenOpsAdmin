// lib/features/finances/dialogs/add_customer_dialog.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:kleenops_admin/services/firestore_service.dart';

/// Shows a quick-add dialog to create a customer with just a name.
Future<DocumentReference<Map<String, dynamic>>?> showAddCustomerDialog({
  required BuildContext context,
  required DocumentReference<Map<String, dynamic>> companyRef,
}) async {
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();
  DocumentReference<Map<String, dynamic>>? result;

  await showDialog(
    context: context,
    builder: (c) {
      return DialogAction(
        title: 'Add Customer',
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Customer Name'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        cancelText: 'Cancel',
        onCancel: () => Navigator.pop(c),
        actionText: 'Add',
        onAction: () async {
          if (formKey.currentState?.validate() != true) return;

          final collection = FirebaseFirestore.instance.collection('customer');
          final docRef = collection.doc();
          final data = <String, dynamic>{
            'name': nameCtrl.text.trim(),
            'email': emailCtrl.text.trim(),
            'phone': phoneCtrl.text.trim(),
            'active': true,
            'balance': 0,
          };

          await FirestoreService().saveDocument(
            collectionRef: collection,
            data: data,
            docId: docRef.id,
          );

          result = docRef;
          if (!c.mounted) return;
          Navigator.pop(c);
        },
      );
    },
  );

  nameCtrl.dispose();
  emailCtrl.dispose();
  phoneCtrl.dispose();
  return result;
}
