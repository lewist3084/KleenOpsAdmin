import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/features/hr/dialogs/add_role_dialog.dart';
import 'package:kleenops_admin/features/hr/forms/hr_role_form.dart';
import 'package:kleenops_admin/theme/palette.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:shared_widgets/tiles/standard_tile_small.dart';

class HrRolesScreen extends ConsumerWidget {
  const HrRolesScreen({super.key});

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
    final palette = AppPaletteScope.of(context);
    final companyRefAsync = ref.watch(companyIdProvider);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: null,
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
                icon: Icons.groups_outlined,
                label: 'Teams',
                onTap: () => context.push(AppRoutePaths.hrTeam),
              ),
              ContentMenuItem(
                icon: Icons.calendar_month_outlined,
                label: 'Time Off',
                onTap: () => context.push(AppRoutePaths.hrTimeOff),
              ),
            ],
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DetailsAppBar(
                title: 'Roles',
                menuSections: menuSections,
              ),
              const HomeNavBarAdapter(highlightSelected: false),
            ],
          );
        },
      ),
      body: _wrapCanvas(
          companyRefAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (companyRef) {
              if (companyRef == null) {
                return const Center(child: Text('No company reference found.'));
              }
              return _RoleList(companyRef: companyRef);
            },
          ),
        ),
      floatingActionButton: companyRefAsync.when(
        loading: () => null,
        error: (_, __) => null,
        data: (companyRef) {
          if (companyRef == null) return null;
          return FloatingActionButton(
            backgroundColor: palette.primary1.withAlpha(220),
            tooltip: 'Add role',
            onPressed: () async {
              final added = await AddRoleDialog.show(
                context,
                companyRef: companyRef,
              );
              if (added == true && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Role created')),
                );
              }
            },
            child: const Icon(Icons.add),
          );
        },
      ),
    );
  }
}

class _RoleList extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;

  const _RoleList({required this.companyRef});

  Future<bool> _confirmDelete(BuildContext context, String roleName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Role'),
          content: Text('Delete "$roleName"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    return confirmed == true;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('role').orderBy('name').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No roles found.'));
        }

        final bottomInset = kBottomNavigationBarHeight +
            16.0 +
            MediaQuery.of(context).padding.bottom;

        return ListView.builder(
          padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 56),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final roleName = (data['name'] ?? doc.id).toString();
            final description = (data['description'] ?? '').toString();

            return Dismissible(
              key: ValueKey(doc.id),
              direction: DismissDirection.startToEnd,
              background: Container(
                margin: const EdgeInsets.symmetric(vertical: 3),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 20),
                color: Colors.red,
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              confirmDismiss: (_) async {
                final confirmed = await _confirmDelete(context, roleName);
                if (!confirmed) return false;
                await doc.reference.delete();
                return false;
              },
              child: StandardTileSmallDart(
                leadingIcon: Icons.badge_outlined,
                label: roleName,
                secondaryText: description.isNotEmpty ? description : null,
                trailingIcon1: Icons.edit_outlined,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => HrRoleForm(
                        companyRef: companyRef,
                        docId: doc.id,
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
}
