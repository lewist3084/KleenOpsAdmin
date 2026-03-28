import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:shared_widgets/tabs/standard_tab.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import '../forms/adminCompanyForm.dart';
import '../forms/adminRegistrationForm.dart';
import '../forms/adminInsuranceForm.dart';
import '../screens/adminCompany.dart';
import '../screens/adminRegistration.dart';
import '../screens/adminInsurance.dart';
import '../screens/adminStandards.dart';

class AdminCompanyTabsScreen extends StatelessWidget {
  const AdminCompanyTabsScreen({super.key});

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
            title: 'Company',
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
          const AdminCompanyTabs(),
        ),
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final menuSections = MenuDrawerSections(
            actions: [
              ContentMenuItem(
                icon: Icons.home_outlined,
                label: 'Admin Home',
                onTap: () => context.push(AppRoutePaths.adminHome),
              ),
              ContentMenuItem(
                icon: Icons.policy_outlined,
                label: 'Policies',
                onTap: () => context.push(AppRoutePaths.adminPolicies),
              ),
              ContentMenuItem(
                icon: Icons.rocket_launch_outlined,
                label: 'Business Setup Wizard',
                onTap: () => context.push(AppRoutePaths.adminSetupWizard),
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

class AdminCompanyTabs extends StatefulWidget {
  const AdminCompanyTabs({super.key});

  @override
  State<AdminCompanyTabs> createState() => _AdminCompanyTabsState();
}

class _AdminCompanyTabsState extends State<AdminCompanyTabs>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging ||
          _tabController.index == _tabController.animation?.value) {
        setState(() {}); // refresh FAB when tab changes
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hideChrome = false;
    final bottomInset =
        (hideChrome ? 16.0 : kBottomNavigationBarHeight + 16.0) +
            MediaQuery.of(context).padding.bottom;

    Widget? fab;
    if (_tabController.index == 1) {
      fab = FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const AdminRegistrationFormScreen(),
          ),
        ),
        child: const Icon(Icons.edit),
      );
    } else if (_tabController.index == 2) {
      fab = FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _InsuranceFabWrapper(),
          ),
        ),
        child: const Icon(Icons.add),
      );
    } else if (_tabController.index == 3) {
      fab = FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const AdminCompanyFormScreen(),
          ),
        ),
        child: const Icon(Icons.edit),
      );
    }

    return Stack(
      children: [
        Column(
          children: [
            Container(
              color: Colors.white,
              child: StandardTabBar(
                controller: _tabController,
                isScrollable: true,
                dividerColor: Colors.grey[300],
                indicatorColor: Theme.of(context).primaryColor,
                indicatorWeight: 3.0,
                labelColor: Colors.black,
                unselectedLabelColor: Colors.grey[600],
                tabs: const [
                  Tab(text: 'Profile'),
                  Tab(text: 'Registration'),
                  Tab(text: 'Insurance'),
                  Tab(text: 'Standards'),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomInset),
                child: TabBarView(
                  physics: const NeverScrollableScrollPhysics(),
                  controller: _tabController,
                  children: const [
                    AdminCompanyContent(),
                    AdminRegistrationContent(),
                    AdminInsuranceContent(),
                    AdminStandardsContent(),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (fab != null)
          Positioned(
            right: 16,
            bottom: 16,
            child: fab,
          ),
      ],
    );
  }
}

/// Resolves companyRef from provider and opens the insurance form for a new policy.
class _InsuranceFabWrapper extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyAsync = ref.watch(companyIdProvider);
    return companyAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) =>
          Scaffold(body: Center(child: Text('Error: $e'))),
      data: (companyRef) {
        if (companyRef == null) {
          return const Scaffold(
              body: Center(child: Text('No company found')));
        }
        return AdminInsuranceFormScreen(companyRef: companyRef);
      },
    );
  }
}
