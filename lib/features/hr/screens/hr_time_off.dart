// lib/features/hr/screens/hr_time_off.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/theme/palette.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:shared_widgets/tiles/standard_tile_small.dart';

import '../forms/hr_time_off_form.dart';
import '../details/hr_time_off_details.dart';

class HrTimeOffScreen extends ConsumerStatefulWidget {
  const HrTimeOffScreen({super.key});

  @override
  ConsumerState<HrTimeOffScreen> createState() => _HrTimeOffScreenState();
}

class _HrTimeOffScreenState extends ConsumerState<HrTimeOffScreen> {
  DocumentReference<Map<String, dynamic>>? _companyRef;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _timeOffStream;
  final Map<String, String> _memberNames = {};

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    final userData = await ref.read(userDocumentProvider.future);
    final comp =
        userData['companyId'] as DocumentReference<Map<String, dynamic>>?;
    if (comp == null) return;

    _companyRef = comp;
    _timeOffStream = comp
        .collection('timeOff')
        .orderBy('createdAt', descending: true)
        .snapshots();

    setState(() {});
  }

  Future<String> _resolveMemberName(dynamic memberIdVal) async {
    if (memberIdVal == null) return 'Unknown';

    String memberId;
    if (memberIdVal is DocumentReference) {
      memberId = memberIdVal.id;
    } else if (memberIdVal is String && memberIdVal.isNotEmpty) {
      memberId = memberIdVal.contains('/')
          ? memberIdVal.split('/').last
          : memberIdVal;
    } else {
      return 'Unknown';
    }

    if (_memberNames.containsKey(memberId)) {
      return _memberNames[memberId]!;
    }

    if (_companyRef == null) return memberId;

    try {
      final snap =
          await _companyRef!.collection('member').doc(memberId).get();
      if (snap.exists) {
        final data = snap.data() ?? {};
        final first = (data['firstName'] ?? '').toString().trim();
        final last = (data['lastName'] ?? '').toString().trim();
        final name = [first, last].where((s) => s.isNotEmpty).join(' ');
        final resolved =
            name.isNotEmpty ? name : (data['name'] ?? memberId).toString();
        _memberNames[memberId] = resolved;
        return resolved;
      }
    } catch (_) {}

    _memberNames[memberId] = memberId;
    return memberId;
  }

  String _formatDate(dynamic val) {
    if (val is Timestamp) {
      return DateFormat('yMMMd').format(val.toDate());
    }
    return '';
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

  Future<void> _deleteRequest(
      DocumentReference<Map<String, dynamic>> docRef) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Request'),
        content:
            const Text('Are you sure you want to delete this time off request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await docRef.delete();
    }
  }

  Future<void> _updateStatus(
      DocumentReference<Map<String, dynamic>> docRef, String status) async {
    final data = <String, dynamic>{'status': status};
    if (status == 'approved' || status == 'denied') {
      final userData = await ref.read(userDocumentProvider.future);
      final memberRef = userData['memberRef'];
      if (memberRef is DocumentReference) {
        data['approvedBy'] = memberRef;
      }
    }
    await docRef.update(data);
  }

  Widget _buildList(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    // Group by status
    const statusOrder = ['requested', 'approved', 'denied'];
    final grouped =
        <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};

    for (var doc in docs) {
      final status =
          (doc.data()['status'] ?? 'requested').toString().toLowerCase();
      grouped.putIfAbsent(status, () => []).add(doc);
    }

    final bottomInset = kBottomNavigationBarHeight +
        16.0 +
        MediaQuery.of(context).padding.bottom;

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset + 60),
      itemCount: statusOrder.length,
      itemBuilder: (ctx, sectionIndex) {
        final status = statusOrder[sectionIndex];
        final items = grouped[status];
        if (items == null || items.isEmpty) return const SizedBox.shrink();

        final statusLabel =
            status[0].toUpperCase() + status.substring(1);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                statusLabel,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...items.map((doc) {
              final data = doc.data();
              final type = (data['type'] ?? '').toString();
              final startDate = _formatDate(data['startDate']);
              final endDate = _formatDate(data['endDate']);
              final dateRange = startDate.isNotEmpty && endDate.isNotEmpty
                  ? '$startDate - $endDate'
                  : startDate;

              return FutureBuilder<String>(
                future: _resolveMemberName(data['memberId']),
                builder: (ctx2, nameSnap) {
                  final memberName = nameSnap.data ?? '...';

                  return Dismissible(
                    key: ValueKey(doc.id),
                    direction: status == 'requested'
                        ? DismissDirection.startToEnd
                        : DismissDirection.none,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (_) async {
                      await _deleteRequest(doc.reference);
                      return false;
                    },
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => HrTimeOffDetailsScreen(
                              companyRef: _companyRef!,
                              docId: doc.id,
                            ),
                          ),
                        );
                      },
                      child: StandardTileSmallDart(
                        leadingIcon: Icons.calendar_today,
                        label: '$memberName - $type',
                        secondaryText: dateRange,
                      ),
                    ),
                  );
                },
              );
            }),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteScope.of(context);

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
                title: 'Time Off',
                menuSections: menuSections,
              ),
              const HomeNavBarAdapter(highlightSelected: false),
            ],
          );
        },
      ),
      body: _wrapCanvas(
          _timeOffStream == null
              ? const Center(child: CircularProgressIndicator())
              : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _timeOffStream,
                  builder: (ctx, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Center(
                          child: Text('Error: ${snap.error}'));
                    }

                    final docs = snap.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Center(
                          child: Text('No time off requests.'));
                    }

                    return _buildList(docs);
                  },
                ),
        ),
      floatingActionButton: _companyRef == null
          ? null
          : FloatingActionButton(
              backgroundColor: palette.primary1.withAlpha(220),
              tooltip: 'New Time Off Request',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        HrTimeOffForm(companyRef: _companyRef!),
                  ),
                );
              },
              child: const Icon(Icons.add),
            ),
    );
  }
}
