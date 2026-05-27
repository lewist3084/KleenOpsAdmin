// lib/features/training/details/training_employee_details.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/containers/container_header.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/tiles/standard_tile_small.dart';
import 'package:shared_widgets/lists/standardViewGroup.dart';
import 'package:shared_widgets/theme/app_palette.dart';
import 'package:shared_widgets/utils/process_localization_utils.dart';
import 'package:kleenops_admin/features/hr/utils/member_file_images.dart';

import 'training_assigned_training_details.dart';

class TrainingEmployeeDetailsScreen extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final DocumentReference<Map<String, dynamic>> memberRef;

  const TrainingEmployeeDetailsScreen({
    super.key,
    required this.companyRef,
    required this.memberRef,
  });

  @override
  State<TrainingEmployeeDetailsScreen> createState() =>
      _TrainingEmployeeDetailsScreenState();
}

class _TrainingEmployeeDetailsScreenState
    extends State<TrainingEmployeeDetailsScreen> {
  // Memoized role-doc fetches keyed by role path. The role ref is derived
  // from a StreamBuilder snapshot, so it can change between rebuilds.
  final Map<String, Future<DocumentSnapshot<Map<String, dynamic>>>>
      _roleFutureCache = {};

  /// Memoized member-doc and assigned-training streams. Both are derived
  /// purely from the constructor params (`FirebaseFirestore.instance`/`widget.memberRef`)
  /// and live unconditionally in the ListView, so they are created once.
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _memberStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _assignedStream;

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

  String _resolveRoleNameFallback(Map<String, dynamic> data) {
    final candidates = [
      data['roleName'],
      data['roleTitle'],
      data['role'],
    ];
    for (final candidate in candidates) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    return '';
  }

  Future<_TrainingLookupTables> _buildLookupTables(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> assignedDocs,
    String localeCode,
  ) async {
    final trainingRefs = assignedDocs
        .map((d) => d.data()['trainingId'])
        .whereType<DocumentReference>()
        .toSet()
        .toList();
    final trainingSnaps = await Future.wait(trainingRefs.map((r) => r.get()));
    final trainingByRef = {for (var s in trainingSnaps) s.reference: s};

    final categoryRefs = trainingSnaps
        .map((s) => (s.data() as Map<String, dynamic>?)?['trainingCategoryId']
            as DocumentReference?)
        .whereType<DocumentReference>()
        .toSet()
        .toList();
    final categorySnaps = await Future.wait(categoryRefs.map((r) => r.get()));
    final categoryNameByRef = <DocumentReference, String>{};
    for (var c in categorySnaps) {
      final data = c.data() as Map<String, dynamic>? ?? {};
      final resolved = ProcessLocalizationUtils.resolveLocalizedText(
        data['name'],
        localeCode: localeCode,
        fallbackLocaleCode: ProcessLocalizationUtils.defaultLocaleCode,
      );
      categoryNameByRef[c.reference] =
          resolved.trim().isEmpty ? 'Uncategorized' : resolved;
    }

    return _TrainingLookupTables(
      trainingByRef: trainingByRef,
      categoryNameByRef: categoryNameByRef,
    );
  }

  @override
  Widget build(BuildContext context) {
    final companyRef = widget.companyRef;
    final memberRef = widget.memberRef;
    final assignedStream = _assignedStream ??= FirebaseFirestore.instance
        .collection('assignedTraining')
        .where('memberId', isEqualTo: memberRef)
        .snapshots();
    final localeCodeRaw = ProcessLocalizationUtils.normalizeLocaleCode(
      Localizations.localeOf(context).toString(),
    );
    final localeCode = localeCodeRaw.isNotEmpty
        ? localeCodeRaw
        : ProcessLocalizationUtils.defaultLocaleCode;
    final bottomPadding = MediaQuery.of(context).padding.bottom + 16;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: null,
      body: _wrapCanvas(
        ListView(
          padding: EdgeInsets.only(bottom: bottomPadding),
          children: [
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _memberStream ??= memberRef.snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const ContainerHeader(
                    titleHeader: 'Name',
                    title: 'Loading...',
                    descriptionHeader: 'Role',
                    description: '',
                    textIcon: Icons.person_outline,
                    descriptionIcon: Icons.work_outline,
                    showImage: false,
                  );
                }
                if (snap.hasError || !(snap.data?.exists ?? false)) {
                  return const ContainerHeader(
                    titleHeader: 'Name',
                    title: 'Employee not found.',
                    descriptionHeader: 'Role',
                    description: '',
                    textIcon: Icons.person_outline,
                    descriptionIcon: Icons.work_outline,
                    showImage: false,
                  );
                }

                final data = snap.data!.data() ?? <String, dynamic>{};
                final name = _resolveMemberName(data);
                final roleFallback = _resolveRoleNameFallback(data);
                final roleId = _resolveRoleId(data['roleId']);
                final roleRef = roleId == null || roleId.isEmpty
                    ? null
                    : FirebaseFirestore.instance.collection('role').doc(roleId);
                final imageFuture =
                    MemberFileImages.primaryProfileImageUrl(
                  companyRef: companyRef,
                  memberId: memberRef.id,
                );

                return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  future: roleRef == null
                      ? null
                      : (_roleFutureCache[roleRef.path] ??= roleRef.get()),
                  builder: (context, roleSnap) {
                    final roleData = roleSnap.data?.data();
                    final roleName =
                        roleData?['name'] as String? ?? roleFallback;
                    final showRoleName = roleName.trim().isNotEmpty;
                    return FutureBuilder<String>(
                      future: imageFuture,
                      builder: (context, imageSnap) {
                        final resolvedImageUrl = imageSnap.data ?? '';
                        return ContainerHeader(
                          image: resolvedImageUrl,
                          images: const [],
                          showImage: resolvedImageUrl.isNotEmpty,
                          titleHeader: 'Name',
                          title: name,
                          descriptionHeader: showRoleName ? 'Role' : '',
                          description: roleName,
                          textIcon: Icons.person_outline,
                          descriptionIcon: Icons.work_outline,
                        );
                      },
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: assignedStream,
              builder: (context, snap) {
                final assignedDocs = snap.data?.docs ??
                    <QueryDocumentSnapshot<Map<String, dynamic>>>[];

                if (snap.hasError) {
                  return ContainerActionWidget(
                    title: 'Training',
                    content: Text('Error: ${snap.error}'),
                    actionText: '',
                    enabled: false,
                  );
                }

                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return ContainerActionWidget(
                    title: 'Training',
                    content: const Center(child: CircularProgressIndicator()),
                    actionText: '',
                    enabled: false,
                  );
                }

                if (assignedDocs.isEmpty) {
                  return const ContainerActionWidget(
                    title: 'Training',
                    content: Text('No training assigned.'),
                    actionText: '',
                    enabled: false,
                  );
                }

                return ContainerActionWidget(
                  title: 'Training',
                  actionText: '',
                  content: FutureBuilder<_TrainingLookupTables>(
                    future: _buildLookupTables(assignedDocs, localeCode),
                    builder: (context, lookSnap) {
                      if (!lookSnap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final tables = lookSnap.data!;
                      final trainingByRef = tables.trainingByRef;
                      final categoryNameByRef = tables.categoryNameByRef;

                      String groupKey(DocumentReference? catRef, String name) {
                        return catRef == null
                            ? '__null__#$name'
                            : '${catRef.path}#$name';
                      }

                      return StandardViewGroup.buildViewFromDocs(
                        docs: assignedDocs,
                        groupBy: (docSnap) {
                          final tRef =
                              docSnap.data()['trainingId'] as DocumentReference?;
                          final tData =
                              (trainingByRef[tRef]?.data() as Map<String, dynamic>?) ??
                                  {};
                          final catRef =
                              tData['trainingCategoryId'] as DocumentReference?;
                          final catName = catRef == null
                              ? 'Uncategorized'
                              : (categoryNameByRef[catRef] ?? 'Uncategorized');
                          return groupKey(catRef, catName);
                        },
                        groupSort: (k1, k2) {
                          String nameOf(String key) {
                            final idx = key.indexOf('#');
                            return idx == -1 ? key : key.substring(idx + 1);
                          }

                          return nameOf(k1).compareTo(nameOf(k2));
                        },
                        itemSort: (a, b) {
                          final aRef =
                              a.data()['trainingId'] as DocumentReference?;
                          final bRef =
                              b.data()['trainingId'] as DocumentReference?;
                          final aData =
                              (trainingByRef[aRef]?.data() as Map<String, dynamic>?) ??
                                  {};
                          final bData =
                              (trainingByRef[bRef]?.data() as Map<String, dynamic>?) ??
                                  {};
                          final aCatRef =
                              aData['trainingCategoryId'] as DocumentReference?;
                          final bCatRef =
                              bData['trainingCategoryId'] as DocumentReference?;
                          final aCatName = aCatRef == null
                              ? ''
                              : (categoryNameByRef[aCatRef] ?? '');
                          final bCatName = bCatRef == null
                              ? ''
                              : (categoryNameByRef[bCatRef] ?? '');
                          if (aCatName != bCatName) {
                            return aCatName.compareTo(bCatName);
                          }

                          final aName =
                              ProcessLocalizationUtils.resolveLocalizedText(
                            aData['name'],
                            localeCode: localeCode,
                            fallbackLocaleCode:
                                ProcessLocalizationUtils.defaultLocaleCode,
                          );
                          final bName =
                              ProcessLocalizationUtils.resolveLocalizedText(
                            bData['name'],
                            localeCode: localeCode,
                            fallbackLocaleCode:
                                ProcessLocalizationUtils.defaultLocaleCode,
                          );
                          return aName.compareTo(bName);
                        },
                        itemBuilder: (docSnap) {
                          final tRef =
                              docSnap.data()['trainingId'] as DocumentReference?;
                          final tData =
                              (trainingByRef[tRef]?.data() as Map<String, dynamic>?) ??
                                  {};
                          final resolvedName =
                              ProcessLocalizationUtils.resolveLocalizedText(
                            tData['name'],
                            localeCode: localeCode,
                            fallbackLocaleCode:
                                ProcessLocalizationUtils.defaultLocaleCode,
                          );
                          final name =
                              resolvedName.trim().isNotEmpty ? resolvedName : 'Unnamed';
                          final assignedData = docSnap.data();

                          final now = DateTime.now();
                          final complete =
                              assignedData['complete'] as bool? ?? false;
                          final ts = assignedData['goodUntil'] as Timestamp?;
                          IconData? statusIcon;
                          String? statusText;
                          Color? iconColor;

                          if (complete) {
                            statusIcon = Icons.check_circle_outlined;
                            iconColor = AppPaletteScope.of(context).primary2;
                          } else if (ts != null) {
                            final goodUntil = ts.toDate();
                            if (goodUntil.isBefore(now)) {
                              statusIcon = Icons.error;
                              iconColor =
                                  Theme.of(context).colorScheme.error;
                            } else {
                              final daysLeft =
                                  goodUntil.difference(now).inDays;
                              statusText = '$daysLeft days';
                            }
                          } else {
                            statusIcon = Icons.error;
                            iconColor = Theme.of(context).colorScheme.error;
                          }

                          Widget trailingIndicator() {
                            final arrow = Icon(
                              Icons.chevron_right,
                              size: 20,
                              color: Colors.grey[600],
                            );
                            if (statusIcon == null) return arrow;
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcon, size: 20, color: iconColor),
                                const SizedBox(width: 6),
                                arrow,
                              ],
                            );
                          }

                          return StandardTileSmallDart(
                            label: name,
                            leadingIcon: Icons.school_outlined,
                            leadingIconColor: iconColor,
                            secondaryText: statusText,
                            trailingWidget: trailingIndicator(),
                            tileColor: Colors.white,
                          );
                        },
                        onTap: (docSnap) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TrainingAssignedTrainingDetailsScreen(
                                companyRef: companyRef,
                                assignedTrainingId: docSnap.id,
                              ),
                            ),
                          );
                        },
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TrainingLookupTables {
  final Map<DocumentReference, DocumentSnapshot> trainingByRef;
  final Map<DocumentReference, String> categoryNameByRef;

  _TrainingLookupTables({
    required this.trainingByRef,
    required this.categoryNameByRef,
  });
}

