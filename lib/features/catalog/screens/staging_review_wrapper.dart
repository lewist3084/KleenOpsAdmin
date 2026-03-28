// lib/features/catalog/screens/staging_review_wrapper.dart
//
// Wraps the StagingReviewScreen with the standard admin layout (DetailsAppBar + HomeNavBar).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';

import 'marketplaceStagingReview.dart';

class StagingReviewWrapper extends StatelessWidget {
  const StagingReviewWrapper({super.key});

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
      MenuDrawerSections? menuSections,
    }) {
      if (hideChrome) return const SizedBox.shrink();
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: 'Staging Review',
            menuSections: menuSections,
          ),
          const HomeNavBarAdapter(),
        ],
      );
    }

    return Scaffold(
      appBar: null,
      drawer: const UserDrawer(),
      body: _wrapCanvas(
        const StagingReviewScreen(),
      ),
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final menuSections = MenuDrawerSections(
            actions: const [],
          );
          return buildBottomBar(
            menuSections: menuSections,
          );
        },
      ),
    );
  }
}
