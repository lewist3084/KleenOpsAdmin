// lib/features/me/screens/my_tasks_screen.dart
//
// Global "My Tasks" inbox. Shows pending action items written to
// `company/{cid}/member/{mid}/myTask/{taskId}` for the signed-in member.
//
// Each task carries a `routePath` so tapping it deep-links to the source
// screen (e.g. absence approvals list). Tasks auto-complete via the
// backend triggers that own the underlying workflow.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/services/ai/ai_context_service.dart';
import 'package:kleenops_admin/widgets/layout/bookended_canvas.dart';

class MyTasksScreen extends ConsumerWidget {
  const MyTasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(aiCanvasControllerProvider);
    final companyAsync = ref.watch(companyIdProvider);
    final memberAsync = ref.watch(memberDocRefProvider);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: 'My Tasks',
            onAiPressed: controller.toggle,
          ),
          const HomeNavBarAdapter(highlightSelected: false),
        ],
      ),
      body: BookendedCanvas(
        child: companyAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (companyRef) {
            if (companyRef == null) {
              return const Center(child: Text('No company selected.'));
            }
            return memberAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (memberRef) {
                if (memberRef == null) {
                  return const Center(child: Text('No member found.'));
                }
                return _MyTasksList(memberRef: memberRef);
              },
            );
          },
        ),
      ),
    );
  }
}

class _MyTasksList extends StatelessWidget {
  const _MyTasksList({required this.memberRef});

  final DocumentReference<Map<String, dynamic>> memberRef;

  @override
  Widget build(BuildContext context) {
    final stream = memberRef
        .collection('myTask')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No tasks waiting on you.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }
        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final doc = docs[i];
            return _MyTaskRow(docRef: doc.reference, data: doc.data());
          },
        );
      },
    );
  }
}

class _MyTaskRow extends StatelessWidget {
  const _MyTaskRow({required this.docRef, required this.data});

  final DocumentReference<Map<String, dynamic>> docRef;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final title = (data['title'] ?? '').toString();
    final description = (data['description'] ?? '').toString();
    final routePath = (data['routePath'] ?? '').toString();
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final fmt = DateFormat.yMMMd().add_jm();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: routePath.isEmpty
            ? null
            : () => GoRouter.of(context).push(routePath),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.task_alt, size: 18, color: Colors.blueGrey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title.isEmpty ? 'Task' : title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (createdAt != null)
                    Text(
                      fmt.format(createdAt),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                ],
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(description, style: const TextStyle(color: Colors.black87)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

