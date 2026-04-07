import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/features/hr/forms/hr_document_form.dart';
import 'package:kleenops_admin/theme/palette.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:shared_widgets/tiles/standard_tile_small.dart';

class HrDocumentsScreen extends ConsumerWidget {
  const HrDocumentsScreen({super.key});

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
      drawer: const UserDrawer(),
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final menuSections = MenuDrawerSections(
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DetailsAppBar(
                title: 'Employee Documents',
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

              return _DocumentsList(companyRef: companyRef);
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
            tooltip: 'Add Document',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => HrDocumentForm(companyRef: companyRef),
                ),
              );
            },
            child: const Icon(Icons.add),
          );
        },
      ),
    );
  }
}

class _DocumentsList extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;

  const _DocumentsList({required this.companyRef});

  String _formatDate(dynamic value) {
    if (value is Timestamp) {
      return DateFormat.yMMMd().format(value.toDate());
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('employeeDocument')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No employee documents found.'));
        }

        final grouped = <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
        for (final doc in docs) {
          final type = (doc.data()['type'] ?? 'other').toString().toLowerCase();
          grouped.putIfAbsent(type, () => []).add(doc);
        }

        final orderedTypes = ['id', 'contract', 'certification', 'tax', 'other'];
        final bottomInset = kBottomNavigationBarHeight +
            16.0 +
            MediaQuery.of(context).padding.bottom;

        return ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset + 56),
          children: orderedTypes
              .where((type) => (grouped[type] ?? const []).isNotEmpty)
              .expand((type) {
            final label = type[0].toUpperCase() + type.substring(1);
            final items = grouped[type]!;
            return [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '$label (${items.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ...items.map((doc) {
                final data = doc.data();
                final name = (data['name'] ?? 'Document').toString();
                final memberName = (data['memberName'] ?? 'Unknown').toString();
                final exp = _formatDate(data['expirationDate']);
                final secondary =
                    exp.isNotEmpty ? '$memberName  |  Expires $exp' : memberName;

                return StandardTileSmallDart(
                  leadingIcon: Icons.description_outlined,
                  label: name,
                  secondaryText: secondary,
                  trailingIcon1: Icons.edit_outlined,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HrDocumentForm(
                          companyRef: companyRef,
                          docId: doc.id,
                        ),
                      ),
                    );
                  },
                );
              }),
            ];
          }).toList(),
        );
      },
    );
  }
}
