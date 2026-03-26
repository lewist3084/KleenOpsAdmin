// lib/features/hr/details/hrOnboardingDetails.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/services/firestore_service.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/tiles/standard_tile_small.dart';

class HrOnboardingDetailsScreen extends ConsumerWidget {
  final String documentId;
  final String name;

  factory HrOnboardingDetailsScreen.fromExtra(Map<String, dynamic>? extra) {
    final e = extra ?? {};
    return HrOnboardingDetailsScreen(
      documentId: e['documentId'] as String? ?? '',
      name: e['name'] as String? ?? '',
    );
  }

  const HrOnboardingDetailsScreen({
    super.key,
    required this.documentId,
    required this.name,
  });

  Widget _wrapCanvas(Widget child) {
    return StandardCanvas(
      child: SafeArea(
        top: true,
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(child: child),
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: CanvasTopBookend(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool hideChrome = false;

    Widget buildBottomBar({VoidCallback? onAiPressed}) {
      if (hideChrome) return const SizedBox.shrink();
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: '$name - Onboarding',
            onAiPressed: onAiPressed,
          ),
          const HomeNavBarAdapter(highlightSelected: false),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: null,
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          return buildBottomBar();
        },
      ),
      body: _wrapCanvas(
          ref.watch(companyIdProvider).when(
                data: (companyRef) {
                  if (companyRef == null) {
                    return const Center(child: Text('No company'));
                  }
                  return _OnboardingDetailsBody(
                    companyRef: companyRef,
                    documentId: documentId,
                    name: name,
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
        ),
    );
  }
}

class _OnboardingDetailsBody extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final String documentId;
  final String name;

  const _OnboardingDetailsBody({
    required this.companyRef,
    required this.documentId,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    final memberStream =
        FirebaseFirestore.instance.collection('member').doc(documentId).snapshots();
    final bottomInset =
        kBottomNavigationBarHeight + 16.0 + MediaQuery.of(context).padding.bottom;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: memberStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data?.data() ?? {};
        final steps = (data['onboardingSteps'] as List?)
                ?.map((s) => Map<String, dynamic>.from(s as Map))
                .toList() ??
            [];

        steps.sort((a, b) =>
            (a['position'] as int? ?? 0).compareTo(b['position'] as int? ?? 0));

        final completedCount =
            steps.where((s) => s['status'] == 'completed').length;
        final progress =
            steps.isNotEmpty ? completedCount / steps.length : 0.0;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Progress header ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person_outline, color: Colors.grey[700]),
                        const SizedBox(width: 8),
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 8,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                progress == 1.0
                                    ? Colors.green[600]!
                                    : Theme.of(context).primaryColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '$completedCount / ${steps.length}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      progress == 1.0
                          ? 'Onboarding complete!'
                          : '${(progress * 100).round()}% complete',
                      style: TextStyle(
                        fontSize: 13,
                        color: progress == 1.0
                            ? Colors.green[700]
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Steps list ──
              Text(
                'Onboarding Steps',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),

              ...steps.asMap().entries.map((entry) {
                final index = entry.key;
                final step = entry.value;
                final title = (step['title'] ?? '').toString();
                final status = (step['status'] ?? 'pending').toString();
                final isCompleted = status == 'completed';
                final completedDate = step['completedDate'];
                final dateStr = completedDate is Timestamp
                    ? DateFormat('yMMMd').format(completedDate.toDate())
                    : null;

                return Container(
                  margin: const EdgeInsets.only(bottom: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: index == 0
                        ? Border.all(color: Colors.grey[200]!)
                        : Border(
                            left: BorderSide(color: Colors.grey[200]!),
                            right: BorderSide(color: Colors.grey[200]!),
                            bottom: BorderSide(color: Colors.grey[200]!),
                          ),
                    borderRadius: index == 0
                        ? const BorderRadius.vertical(
                            top: Radius.circular(8))
                        : index == steps.length - 1
                            ? const BorderRadius.vertical(
                                bottom: Radius.circular(8))
                            : null,
                  ),
                  child: StandardTileSmallDart(
                    label: title,
                    secondaryText: dateStr != null
                        ? 'Completed $dateStr'
                        : _stepTypeLabel(
                            (step['type'] ?? 'manual').toString()),
                    labelIcon: isCompleted
                        ? Icons.check_circle
                        : status == 'skipped'
                            ? Icons.skip_next
                            : Icons.radio_button_unchecked,
                    trailingIcon1: isCompleted ? null : Icons.check,
                    onTrailing1Tap: isCompleted
                        ? null
                        : () => _markComplete(context, index, steps),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Future<void> _markComplete(
    BuildContext context,
    int stepIndex,
    List<Map<String, dynamic>> steps,
  ) async {
    final updatedSteps = steps.map((s) => Map<String, dynamic>.from(s)).toList();
    updatedSteps[stepIndex]['status'] = 'completed';
    updatedSteps[stepIndex]['completedDate'] = Timestamp.now();

    final allCompleted =
        updatedSteps.every((s) => s['status'] == 'completed' || s['status'] == 'skipped');

    final data = <String, dynamic>{
      'onboardingSteps': updatedSteps,
    };
    if (allCompleted) {
      data['onboardingStatus'] = 'completed';
      data['onboardingCompletedDate'] = Timestamp.now();
    }

    try {
      await FirestoreService().saveDocument(
        collectionRef: FirebaseFirestore.instance.collection('member'),
        data: data,
        docId: documentId,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update step: $e')),
        );
      }
    }
  }

  String _stepTypeLabel(String type) {
    switch (type) {
      case 'form':
        return 'Form to complete';
      case 'document_upload':
        return 'Document required';
      case 'acknowledgement':
        return 'Acknowledgement needed';
      case 'manual':
        return 'Manual step';
      default:
        return type;
    }
  }
}
