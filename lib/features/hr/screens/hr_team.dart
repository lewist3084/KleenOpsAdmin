//  hr_team.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:shared_widgets/lists/standardViewGroup.dart';
import 'package:shared_widgets/tiles/standard_tile_large.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:kleenops_admin/features/hr/forms/hr_team_form.dart';
import 'package:kleenops_admin/theme/palette.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';

/// Top-level screen with its own Scaffold (app bar + content + bottom nav)
class HrTeamScreen extends StatelessWidget {
  const HrTeamScreen({super.key});

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
            title: 'HR Teams',
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
      body: _wrapCanvas(
          const HrTeamContent(),
        ),
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final menuSections = MenuDrawerSections(
            actions: [
              ContentMenuItem(
                icon: Icons.badge_outlined,
                label: 'Employees',
                onTap: () => context.push(AppRoutePaths.hrEmployees),
              ),
              ContentMenuItem(
                icon: Icons.bar_chart_outlined,
                label: 'Stats',
                onTap: () => context.push(AppRoutePaths.hrStats),
              ),
              ContentMenuItem(
                icon: Icons.qr_code_scanner,
                label: 'Scan Ticket',
                onTap: () => context.push(AppRoutePaths.hrTicketScanner),
              ),
            ],
          );
          return buildBottomBar(
            menuSections: menuSections,
          );
        },
      ),
    );
  }
}

class HrTeamContent extends StatelessWidget {
  const HrTeamContent({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteScope.of(context);
    final bool hideChrome = false;
    final bottomInset =
        (hideChrome ? 16.0 : kBottomNavigationBarHeight + 16.0) +
            MediaQuery.of(context).padding.bottom;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('User not authenticated.'));
    }

    final userRef = FirebaseFirestore.instance.collection('user').doc(user.uid);

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: userRef.get(),
      builder: (ctx, snap) {
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snap.hasData || !snap.data!.exists) {
          return const Center(child: Text('User data not found.'));
        }

        final data = snap.data!.data()!;
        final companyRef = _resolveCompanyRef(data['companyId']);
        if (companyRef == null) {
          return const Center(child: Text('Invalid company reference.'));
        }

        // Stream of teams under that company
        final teamStream =
            FirebaseFirestore.instance.collection('team').orderBy('name').snapshots();

        final list = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: StandardViewGroup(
            queryStream: teamStream,
            groupBy: (_) => '', // no grouping headers
            itemSort: (a, b) {
              final aName =
                  (a.data()['name'] ?? a.data()['team'] ?? '').toString();
              final bName =
                  (b.data()['name'] ?? b.data()['team'] ?? '').toString();
              return aName.compareTo(bName);
            },
            itemBuilder: (doc) {
              final data = doc.data();
              final String teamName =
                  (data['name'] ?? data['team'] ?? 'Unnamed Team').toString();
              final String description =
                  (data['description'] ?? '').toString().trim();
              final bool pacing = data['pacing'] as bool? ?? false;
              final bool priority = data['priority'] as bool? ?? false;
              final int? frontWindow = _asInt(data['frontWindow']);
              final int? pacingInterval = _asInt(data['pacingInterval']);
              final int? rearWindow = _asInt(data['rearWindow']);
              final int? scheduleForecast = _asInt(data['scheduleForecast']);

              String? thirdLine;
              if (pacing || priority) {
                final chips = <String>[];
                if (pacing) chips.add('Pacing');
                if (priority) chips.add('Priority');
                thirdLine = chips.join(' | ');
              }

              String? fourthLine;
              final timing = <String>[];
              if (frontWindow != null) timing.add('Front: $frontWindow');
              if (pacingInterval != null) {
                timing.add('Interval: $pacingInterval');
              }
              if (rearWindow != null) timing.add('Rear: $rearWindow');
              if (scheduleForecast != null) {
                timing.add('Forecast: $scheduleForecast');
              }
              if (timing.isNotEmpty) fourthLine = timing.join(' | ');

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: StandardTileLargeDart(
                  imageUrl: '',
                  showImage: false,
                  firstLine: teamName,
                  secondLine: description,
                  thirdLine: thirdLine,
                  fourthLine: fourthLine,
                  trailingIcon1: Icons.edit_outlined,
                  trailingAction1: () => _openTeamForm(
                    context,
                    companyRef,
                    teamRef: doc.reference,
                  ),
                ),
              );
            },
            emptyMessage: 'No teams found.',
            onTap: (doc) => _openTeamForm(
              context,
              companyRef,
              teamRef: doc.reference,
            ),
          ),
        );

        return Stack(
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: list,
            ),
            Positioned(
              right: 16,
              bottom: bottomInset,
              child: FloatingActionButton(
                backgroundColor: palette.primary1.withAlpha(220),
                onPressed: () => _openTeamForm(context, companyRef),
                tooltip: 'Add Team',
                child: const Icon(Icons.add),
              ),
            ),
          ],
        );
      },
    );
  }

  DocumentReference<Map<String, dynamic>>? _resolveCompanyRef(dynamic raw) {
    DocumentReference<Object?>? baseRef;
    if (raw is DocumentReference) {
      baseRef = raw;
    } else if (raw is String && raw.isNotEmpty) {
      final path = raw.contains('/') ? raw : 'company/$raw';
      baseRef = FirebaseFirestore.instance.doc(path);
    } else if (raw is Map) {
      final dynamic path = raw['path'] ?? raw['ref'];
      if (path is String && path.isNotEmpty) {
        baseRef = FirebaseFirestore.instance.doc(path);
      }
    }
    return baseRef?.withConverter<Map<String, dynamic>>(
      fromFirestore: (snapshot, _) => snapshot.data() ?? <String, dynamic>{},
      toFirestore: (value, _) => value,
    );
  }

  Future<void> _openTeamForm(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> companyRef, {
    DocumentReference<Map<String, dynamic>>? teamRef,
  }) async {
    final result = await context.push<HrTeamFormResult>(
      AppRoutePaths.hrTeamForm,
      extra: HrTeamFormArgs(
        companyRef: companyRef,
        teamRef: teamRef,
      ),
    );
    if (!context.mounted) return;
    if (result == HrTeamFormResult.saved) {
      final message = teamRef == null ? 'Team created.' : 'Team updated.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    final parsed = int.tryParse(value.toString());
    return parsed;
  }
}
