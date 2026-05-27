// lib/features/processes/tabs/process_info_tabs.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kleenops_admin/features/processes/details/processes_processes_details.dart';

/// Top-level screen with its own Scaffold (app bar + content + bottom nav)
class ProcessInfoTabsScreen extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final String docId;

  const ProcessInfoTabsScreen({
    super.key,
    required this.companyRef,
    required this.docId,
  });

  @override
  Widget build(BuildContext context) {
    return ProcessInfoTabs(companyRef: companyRef, docId: docId);
  }
}

class ProcessInfoTabs extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final String docId;

  const ProcessInfoTabs({
    super.key,
    required this.companyRef,
    required this.docId,
  });

  @override
  Widget build(BuildContext context) {
    return ProcessesProcessesDetails(
      companyRef: companyRef,
      docId: docId,
    );
  }
}
