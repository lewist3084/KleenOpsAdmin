// lib/features/training/screens/training_teams.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/features/training/tabs/training_employees_tabs.dart';
import 'package:kleenops_admin/services/ai/ai_context_service.dart';
import 'package:kleenops_admin/widgets/ai/ai_screen_context.dart';
import 'package:shared_widgets/lists/standardViewGroup.dart';
import 'package:shared_widgets/buttons/pill_button.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:shared_widgets/tiles/standard_tile_large.dart';

import '../forms/training_training_form.dart';

/// Top-level screen with its own Scaffold (app bar + content + bottom nav)
class TrainingTeamsScreen extends StatelessWidget {
  const TrainingTeamsScreen({super.key});

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
  Widget build(BuildContext context) {
    final bool hideChrome = false;

    Widget buildBottomBar({
      VoidCallback? onAiPressed,
      MenuDrawerSections? menuSections,
    }) {
      if (hideChrome) return const SizedBox.shrink();
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: 'Training Teams',
            onAiPressed: onAiPressed,
            menuSections: menuSections,
          ),
          const HomeNavBarAdapter(),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: null,
      drawer: const UserDrawer(),
      body: AiScreenContext(
        context: AiContextPresets.trainingTeams(),
        child: _wrapCanvas(
          const TrainingTeamsContent(),
        ),
      ),
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final controller = ref.read(aiCanvasControllerProvider);
          final companyRef = ref.watch(companyIdProvider).value;
          final menuSections = MenuDrawerSections(
            actions: [
              ContentMenuItem(
                icon: Icons.menu_book_outlined,
                label: 'Library',
                onTap: () => context.push(AppRoutePaths.trainingStats),
              ),
              ContentMenuItem(
                icon: Icons.add,
                label: 'New Training',
                onTap: () {
                  if (companyRef == null) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TrainingTrainingForm(
                        companyId: companyRef,
                      ),
                    ),
                  );
                },
              ),
            ],
          );
          return buildBottomBar(
            onAiPressed: controller.toggle,
            menuSections: menuSections,
          );
        },
      ),
    );
  }
}

class TrainingTeamsContent extends ConsumerWidget {
  const TrainingTeamsContent({super.key});

  static const List<String> _trainingPercentKeys = <String>[
    'trainingCompletionPercent',
    'trainingPercent',
    'trainingCompletion',
    'trainingCompliancePercent',
    'trainingCompliance',
  ];

  static const List<String> _trainingRenewalKeys = <String>[
    'trainingRenewalCount',
    'trainingExpiringSoonCount',
    'trainingExpiringCount',
    'expiringTrainingSoonCount',
    'expiringTrainingCount',
    'expiringTrainings',
    'trainingExpiringSoon',
    'trainingExpiring',
  ];

  static const List<String> _trainingOverdueKeys = <String>[
    'trainingOverdueCount',
    'trainingExpiredCount',
    'trainingPastDueCount',
    'trainingOverdue',
    'trainingExpired',
  ];

  List<DocumentReference<Map<String, dynamic>>> _resolveTeamRefs(
    DocumentReference<Map<String, dynamic>> companyRef,
    List<dynamic> rawAccess,
  ) {
    final seen = <String>{};
    return rawAccess
        .map((entry) {
          if (entry is DocumentReference) {
            return entry.withConverter<Map<String, dynamic>>(
              fromFirestore: (s, _) => s.data() ?? <String, dynamic>{},
              toFirestore: (m, _) => m,
            );
          }
          if (entry is String && entry.isNotEmpty) {
            return companyRef
                .collection('team')
                .doc(entry)
                .withConverter<Map<String, dynamic>>(
                  fromFirestore: (s, _) => s.data() ?? <String, dynamic>{},
                  toFirestore: (m, _) => m,
                );
          }
          return null;
        })
        .whereType<DocumentReference<Map<String, dynamic>>>()
        .where((ref) => seen.add(ref.path))
        .toList();
  }

  double? _parsePercent(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) {
      final double value = raw.toDouble();
      if (value.isNaN || value.isInfinite) return null;
      if (value >= 0 && value <= 1) return value * 100;
      return value;
    }
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      final sanitized = trimmed.endsWith('%')
          ? trimmed.substring(0, trimmed.length - 1).trim()
          : trimmed;
      final double? parsed = double.tryParse(sanitized);
      if (parsed == null) return null;
      if (parsed >= 0 && parsed <= 1) return parsed * 100;
      return parsed;
    }
    return null;
  }

  double? _resolvePercent(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final double? parsed = _parsePercent(data[key]);
      if (parsed != null) return parsed;
    }
    return null;
  }

  int? _parseCount(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw >= 0 ? raw : null;
    if (raw is num) {
      final double value = raw.toDouble();
      if (value.isNaN || value.isInfinite) return null;
      final int resolved = value.toInt();
      return resolved >= 0 ? resolved : null;
    }
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      final int? parsed = int.tryParse(trimmed);
      if (parsed != null) return parsed >= 0 ? parsed : null;
      final double? parsedDouble = double.tryParse(trimmed);
      if (parsedDouble == null) return null;
      final int resolved = parsedDouble.toInt();
      return resolved >= 0 ? resolved : null;
    }
    return null;
  }

  int? _resolveCount(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final int? parsed = _parseCount(data[key]);
      if (parsed != null) return parsed;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(userDocumentProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('User error: $e')),
          data: (user) {
            final companyRef = user['companyId'] as DocumentReference?;
            if (companyRef == null) {
              return const Center(child: Text('No company assigned.'));
            }

            final typedCompanyRef =
                companyRef.withConverter<Map<String, dynamic>>(
              fromFirestore: (s, _) => s.data() ?? <String, dynamic>{},
              toFirestore: (m, _) => m,
            );

            final rawAccess =
                (user['teamAccess'] as List<dynamic>? ?? <dynamic>[]);
            final teamRefs = _resolveTeamRefs(typedCompanyRef, rawAccess);
            if (teamRefs.isEmpty) {
              return const Center(child: Text('No teams found.'));
            }

            final teamIds = teamRefs.map((r) => r.id).toList();
            final teamsQuery = typedCompanyRef
                .collection('team')
                .where(FieldPath.documentId, whereIn: teamIds)
                .snapshots();

            const bottomInset = 16.0;

            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: StandardViewGroup(
                queryStream: teamsQuery,
                emptyMessage: 'No teams found.',
                groupBy: (_) => '',
                itemSort: (a, b) {
                  final an = ((a.data()['name'] ?? a.data()['team']) ?? a.id)
                      .toString()
                      .toLowerCase();
                  final bn = ((b.data()['name'] ?? b.data()['team']) ?? b.id)
                      .toString()
                      .toLowerCase();
                  return an.compareTo(bn);
                },
                onTap: (doc) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      settings: RouteSettings(
                        name: '/training/team/${doc.id}',
                      ),
                      builder: (_) => TrainingEmployeesTabsScreen(
                        teamId: doc.id,
                      ),
                    ),
                  );
                },
                itemBuilder: (doc) {
                  final data = doc.data();
                  final name = (data['name'] as String?) ??
                      (data['team'] as String?) ??
                      doc.id;
                  final teamRef = doc.reference;

                  final membersQuery = typedCompanyRef
                      .collection('member')
                      .where('active', isEqualTo: true)
                      .where('primaryTeamId', isEqualTo: teamRef);

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: membersQuery.snapshots(),
                    builder: (context, snapshot) {
                      final memberDocs = snapshot.data?.docs ?? [];
                      final int? memberCount =
                          snapshot.hasData ? memberDocs.length : null;
                      final memberLabel = memberCount == null
                          ? 'Members: --'
                          : 'Members: $memberCount';
                      final double? completionPercentRaw =
                          _resolvePercent(data, _trainingPercentKeys);
                      final double? completionPercent =
                          completionPercentRaw == null
                              ? null
                              : completionPercentRaw.roundToDouble();
                      final int? renewalCount =
                          _resolveCount(data, _trainingRenewalKeys);
                      final int? overdueCount =
                          _resolveCount(data, _trainingOverdueKeys);
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 6.0),
                        child: StandardTileLargeDart(
                          imageUrl: '',
                          firstLine: name,
                          firstLineIcon: Icons.group,
                          firstLineTrailing: TrainingPillButtonDart(
                            completionPercent: completionPercent,
                            renewalCount: renewalCount,
                            overdueCount: overdueCount,
                          ),
                          secondLine: memberLabel,
                          secondLineIcon: Icons.people_outline,
                          showImage: false,
                        ),
                      );
                    },
                  );
                },
              ),
            );
          },
        );
  }
}
