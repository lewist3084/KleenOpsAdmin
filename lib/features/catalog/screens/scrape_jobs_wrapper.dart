// lib/features/catalog/screens/scrape_jobs_wrapper.dart
//
// Wraps the ScrapeJobsScreen with the standard admin layout (DetailsAppBar + HomeNavBar).
//
// Owns the search state for the Review tab so the search field can sit
// just above the DetailsAppBar in the bottom chrome — gated on the
// appbar's search toggle. The screen receives the live `searchQuery` as
// a constructor argument and threads it into the Review tab.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/search/search_control_strip_adapter.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';

import 'marketplace_scrape_jobs.dart';

class ScrapeJobsWrapper extends StatefulWidget {
  const ScrapeJobsWrapper({super.key});

  @override
  State<ScrapeJobsWrapper> createState() => _ScrapeJobsWrapperState();
}

class _ScrapeJobsWrapperState extends State<ScrapeJobsWrapper> {
  bool _searchActive = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searchActive = !_searchActive;
      if (!_searchActive) {
        _searchController.clear();
        _searchQuery = '';
      }
    });
    if (_searchActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocusNode.requestFocus();
      });
    }
  }

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
          if (_searchActive)
            SearchControlStrip(
              controller: _searchController,
              focusNode: _searchFocusNode,
              hintText: 'Search staged products',
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          DetailsAppBar(
            title: 'Web Scraping',
            menuSections: menuSections,
            onSearchToggle: _toggleSearch,
            searchActive: _searchActive,
          ),
          const HomeNavBarAdapter(),
        ],
      );
    }

    return Scaffold(
      appBar: null,
      drawer: const UserDrawer(),
      body: _wrapCanvas(
        ScrapeJobsScreen(searchQuery: _searchQuery),
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
