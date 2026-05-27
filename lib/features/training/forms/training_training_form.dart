// features\training\forms\training_training_form.dart
//
// SKIPPED in the kleenops_admin port: this file's primary purpose is built on
// kleenops infrastructure that is intentionally stripped from the admin app
// (AI canvas / repositories / lookup-selector / portal / files / google docs
// / AITextField, etc). Restoring it would mean porting whole subsystems that
// are out of scope. A minimal class with the same constructor is exported so
// callers that import this file (e.g. training_teams.dart,
// training_employees_tabs.dart) continue to compile and can navigate to a
// "not implemented" placeholder.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TrainingTrainingForm extends StatelessWidget {
  final String? docId;
  final DocumentReference<Map<String, dynamic>> companyId;

  const TrainingTrainingForm({
    super.key,
    this.docId,
    required this.companyId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Training Form')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'The training authoring form has not been ported to the admin app yet.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
