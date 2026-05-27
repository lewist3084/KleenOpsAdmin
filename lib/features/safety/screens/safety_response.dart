// lib/features/safety/screens/safety_response_content.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:shared_widgets/tiles/standard_tile_small.dart';
import 'package:kleenops_admin/app/shared_widgets/search/search_control_strip_adapter.dart';
import 'package:shared_widgets/lists/standardView.dart';
import 'package:shared_widgets/utils/process_localization_utils.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/services/ai/ai_context_service.dart';
import 'package:kleenops_admin/widgets/ai/ai_screen_context.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';

/// Top-level screen with its own Scaffold (app bar + content + bottom nav)
class SafetyResponseScreen extends StatefulWidget {
  const SafetyResponseScreen({super.key});

  @override
  State<SafetyResponseScreen> createState() => _SafetyResponseScreenState();
}

class _SafetyResponseScreenState extends State<SafetyResponseScreen> {
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
            title: 'Safety Response',
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
        context: AiContextPresets.safetyResponse(),
        child: _wrapCanvas(
          SafetyResponseContent(searchVisible: _searchVisible),
        ),
      ),
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final controller = ref.read(aiCanvasControllerProvider);
          final menuSections = MenuDrawerSections(
            actions: [
              ContentMenuItem(
                icon: Icons.analytics_outlined,
                label: 'Analysis',
                onTap: () => context.push(AppRoutePaths.safetyAnalysis),
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

class SafetyResponseContent extends ConsumerStatefulWidget {
  const SafetyResponseContent({super.key, this.searchVisible = false});

  final bool searchVisible;

  @override
  ConsumerState<SafetyResponseContent> createState() =>
      _SafetyResponseContentState();
}

class _SafetyResponseContentState
    extends ConsumerState<SafetyResponseContent> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
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
            .collection('companyObject')
            .where('safetyResponse', isEqualTo: true)
            .snapshots();

        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Column(
            children: [
              if (widget.searchVisible)
                SearchControlStrip(
                  controller: _searchController,
                  hintText: 'Search Objects',
                  onChanged: (val) => setState(() => _searchQuery = val),
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
                    final safetyLocaleCode =
                        Localizations.localeOf(context).toString();
                    final filtered = docs.where((doc) {
                      final name = ProcessLocalizationUtils.resolveLocalizedText(
                        doc.data()['localName'],
                        localeCode: safetyLocaleCode,
                      ).toLowerCase();
                      return name.contains(_searchQuery.toLowerCase());
                    }).toList()
                      ..sort((a, b) {
                        final an = ProcessLocalizationUtils.resolveLocalizedText(
                          a.data()['localName'],
                          localeCode: safetyLocaleCode,
                        ).toLowerCase();
                        final bn = ProcessLocalizationUtils.resolveLocalizedText(
                          b.data()['localName'],
                          localeCode: safetyLocaleCode,
                        ).toLowerCase();
                        return an.compareTo(bn);
                      });

                    if (filtered.isEmpty) {
                      return Center(
                        child: Text(_searchQuery.isEmpty
                            ? 'No safety response objects found.'
                            : 'No objects match "$_searchQuery".'),
                      );
                    }

                    return StandardView<
                        QueryDocumentSnapshot<Map<String, dynamic>>>(
                      items: filtered,
                      groupBy: (_) => '',
                      disableGrouping: true,
                      itemBuilder: (doc) {
                        final data = doc.data();
                        final resolved =
                            ProcessLocalizationUtils.resolveLocalizedText(
                          data['localName'],
                          localeCode: safetyLocaleCode,
                        ).trim();
                        final name = resolved.isEmpty ? 'Unnamed' : resolved;
                        return StandardTileSmallDart.iconText(
                          leadingicon: Icons.list_alt_outlined,
                          text: name,
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

