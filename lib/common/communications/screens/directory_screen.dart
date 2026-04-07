import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/common/communications/comm_menu.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';

/// Company member directory — lists active members with contact info.
class AdminDirectoryScreen extends ConsumerWidget {
  const AdminDirectoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyAsync = ref.watch(companyIdProvider);
    final menuSections = MenuDrawerSections(
      communications: buildAdminCommunicationMenuItems(context),
    );

    return Scaffold(
      body: SafeArea(
        child: companyAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (companyRef) {
            if (companyRef == null) {
              return const Center(child: Text('No company.'));
            }
            return _MemberList(companyRef: companyRef);
          },
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(title: 'Directory', menuSections: menuSections),
          const HomeNavBarAdapter(),
        ],
      ),
    );
  }
}

class _MemberList extends StatelessWidget {
  const _MemberList({required this.companyRef});
  final DocumentReference<Map<String, dynamic>> companyRef;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: companyRef
          .collection('member')
          .where('active', isEqualTo: true)
          .orderBy('name')
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Text('No team members found.',
                style: TextStyle(color: Colors.grey.shade600)),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final d = docs[index].data();
            final name = (d['name'] as String?) ?? '';
            final email = (d['email'] as String?) ?? '';
            final phone = (d['phone'] as String?) ?? '';
            final role = (d['primaryRole'] as String?) ??
                (d['roleName'] as String?) ??
                '';
            final initials = name.split(' ').where((p) => p.isNotEmpty).map(
                (p) => p[0].toUpperCase()).take(2).join();

            return ListTile(
              leading: CircleAvatar(child: Text(initials)),
              title: Text(name),
              subtitle: Text(
                [if (role.isNotEmpty) role, if (email.isNotEmpty) email]
                    .join(' • '),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              trailing: phone.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.phone, size: 20),
                      onPressed: () {},
                    )
                  : null,
            );
          },
        );
      },
    );
  }
}
