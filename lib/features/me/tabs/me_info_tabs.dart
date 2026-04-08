// lib/features/me/tabs/me_info_tabs.dart
//
// Admin's own "Me" area: Profile (header) + Onboarding + Charts.
// Onboarding tab is auto-selected on first build when the admin still has
// pending onboarding work.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kleenops_admin/app/shared_widgets/drawers/user_drawer.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/features/me/details/me_info_details.dart';
import 'package:kleenops_admin/features/me/screens/me_info_charts.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/tabs/standard_tab.dart';

/// Top-level screen with its own Scaffold (app bar + content + bottom nav)
class MeInfoTabsScreen extends StatelessWidget {
  const MeInfoTabsScreen({super.key});

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
      body: _wrapCanvas(const MeInfoTabs()),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          DetailsAppBar(title: 'My Info'),
          HomeNavBarAdapter(),
        ],
      ),
    );
  }
}

class MeInfoTabs extends ConsumerStatefulWidget {
  const MeInfoTabs({super.key});

  @override
  ConsumerState<MeInfoTabs> createState() => _MeInfoTabsState();
}

class _MeInfoTabsState extends ConsumerState<MeInfoTabs>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _autoSelected = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _maybeAutoSelectOnboarding(Map<String, dynamic> userData) {
    if (_autoSelected) return;
    final status = userData['onboardingStatus'];
    final steps = userData['onboardingSteps'];
    final hasSteps = steps is List && steps.isNotEmpty;
    if (hasSteps && status != 'completed') {
      _tabController.index = 1; // Onboarding tab
    }
    _autoSelected = true;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(userDocumentProvider, (prev, next) {
      next.whenData(_maybeAutoSelectOnboarding);
    });
    ref.read(userDocumentProvider).whenData(_maybeAutoSelectOnboarding);

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              child: StandardTabBar(
                controller: _tabController,
                isScrollable: true,
                dividerColor: Colors.grey[300],
                indicatorColor: Theme.of(context).primaryColor,
                indicatorWeight: 3,
                labelColor: Colors.black,
                unselectedLabelColor: Colors.grey[600],
                tabs: const [
                  Tab(text: 'Profile'),
                  Tab(text: 'Onboarding'),
                  Tab(text: 'Charts'),
                ],
              ),
            ),
          ),
        ];
      },
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          MeInfoDetailsContent(
            key: PageStorageKey('me-profile'),
            showHeader: true,
          ),
          _OnboardingTabContent(key: PageStorageKey('me-onboarding')),
          MeInfoChartsContent(key: PageStorageKey('me-charts')),
        ],
      ),
    );
  }
}

class _OnboardingTabContent extends ConsumerWidget {
  const _OnboardingTabContent({super.key});

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
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 16),
          child: MeOnboardingSection(memberRef: memberRef),
        );
      },
    );
  }
}
