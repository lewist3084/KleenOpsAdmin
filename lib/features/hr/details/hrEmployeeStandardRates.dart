// lib/features/hr/details/hrEmployeeStandardRates.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_appbar_adapter.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:shared_widgets/lists/standardViewGroup.dart';
import 'package:shared_widgets/tiles/standard_tile_small.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';

class HrEmployeeStandardRatesScreen extends ConsumerWidget {
  const HrEmployeeStandardRatesScreen({super.key});

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
    final companyRefAsync = ref.watch(companyIdProvider);
    final bool hideChrome = false;

    Widget buildBottomBar({VoidCallback? onAiPressed}) {
      if (hideChrome) return const SizedBox.shrink();
      final menuSections = MenuDrawerSections(
        actions: [
          ContentMenuItem(
            icon: Icons.badge_outlined,
            label: 'Employees',
            onTap: () => context.push(AppRoutePaths.hrEmployees),
          ),
          ContentMenuItem(
            icon: Icons.groups_outlined,
            label: 'Teams',
            onTap: () => context.push(AppRoutePaths.hrTeam),
          ),
          ContentMenuItem(
            icon: Icons.bar_chart_outlined,
            label: 'Stats',
            onTap: () => context.push(AppRoutePaths.hrStats),
          ),
        ],
      );

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: 'Standard Rates',
            onAiPressed: onAiPressed,
            menuSections: menuSections,
          ),
          const HomeNavBarAdapter(highlightSelected: false),
        ],
      );
    }

    final body = companyRefAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error loading company: $err')),
      data: (companyRef) {
        if (companyRef == null) {
          return const Center(child: Text('No company found.'));
        }

        final ratesStream =
            FirebaseFirestore.instance.collection('standardLarborRates').snapshots();

        final bottomPadding =
            hideChrome ? 16.0 : kBottomNavigationBarHeight + 16.0;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            bottomPadding + MediaQuery.of(context).padding.bottom,
          ),
          child: StandardViewGroup(
            queryStream: ratesStream,
            groupBy: (_) => '',
            emptyMessage: 'No standard rates found.',
            itemSort: (a, b) {
              final left = _concatenatedName(a).toLowerCase();
              final right = _concatenatedName(b).toLowerCase();
              return left.compareTo(right);
            },
            itemBuilder: (doc) {
              final label = _concatenatedName(doc);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: StandardTileSmallDart(
                  leadingIcon: Icons.attach_money,
                  label: label.isEmpty ? 'Unnamed rate' : label,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              );
            },
          ),
        );
      },
    );

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: null,
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          return buildBottomBar();
        },
      ),
      body: _wrapCanvas(body),
    );
  }

  String _concatenatedName(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final raw = doc.data()['concatenatedName'];
    if (raw == null) return '';
    return raw.toString().trim();
  }

}

