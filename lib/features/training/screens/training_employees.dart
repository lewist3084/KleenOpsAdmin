// lib/features/training/screens/training_employees.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kleenops_admin/app/shared_widgets/search/search_control_strip_adapter.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/features/training/details/training_employee_details.dart';
import 'package:kleenops_admin/features/training/tabs/training_employees_tabs.dart'
    show trainingEmployeesTabsSearchVisibleProvider;
import 'package:shared_widgets/lists/standardView.dart';
import 'package:shared_widgets/buttons/pill_button.dart';
import 'package:shared_widgets/tiles/standard_tile_small.dart';

class TrainingEmployeesContent extends ConsumerStatefulWidget {
  final String? teamId;
  const TrainingEmployeesContent({super.key, this.teamId});

  @override
  ConsumerState<TrainingEmployeesContent> createState() =>
      _TrainingEmployeesContentState();
}

class _TrainingEmployeesContentState
    extends ConsumerState<TrainingEmployeesContent> {
  final _searchCtl = TextEditingController();
  String _search = '';
  final _roleNames = <String, String>{};
  static const List<String> _trainingPercentKeys = <String>[
    'trainingCompletionPercent',
    'trainingPercent',
    'trainingCompletion',
    'trainingCompliancePercent',
    'trainingCompliance',
  ];
  static const List<String> _trainingRenewalKeys = <String>[
    'trainingRenewalCount',
    'trainingExpiringSoonCount',
    'trainingExpiringCount',
    'expiringTrainingSoonCount',
    'expiringTrainingCount',
    'expiringTrainings',
    'trainingExpiringSoon',
    'trainingExpiring',
  ];
  static const List<String> _trainingOverdueKeys = <String>[
    'trainingOverdueCount',
    'trainingExpiredCount',
    'trainingPastDueCount',
    'trainingOverdue',
    'trainingExpired',
  ];

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

    return 'Unnamed';
  }

  String? _resolveRoleId(dynamic roleVal) {
    if (roleVal is DocumentReference) {
      return roleVal.id;
    }
    if (roleVal is String) {
      if (roleVal.contains('/')) {
        return roleVal.split('/').last;
      }
      return roleVal;
    }
    return null;
  }

  double? _parsePercent(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) {
      final double value = raw.toDouble();
      if (value.isNaN || value.isInfinite) return null;
      if (value >= 0 && value <= 1) return value * 100;
      return value;
    }
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      final sanitized = trimmed.endsWith('%')
          ? trimmed.substring(0, trimmed.length - 1).trim()
          : trimmed;
      final double? parsed = double.tryParse(sanitized);
      if (parsed == null) return null;
      if (parsed >= 0 && parsed <= 1) return parsed * 100;
      return parsed;
    }
    return null;
  }

  double? _resolvePercent(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final double? parsed = _parsePercent(data[key]);
      if (parsed != null) return parsed;
    }
    return null;
  }

  int? _parseCount(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw >= 0 ? raw : null;
    if (raw is num) {
      final double value = raw.toDouble();
      if (value.isNaN || value.isInfinite) return null;
      final int resolved = value.toInt();
      return resolved >= 0 ? resolved : null;
    }
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      final int? parsed = int.tryParse(trimmed);
      if (parsed != null) return parsed >= 0 ? parsed : null;
      final double? parsedDouble = double.tryParse(trimmed);
      if (parsedDouble == null) return null;
      final int resolved = parsedDouble.toInt();
      return resolved >= 0 ? resolved : null;
    }
    return null;
  }

  int? _resolveCount(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final int? parsed = _parseCount(data[key]);
      if (parsed != null) return parsed;
    }
    return null;
  }

  Future<void> _loadMissingRoleNames(
    DocumentReference<Map<String, dynamic>> companyRef,
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final missing = <String>{};
    for (final doc in docs) {
      final roleId = _resolveRoleId(doc.data()['roleId']);
      if (roleId != null && !_roleNames.containsKey(roleId)) {
        missing.add(roleId);
      }
    }

    if (missing.isEmpty) return;

    final futures = missing.map(
      (id) => FirebaseFirestore.instance.collection('role').doc(id).get(),
    );
    final snaps = await Future.wait(futures);
    for (final snap in snaps) {
      final data = snap.data() ?? <String, dynamic>{};
      _roleNames[snap.id] = data['name'] as String? ?? snap.id;
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ref.watch(companyIdProvider).when(
          loading: () => const CustomScrollView(
            slivers: [
              SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          ),
          error: (e, _) => CustomScrollView(
            slivers: [
              SliverFillRemaining(
                child: Center(child: Text('Error loading company: $e')),
              ),
            ],
          ),
          data: (companyRef) {
            if (companyRef == null) {
              return const CustomScrollView(
                slivers: [
                  SliverFillRemaining(
                    child: Center(child: Text('No company assigned.')),
                  ),
                ],
              );
            }

            if (widget.teamId == null || widget.teamId!.isEmpty) {
              return const CustomScrollView(
                slivers: [
                  SliverFillRemaining(
                    child: Center(child: Text('No team selected.')),
                  ),
                ],
              );
            }

            final typedCompanyRef =
                companyRef.withConverter<Map<String, dynamic>>(
              fromFirestore: (s, _) => s.data() ?? <String, dynamic>{},
              toFirestore: (m, _) => m,
            );
            final teamRef =
                typedCompanyRef.collection('team').doc(widget.teamId);
            final membersQuery = typedCompanyRef
                .collection('member')
                .where('active', isEqualTo: true)
                .where('primaryTeamId', isEqualTo: teamRef);

            final showSearch =
                ref.watch(trainingEmployeesTabsSearchVisibleProvider);
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: membersQuery.snapshots(),
              builder: (_, snap) {
                final slivers = <Widget>[];

                Widget buildScrollView() {
                  return CustomScrollView(
                    slivers: [
                      ...slivers,
                      if (showSearch)
                        SliverToBoxAdapter(
                          child: SearchControlStrip(
                            controller: _searchCtl,
                            hintText: 'Search team members...',
                            onChanged: (t) => setState(
                                () => _search = t.toLowerCase().trim()),
                          ),
                        ),
                    ],
                  );
                }

                if (!snap.hasData) {
                  slivers.add(
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                  return buildScrollView();
                }

                final docs = snap.data!.docs.where((d) {
                  final name = _resolveMemberName(d.data()).toLowerCase();
                  return name.contains(_search);
                }).toList();

                docs.sort((a, b) {
                  final an = _resolveMemberName(a.data()).toLowerCase();
                  final bn = _resolveMemberName(b.data()).toLowerCase();
                  return an.compareTo(bn);
                });

                () async {
                  await _loadMissingRoleNames(typedCompanyRef, docs);
                }();

                if (docs.isEmpty) {
                  slivers.add(
                    const SliverFillRemaining(
                      child: Center(child: Text('No team members.')),
                    ),
                  );
                  return buildScrollView();
                }

                slivers.add(
                  SliverToBoxAdapter(
                    child: StandardView<
                        QueryDocumentSnapshot<Map<String, dynamic>>>(
                      items: docs,
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewPadding.bottom + 16,
                      ),
                      headerIcon: null,
                      physics: const NeverScrollableScrollPhysics(),
                      groupBy: (d) {
                        final roleId = _resolveRoleId(d.data()['roleId']);
                        return roleId != null
                            ? (_roleNames[roleId] ?? 'Role')
                            : 'Role';
                      },
                      itemBuilder: (d) {
                        final data = d.data();
                        final name = _resolveMemberName(data);
                        final double? completionPercent =
                            _resolvePercent(data, _trainingPercentKeys);
                        final int? renewalCount =
                            _resolveCount(data, _trainingRenewalKeys);
                        final int? overdueCount =
                            _resolveCount(data, _trainingOverdueKeys);
                        return StandardTileSmallDart(
                          label: name,
                          leadingIcon: Icons.person_outline,
                          trailingWidget: TrainingPillButtonDart(
                            completionPercent: completionPercent,
                            renewalCount: renewalCount,
                            overdueCount: overdueCount,
                          ),
                          tileColor: Colors.white,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => TrainingEmployeeDetailsScreen(
                                  companyRef: typedCompanyRef,
                                  memberRef: d.reference,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                );

                return buildScrollView();
              },
            );
          },
        );
  }
}
