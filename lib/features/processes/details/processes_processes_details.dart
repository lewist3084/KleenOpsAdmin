// lib/features/processes/details/processes_processes_details.dart
// SKIPPED (727 lines): heavy details screen with deep dependencies on
// admin-absent widgets (chart, image rows expand) and AI canvas.
// Stub keeps tabs/process_info_tabs.dart compiling.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProcessesProcessesDetails extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final String docId;

  const ProcessesProcessesDetails({
    super.key,
    required this.companyRef,
    required this.docId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Process Details')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Process details for $docId — pending full port.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
