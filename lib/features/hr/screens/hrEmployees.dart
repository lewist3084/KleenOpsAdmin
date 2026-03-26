// lib/features/hr/screens/hrEmployees.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kleenops_admin/common/utils/contact_info.dart';
import 'package:kleenops_admin/features/hr/forms/hr_employee_form.dart';
import '../details/hrEmployeeDetails.dart';
import 'hrTicketScannerScreen.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:shared_widgets/lists/standardView.dart';
import 'package:shared_widgets/tiles/standard_tile_small.dart';
import 'package:kleenops_admin/theme/palette.dart';

/// Employees list with floating action button
class HrEmployeesContent extends ConsumerStatefulWidget {
  const HrEmployeesContent({super.key});

  @override
  ConsumerState<HrEmployeesContent> createState() => _HrEmployeesContentState();
}

class _HrEmployeesContentState extends ConsumerState<HrEmployeesContent> {
  Stream<QuerySnapshot<Map<String, dynamic>>>? _membersStream;
  DocumentReference<Map<String, dynamic>>? _companyRef;
  final Map<String, String> _roleNames = {};

  String? _normalizeRoleId(dynamic value) {
    if (value is DocumentReference) return value.id;
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return trimmed.contains('/') ? trimmed.split('/').last : trimmed;
    }
    return null;
  }

  String _resolveRoleLabel(dynamic roleValue) {
    final roleId = _normalizeRoleId(roleValue);
    if (roleId == null) return 'Unknown Role';
    return _roleNames[roleId] ?? roleId;
  }

  String _resolveMemberName(Map<String, dynamic> data) {
    String pickString(dynamic value) {
      return value is String ? value.trim() : '';
    }

    final first = pickString(data['firstName']);
    final last = pickString(data['lastName']);
    final combined = [first, last].where((part) => part.isNotEmpty).join(' ');

    final candidates = [
      data['name'],
      data['displayName'],
      data['authName'],
      data['fullName'],
      data['preferredName'],
      combined,
      data['email'],
      data['authEmail'],
    ];

    for (final candidate in candidates) {
      final value = pickString(candidate);
      if (value.isNotEmpty) return value;
    }

    return 'No Name';
  }

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

    _membersStream =
        comp.collection('member').where('active', isEqualTo: true).snapshots();

    setState(() {});
  }

  String? _formatPhone(String? p) {
    if (p == null) return null;
    final d = p.replaceAll(RegExp(r'\D'), '');
    if (d.length == 10) return '+1$d';
    if (d.length == 11 && d.startsWith('1')) return '+$d';
    return '+1$d';
  }

  Widget _buildList(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    // grouping
    final grouped =
        <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    final order = <String>[];

    for (var doc in docs) {
      final label = _resolveRoleLabel(doc.data()['roleId']);

      grouped.putIfAbsent(label, () {
        order.add(label);
        return [];
      }).add(doc);
    }

    // sort
    final sorted = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (var label in order) {
      final list = grouped[label]!;
      list.sort((a, b) =>
          _resolveMemberName(a.data()).compareTo(_resolveMemberName(b.data())));
      sorted.addAll(list);
    }

    return StandardView<QueryDocumentSnapshot<Map<String, dynamic>>>(
      items: sorted,
      groupBy: (doc) {
        return _resolveRoleLabel(doc.data()['roleId']);
      },
      itemBuilder: (doc) {
        final d = doc.data();
        unawaited(
          migrateContactFieldsIfNeeded(
            docRef: doc.reference,
            data: d,
          ).catchError((_) {}),
        );
        final contacts = parseContactInfo(d);
        final name = _resolveMemberName(d);
        final phone = _formatPhone(contacts.primaryPhone?.value);
        final clockedIn = d['clockedIn'] == true;
        final roleName = _resolveRoleLabel(d['roleId']);

        return InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => HrEmployeesDetailsScreen(
                documentId: doc.id,
                name: name,
                roleName: roleName,
                imageUrl: '',
              ),
            ),
          ),
          child: StandardTileSmallDart.iconText(
            leadingicon:
                clockedIn ? Icons.access_time_filled : Icons.person_outlined,
            text: name,
            trailingIcon1: Icons.local_phone,
            trailingAction1: phone != null ? () => launch('tel:$phone') : null,
            trailingIcon2: Icons.chat_rounded,
            trailingAction2: phone != null ? () => launch('sms:$phone') : null,
          ),
        );
      },
      headerIcon: null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteScope.of(context);
    final bool hideChrome = false;
    final bottomInset =
        (hideChrome ? 16.0 : kBottomNavigationBarHeight + 16.0) +
            MediaQuery.of(context).padding.bottom;

    final content = Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Employees',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: _membersStream == null
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _membersStream,
                    builder: (ctx, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snap.hasError) {
                        return Center(child: Text('Error: ${snap.error}'));
                      }

                      final docs = snap.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return const Center(child: Text('No employees found.'));
                      }

                      // load missing role names once
                      final missing = docs
                          .map((d) => _normalizeRoleId(d.data()['roleId']))
                          .where(
                            (id) => id != null && !_roleNames.containsKey(id),
                          )
                          .cast<String>()
                          .toSet()
                          .toList();

                      if (missing.isNotEmpty && _companyRef != null) {
                        return FutureBuilder<
                                List<DocumentSnapshot<Map<String, dynamic>>>>(
                            future: Future.wait(
                              missing.map(
                                (id) => _companyRef!
                                    .collection('role')
                                    .doc(id)
                                    .get(),
                              ),
                            ),
                            builder: (c2, snap2) {
                              if (snap2.connectionState !=
                                  ConnectionState.done) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              if (snap2.hasError) {
                                return Center(
                                  child: Text(
                                      'Error loading roles: ${snap2.error}'),
                                );
                              }
                              for (var roleDoc in snap2.data!) {
                                final m = roleDoc.data()!;
                                _roleNames[roleDoc.id] =
                                    m['name'] as String? ?? roleDoc.id;
                              }
                              return _buildList(docs);
                            });
                      }

                      return _buildList(docs);
                    },
                  ),
          ),
        ],
      ),
    );

    return Stack(
      children: [
        content,
        if (_companyRef != null)
          Positioned(
            right: 16,
            bottom: bottomInset,
            child: FloatingActionButton(
              backgroundColor: palette.primary1.withAlpha(220),
              tooltip: 'Scan onboarding ticket',
              onPressed: () {
                if (_companyRef == null) return;
                showModalBottomSheet<void>(
                  context: context,
                  builder: (sheetContext) {
                    return SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.person_add_alt_1_outlined),
                            title: const Text('Create Employee Manually'),
                            onTap: () {
                              Navigator.of(sheetContext).pop();
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => HrEmployeeForm(
                                    companyRef: _companyRef!,
                                  ),
                                ),
                              );
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.qr_code_scanner),
                            title: const Text('Scan Onboarding Ticket'),
                            onTap: () {
                              Navigator.of(sheetContext).pop();
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const HrTicketScannerScreen(),
                                  settings: RouteSettings(arguments: _companyRef),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              child: const Icon(Icons.person_add),
            ),
          ),
      ],
    );
  }
}
