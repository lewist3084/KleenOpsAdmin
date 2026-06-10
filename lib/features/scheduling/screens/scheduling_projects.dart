// lib/features/scheduling/screens/scheduling_projects.dart
//
// Roster of scheduling "projects" (companyRef/project). Tasks can be assigned a
// project, so this list is reached from the scheduling Resources drawer entry
// ("Projects"). It owns the `/scheduling/projects` location and pins its bottom
// nav to a Home/Projects bar (section:'projects'). Mirrors the kleenops screen.
//
// - FAB → blank project form (create).
// - Tap a tile → project detail screen (which has its own edit FAB).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/lists/standardViewGroup.dart';
import 'package:shared_widgets/tiles/standard_tile_large.dart';

class SchedulingProjectsScreen extends StatelessWidget {
  const SchedulingProjectsScreen({super.key});

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
    return Scaffold(
      appBar: null,
      drawer: const UserDrawer(),
      body: _wrapCanvas(const _SchedulingProjectsContent()),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          DetailsAppBar(title: 'Projects'),
          HomeNavBarAdapter(section: 'projects'),
        ],
      ),
    );
  }
}

class _SchedulingProjectsContent extends ConsumerWidget {
  const _SchedulingProjectsContent();

  String _nameOf(Map<String, dynamic> m, String fallback) {
    final name = (m['name'] as String?)?.trim();
    return (name != null && name.isNotEmpty) ? name : fallback;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyRefAsync = ref.watch(companyIdProvider);

    return companyRefAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (companyRef) {
        if (companyRef == null) {
          return const Center(child: Text('No company reference for user.'));
        }

        final query = companyRef
            .collection('project')
            .withConverter<Map<String, dynamic>>(
              fromFirestore: (s, _) => s.data() ?? <String, dynamic>{},
              toFirestore: (d, _) => d,
            );

        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton(
            heroTag: null,
            onPressed: () => context.push(AppRoutePaths.schedulingProjectForm),
            child: const Icon(Icons.add),
          ),
          body: SafeArea(
            top: false,
            bottom: false,
            child: StandardViewGroup(
              queryStream: query.snapshots(),
              emptyMessage: 'No projects yet. Tap + to add one.',
              disableGrouping: true,
              groupBy: (_) => '',
              itemSort: (a, b) {
                final an = _nameOf(a.data(), a.id).toLowerCase();
                final bn = _nameOf(b.data(), b.id).toLowerCase();
                return an.compareTo(bn);
              },
              onSwipeRight: (doc) async {
                final original = Map<String, dynamic>.from(doc.data());
                final reference = doc.reference;
                await reference.delete();
                SnackbarService.instance.showSnackBar(
                  SnackBar(
                    content: const Text('Project deleted'),
                    duration: const Duration(seconds: 5),
                    action: SnackBarAction(
                      label: 'UNDO',
                      onPressed: () async => reference.set(original),
                    ),
                  ),
                );
              },
              itemBuilder: (doc) {
                final m = doc.data();
                final name = _nameOf(m, '(untitled project)');
                final description = (m['description'] as String?)?.trim() ?? '';
                return StandardTileLargeDart(
                  imageUrl: '',
                  showImage: false,
                  firstLine: name,
                  firstLineIcon: Icons.folder_special,
                  secondLine: description,
                  trailingIcon1: Icons.chevron_right,
                  trailingAction1: () => context.push(
                    '${AppRoutePaths.schedulingProjectDetails}?docId=${doc.id}',
                  ),
                );
              },
              onTap: (doc) => context.push(
                '${AppRoutePaths.schedulingProjectDetails}?docId=${doc.id}',
              ),
            ),
          ),
        );
      },
    );
  }
}
