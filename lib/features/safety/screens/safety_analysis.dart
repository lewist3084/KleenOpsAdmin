// lib/features/safety/screens/safety_analysis_content.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:shared_widgets/lists/standardView.dart';
import 'package:shared_widgets/tiles/standard_tile_small.dart';
import 'package:kleenops_admin/app/shared_widgets/search/search_control_strip_adapter.dart';
import '../details/safety_analysis_details.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/services/ai/ai_context_service.dart';
import 'package:kleenops_admin/widgets/ai/ai_screen_context.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:shared_widgets/utils/process_localization_utils.dart';

/// Top-level screen with its own Scaffold (app bar + content + bottom nav)
class SafetyAnalysisScreen extends StatefulWidget {
  const SafetyAnalysisScreen({super.key});

  @override
  State<SafetyAnalysisScreen> createState() => _SafetyAnalysisScreenState();
}

class _SafetyAnalysisScreenState extends State<SafetyAnalysisScreen> {
  bool _searchVisible = false;

  void _toggleSearch() => setState(() => _searchVisible = !_searchVisible);

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
            title: 'Safety Analysis',
            onAiPressed: onAiPressed,
            menuSections: menuSections,
            showSearchToggle: true,
            searchActive: _searchVisible,
            onSearchToggle: _toggleSearch,
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
        context: AiContextPresets.safetyAnalysis(),
        child: _wrapCanvas(
          SafetyAnalysisContent(searchVisible: _searchVisible),
        ),
      ),
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final controller = ref.read(aiCanvasControllerProvider);
          final menuSections = MenuDrawerSections(
            actions: [
              ContentMenuItem(
                icon: Icons.health_and_safety_outlined,
                label: 'Response',
                onTap: () => context.push(AppRoutePaths.safetyResponse),
              ),
              ContentMenuItem(
                icon: Icons.bar_chart_outlined,
                label: 'Stats',
                onTap: () => context.push(AppRoutePaths.safetyStats),
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

class SafetyAnalysisContent extends ConsumerStatefulWidget {
  const SafetyAnalysisContent({super.key, this.searchVisible = false});

  final bool searchVisible;

  @override
  ConsumerState<SafetyAnalysisContent> createState() =>
      _SafetyAnalysisContentState();
}

class _SafetyAnalysisContentState
    extends ConsumerState<SafetyAnalysisContent> {
  final TextEditingController _searchCtl = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final companyRefAsync = ref.watch(companyIdProvider);
    const bottomInset = 16.0;

    return companyRefAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading company: $e')),
      data: (companyRef) {
        if (companyRef == null) {
          return const Center(child: Text('No company found.'));
        }

        final queryStream = companyRef
            .collection('task')
            .where('safetyAnalysis', isEqualTo: true)
            .orderBy('name')
            .snapshots();

        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Column(
            children: [
              if (widget.searchVisible)
                SearchControlStrip(
                  controller: _searchCtl,
                  hintText: 'Search Tasks',
                  onChanged: (t) =>
                      setState(() => _search = t.toLowerCase().trim()),
                ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: queryStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    final docs = snapshot.data?.docs ?? [];
                    final filtered = docs.where((doc) {
                      final name =
                          (doc.data()['name'] ?? '').toString().toLowerCase();
                      return name.contains(_search);
                    }).toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Text(
                          _search.isEmpty
                              ? 'No safety analysis tasks found.'
                              : 'No tasks match "$_search".',
                        ),
                      );
                    }

                    return StandardView<
                        QueryDocumentSnapshot<Map<String, dynamic>>>(
                      items: filtered,
                      groupBy: (_) => '',
                      disableGrouping: true,
                      onTap: (doc) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SafetyAnalysisDetailsScreen(
                              companyRef: companyRef,
                              docId: doc.id,
                            ),
                          ),
                        );
                      },
                      itemBuilder: (doc) {
                        final data = doc.data();
                        final localeCode =
                            Localizations.localeOf(context).languageCode;
                        final resolvedName =
                            ProcessLocalizationUtils.resolveLocalizedText(
                          data['name'],
                          localeCode: localeCode,
                          fallbackLocaleCode:
                              ProcessLocalizationUtils.defaultLocaleCode,
                        );
                        final name =
                            resolvedName.isNotEmpty ? resolvedName : 'Unnamed';
                        return FutureBuilder<num>(
                          future: _loadTaskMaxPrn(doc.reference, companyRef),
                          builder: (context, snap) {
                            final prn = snap.data ?? 0;
                            return StandardTileSmallDart.iconText(
                              leadingicon: Icons.list_alt_outlined,
                              text: name,
                              secondText: 'PRN $prn',
                            );
                          },
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

  Future<num> _loadTaskMaxPrn(
      DocumentReference<Map<String, dynamic>> taskRef,
      DocumentReference<Map<String, dynamic>> companyRef) async {
    final processSnap = await companyRef
        .collection('objectProcessTask')
        .where('taskId', isEqualTo: taskRef)
        .get();

    num taskMax = 0;
    for (final processDoc in processSnap.docs) {
      final failureModeSnap = await companyRef
          .collection('failureMode')
          .where('objectProcessTaskId', isEqualTo: processDoc.reference)
          .get();

      for (final fmDoc in failureModeSnap.docs) {
        final fmData = fmDoc.data();
        final sevRef = fmData['severityId']
            as DocumentReference<Map<String, dynamic>>?;
        final sevSnap = await sevRef?.get();
        final sevData = sevSnap?.data();
        final sevPos = (sevData?['position'] as num?) ?? 0;

        final pcSnap = await companyRef
            .collection('failureModePotentialCause')
            .where('failureModeId', isEqualTo: fmDoc.reference)
            .get();

        for (final pcDoc in pcSnap.docs) {
          final pcData = pcDoc.data();
          final occRef = pcData['occurrenceId']
              as DocumentReference<Map<String, dynamic>>?;
          final detRef = pcData['detectionId']
              as DocumentReference<Map<String, dynamic>>?;
          final occSnap = await occRef?.get();
          final detSnap = await detRef?.get();
          final occData = occSnap?.data();
          final detData = detSnap?.data();
          final occPos = (occData?['position'] as num?) ?? 0;
          final detPos = (detData?['position'] as num?) ?? 0;
          final prn = sevPos * occPos * detPos;
          if (prn > taskMax) taskMax = prn;
        }
      }
    }

    return taskMax;
  }
}

