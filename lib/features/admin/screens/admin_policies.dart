import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/features/admin/forms/admin_policy_form.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:shared_widgets/tabs/standard_tab.dart';
import 'package:shared_widgets/tiles/standard_tile_small.dart';

/// Top-level screen with its own Scaffold (app bar + content + bottom nav)
class AdminPoliciesScreen extends StatelessWidget {
  const AdminPoliciesScreen({super.key});

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
            title: 'Policies',
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
          const AdminPoliciesContent(),
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
                icon: Icons.apartment_outlined,
                label: 'Company',
                onTap: () => context.push(AppRoutePaths.adminCompany),
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

class AdminPoliciesContent extends ConsumerStatefulWidget {
  const AdminPoliciesContent({super.key});

  @override
  ConsumerState<AdminPoliciesContent> createState() =>
      _AdminPoliciesContentState();
}

class _AdminPoliciesContentState extends ConsumerState<AdminPoliciesContent>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final companyAsync = ref.watch(companyIdProvider);
    final bool hideChrome = false;
    final bottomInset =
        (hideChrome ? 16.0 : kBottomNavigationBarHeight + 16.0) +
            MediaQuery.of(context).padding.bottom;

    return companyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (companyRef) {
        if (companyRef == null) {
          return const Center(child: Text('No company found'));
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
                      Tab(text: 'Company Policies'),
                      Tab(text: 'Operations Policies'),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: bottomInset),
                    child: TabBarView(
                      physics: const NeverScrollableScrollPhysics(),
                      controller: _tabController,
                      children: [
                        _PolicyList(
                          companyRef: companyRef,
                          category: 'company',
                        ),
                        _PolicyList(
                          companyRef: companyRef,
                          category: 'operations',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton(
                onPressed: () {
                  final category =
                      _tabController.index == 0 ? 'company' : 'operations';
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AdminPolicyFormScreen(
                        companyRef: companyRef,
                        initialCategory: category,
                      ),
                    ),
                  );
                },
                child: const Icon(Icons.add),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PolicyList extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final String category;

  const _PolicyList({required this.companyRef, required this.category});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('policy')
          .where('category', isEqualTo: category)
          .orderBy('title')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.policy_outlined,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    category == 'company'
                        ? 'No company policies yet'
                        : 'No operations policies yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to add your first policy.',
                    style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 80),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final title = (data['title'] ?? 'Untitled').toString();
            final status = (data['status'] ?? 'draft').toString();
            final version = (data['version'] ?? '').toString();

            return Dismissible(
              key: ValueKey(doc.id),
              direction: status == 'draft'
                  ? DismissDirection.startToEnd
                  : DismissDirection.none,
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 20),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              confirmDismiss: (_) async {
                return await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Policy'),
                    content: Text('Delete "$title"? This cannot be undone.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
              onDismissed: (_) => doc.reference.delete(),
              child: StandardTileSmallDart(
                label: title,
                secondaryText:
                    '${_statusLabel(status)}${version.isNotEmpty ? ' • v$version' : ''}',
                leadingIcon: Icons.article_outlined,
                leadingIconColor: _statusColor(status),
                trailingIcon1: Icons.chevron_right,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AdminPolicyFormScreen(
                        companyRef: companyRef,
                        docId: doc.id,
                        initialCategory: category,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'active':
        return 'Active';
      case 'archived':
        return 'Archived';
      default:
        return 'Draft';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'archived':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }
}
