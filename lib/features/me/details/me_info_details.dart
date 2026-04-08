// lib/features/me/details/me_info_details.dart
//
// Admin's own profile + onboarding view. Reads the current user's member
// document and renders a header (name + role) plus the onboarding section
// shared with the kleenops employee app. Schedule/Training/Compensation are
// intentionally not duplicated here — the admin app's HR area covers those.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/features/hr/utils/member_file_images.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/containers/container_header.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:shared_widgets/services/firestore_service.dart';

class MeInfoDetailsContent extends ConsumerWidget {
  final bool showHeader;

  const MeInfoDetailsContent({super.key, this.showHeader = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberRefAsync = ref.watch(memberDocRefProvider);
    return memberRefAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (memberRef) {
        if (memberRef == null) {
          return const Center(child: Text('Member profile not found.'));
        }
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: memberRef.snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snap.data!.data() ?? <String, dynamic>{};
            return _ProfileBody(
              memberRef: memberRef,
              data: data,
              showHeader: showHeader,
            );
          },
        );
      },
    );
  }
}

class _ProfileBody extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> memberRef;
  final Map<String, dynamic> data;
  final bool showHeader;

  const _ProfileBody({
    required this.memberRef,
    required this.data,
    required this.showHeader,
  });

  @override
  Widget build(BuildContext context) {
    final companyRef = memberRef.parent.parent;
    final name = data['name'] as String? ?? '';
    final roleRef = (data['roleId'] as DocumentReference?)
        ?.withConverter<Map<String, dynamic>>(
      fromFirestore: (s, _) => s.data()!,
      toFirestore: (m, _) => m,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader)
            FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: roleRef?.get(),
              builder: (context, roleSnap) {
                final roleName = (roleSnap.hasData && roleSnap.data!.exists)
                    ? roleSnap.data!.data()!['name'] as String? ?? ''
                    : '';
                final imageFuture = companyRef == null
                    ? Future.value('')
                    : MemberFileImages.primaryProfileImageUrl(
                        companyRef: companyRef,
                        memberId: memberRef.id,
                      );
                return FutureBuilder<String>(
                  future: imageFuture,
                  builder: (context, imageSnap) {
                    final imageUrl = imageSnap.data?.trim() ?? '';
                    return ContainerHeader(
                      image: imageUrl.isNotEmpty ? imageUrl : null,
                      images: null,
                      showImage: imageUrl.isNotEmpty,
                      titleHeader: 'Name',
                      title: name,
                      descriptionHeader: 'Role',
                      description: roleName,
                      textIcon: Icons.person_outline,
                      descriptionIcon: Icons.work_outline,
                    );
                  },
                );
              },
            ),
          MeOnboardingSection(memberRef: memberRef),
        ],
      ),
    );
  }
}

/*───────────────────────────────────────────────────────────*/
/*  Onboarding section                                       */
/*  Reads onboardingSteps from the member doc and lets the   */
/*  employee mark each step complete. Mirrors the writeback  */
/*  shape used by hr_onboarding_details.dart.                */
/*───────────────────────────────────────────────────────────*/
class MeOnboardingSection extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> memberRef;

  const MeOnboardingSection({super.key, required this.memberRef});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: memberRef.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const ContainerActionWidget(
            title: 'Onboarding',
            actionText: '',
            content: Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }
        final data = snap.data!.data() ?? <String, dynamic>{};
        final raw = data['onboardingSteps'];
        final steps = (raw is List)
            ? raw
                .whereType<Map>()
                .map((m) => Map<String, dynamic>.from(m))
                .toList()
            : <Map<String, dynamic>>[];
        steps.sort((a, b) =>
            (a['position'] as int? ?? 0).compareTo(b['position'] as int? ?? 0));

        if (steps.isEmpty) {
          return const ContainerActionWidget(
            title: 'Onboarding',
            actionText: '',
            content: Text(
              'No onboarding tasks assigned — see your supervisor.',
            ),
          );
        }

        final completedCount =
            steps.where((s) => s['status'] == 'completed').length;
        final progress = completedCount / steps.length;
        final allDone = progress >= 1.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ContainerActionWidget(
              title: allDone ? 'Onboarding Complete' : 'Onboarding Progress',
              actionText: '',
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                              allDone
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
                  const SizedBox(height: 6),
                  Text(
                    allDone
                        ? 'All steps complete. Welcome aboard!'
                        : '${(progress * 100).round()}% complete',
                    style: TextStyle(
                      fontSize: 13,
                      color: allDone ? Colors.green[700] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            ...steps.asMap().entries.map((entry) {
              final index = entry.key;
              final step = entry.value;
              return _OnboardingStepCard(
                step: step,
                onComplete: () => _markStepComplete(context, index, steps),
              );
            }),
          ],
        );
      },
    );
  }

  Future<void> _markStepComplete(
    BuildContext context,
    int stepIndex,
    List<Map<String, dynamic>> steps,
  ) async {
    final step = steps[stepIndex];
    final title = (step['title'] ?? 'this step').toString();
    final scaffold = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => DialogAction(
        title: 'Mark Complete',
        content: Text(
          'Mark "$title" as complete? Your supervisor will see this updated.',
        ),
        cancelText: 'Cancel',
        actionText: 'Mark Complete',
        onCancel: () => Navigator.of(ctx).pop(false),
        onAction: () => Navigator.of(ctx).pop(true),
      ),
    );
    if (confirmed != true) return;

    final updatedSteps =
        steps.map((s) => Map<String, dynamic>.from(s)).toList();
    updatedSteps[stepIndex]['status'] = 'completed';
    updatedSteps[stepIndex]['completedDate'] = Timestamp.now();

    final allCompleted = updatedSteps.every(
      (s) => s['status'] == 'completed' || s['status'] == 'skipped',
    );

    final payload = <String, dynamic>{
      'onboardingSteps': updatedSteps,
    };
    if (allCompleted) {
      payload['onboardingStatus'] = 'completed';
      payload['onboardingCompletedDate'] = Timestamp.now();
    }

    try {
      await FirestoreService().saveDocument(
        collectionRef: memberRef.parent,
        docId: memberRef.id,
        data: payload,
      );
    } catch (e) {
      scaffold.showSnackBar(
        SnackBar(content: Text('Failed to update step: $e')),
      );
    }
  }
}

class _OnboardingStepCard extends StatelessWidget {
  final Map<String, dynamic> step;
  final VoidCallback onComplete;

  const _OnboardingStepCard({
    required this.step,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final title = (step['title'] ?? '').toString();
    final description = (step['description'] ?? '').toString();
    final type = (step['type'] ?? 'manual').toString();
    final status = (step['status'] ?? 'pending').toString();
    final isCompleted = status == 'completed';
    final completedDate = step['completedDate'];
    final dateStr = completedDate is Timestamp
        ? DateFormat('yMMMd').format(completedDate.toDate())
        : null;

    String actionText;
    switch (type) {
      case 'form':
        actionText = 'Open Form';
        break;
      case 'document_upload':
        actionText = 'Upload';
        break;
      case 'acknowledgement':
        actionText = 'Acknowledge';
        break;
      default:
        actionText = '';
    }
    if (isCompleted) actionText = '';

    return ContainerActionWidget(
      title: title,
      actionText: actionText,
      onAction: actionText.isEmpty ? null : onComplete,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                description,
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
            ),
          Row(
            children: [
              Icon(
                isCompleted
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                size: 18,
                color: isCompleted ? Colors.green[600] : Colors.grey[500],
              ),
              const SizedBox(width: 6),
              Text(
                isCompleted && dateStr != null
                    ? 'Completed $dateStr'
                    : isCompleted
                        ? 'Completed'
                        : _stepTypeLabel(type),
                style: TextStyle(
                  fontSize: 13,
                  color: isCompleted ? Colors.green[700] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
        return 'Your supervisor will handle this';
      default:
        return 'Pending';
    }
  }
}
