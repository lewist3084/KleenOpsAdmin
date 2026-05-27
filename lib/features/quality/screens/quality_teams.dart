// lib/features/quality/screens/quality_teams.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/features/quality/tabs/inspection_tabs.dart';
import 'package:kleenops_admin/services/ai/ai_context_service.dart';
import 'package:kleenops_admin/widgets/ai/ai_screen_context.dart';
import 'package:shared_widgets/lists/standardViewGroup.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:shared_widgets/tiles/standard_tile_large.dart';

/// Top-level screen with its own Scaffold (app bar + content + bottom nav)
class QualityTeamsScreen extends StatelessWidget {
  const QualityTeamsScreen({super.key});

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
            title: 'Quality Teams',
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
        context: AiContextPresets.qualityTeams(),
        child: _wrapCanvas(
          const QualityTeamsContent(),
        ),
      ),
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final controller = ref.read(aiCanvasControllerProvider);
          final menuSections = MenuDrawerSections(
            actions: [
              ContentMenuItem(
                icon: Icons.bar_chart_outlined,
                label: 'Stats',
                onTap: () => context.push(AppRoutePaths.qualityStats),
              ),
              ContentMenuItem(
                icon: Icons.home_outlined,
                label: 'Quality Home',
                onTap: () => context.push(AppRoutePaths.qualityHome),
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

class QualityTeamsContent extends ConsumerWidget {
  const QualityTeamsContent({super.key});

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
            return FirebaseFirestore.instance.collection('team').doc(entry)
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

        final typedCompanyRef = companyRef.withConverter<Map<String, dynamic>>(
          fromFirestore: (s, _) => s.data() ?? <String, dynamic>{},
          toFirestore: (m, _) => m,
        );

        final rawAccess = (user['teamAccess'] as List<dynamic>? ?? <dynamic>[]);
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
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          settings: const RouteSettings(
                            name: '/quality/inspections',
                          ),
                          builder: (_) => const InspectionTabsScreen(),
                        ),
                      );
                    },
                    child: const StandardTileLargeDart(
                      imageUrl: '',
                      firstLine: 'All Teams',
                      firstLineIcon: Icons.groups,
                      secondLine: 'View inspections across every team',
                      secondLineIcon: Icons.visibility_outlined,
                      showImage: false,
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
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
                    name: '/quality/team/${doc.id}',
                  ),
                  builder: (_) => InspectionTabsScreen(
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
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8.0, vertical: 6.0),
                    child: StandardTileLargeDart(
                      imageUrl: '',
                      firstLine: name,
                      firstLineIcon: Icons.group,
                      secondLine: memberLabel,
                      secondLineIcon: Icons.people_outline,
                      showImage: false,
                    ),
                  );
                },
              );
            },
          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

