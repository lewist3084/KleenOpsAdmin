// lib/features/scheduling/details/scheduling_project_details.dart
//
// Read-only detail view for a scheduling "project". The edit FAB opens the
// same form the list's "+" uses, seeded with this project's docId. Mirrors the
// kleenops screen.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:kleenops_admin/widgets/layout/bookended_canvas.dart';

class SchedulingProjectDetails extends StatelessWidget {
  const SchedulingProjectDetails({
    super.key,
    required this.companyId,
    required this.docId,
  });

  final DocumentReference companyId;
  final String docId;

  @override
  Widget build(BuildContext context) {
    final docRef = companyId.collection('project').doc(docId).withConverter<
        Map<String, dynamic>>(
      fromFirestore: (s, _) => s.data() ?? <String, dynamic>{},
      toFirestore: (m, _) => m,
    );

    return Scaffold(
      body: BookendedCanvas(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: docRef.snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(child: Text('Error: ${snap.error}'));
            }
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snap.hasData || !snap.data!.exists) {
              return const Center(child: Text('Project not found.'));
            }
            final m = snap.data!.data() ?? <String, dynamic>{};
            final name = (m['name'] as String?)?.trim() ?? '';
            final description = (m['description'] as String?)?.trim() ?? '';

            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ContainerActionWidget(
                    actionText: '',
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.folder_special, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                name.isNotEmpty ? name : '(untitled project)',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            description,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: () => context.push(
          '${AppRoutePaths.schedulingProjectForm}?docId=$docId',
        ),
        child: const Icon(Icons.edit),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          DetailsAppBar(title: 'Project Details'),
          HomeNavBarAdapter(section: 'projects', highlightSelected: false),
        ],
      ),
      drawer: const UserDrawer(),
    );
  }
}
