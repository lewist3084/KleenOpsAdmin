// lib/features/quality/widgets/quality_timeline_tile.dart
//
// Shared tile widget for rendering timeline quality records. Shows the
// report's master image, the quality issue name, the subject member, and
// supporting metadata (object, task).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/tiles/standard_tile_large.dart';

class QualityTimelineTile extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final DocumentReference<Map<String, dynamic>> companyRef;

  const QualityTimelineTile({
    super.key,
    required this.doc,
    required this.companyRef,
  });

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final title = data['title'] as String? ?? 'Quality Issue';
    final initialMemberName = _extractMemberName(data);
    final initialObjectName = _extractObjectName(data);
    final initialTaskName = _extractTaskName(data);

    return FutureBuilder<_QualityTileData>(
      future: _resolve(
        data,
        initialMemberName,
        initialObjectName,
        initialTaskName,
      ),
      builder: (context, snapshot) {
        final resolved = snapshot.data;
        final memberName =
            resolved?.memberName ?? (initialMemberName ?? '');
        final objectName =
            resolved?.objectName ?? (initialObjectName ?? '');
        final taskName = resolved?.taskName ?? (initialTaskName ?? '');
        final imageUrl = resolved?.imageUrl ?? '';

        return StandardTileLargeDart(
          imageUrl: imageUrl,
          showImage: imageUrl.isNotEmpty,
          firstLine: title,
          firstLineIcon: Icons.science_outlined,
          secondLine: memberName,
          secondLineIcon: Icons.person_outline,
          thirdLine: objectName,
          thirdLineIcon: Icons.home_work_outlined,
          fourthLine: taskName,
          fourthLineIcon: Icons.assignment_outlined,
        );
      },
    );
  }

  Future<_QualityTileData> _resolve(
    Map<String, dynamic> data,
    String? initialMemberName,
    String? initialObjectName,
    String? initialTaskName,
  ) async {
    final results = await Future.wait([
      _memberNameFuture(data, initialMemberName),
      _objectNameFuture(data, initialObjectName),
      _taskNameFuture(data, initialTaskName),
      _imageUrlFuture(),
    ]);
    return _QualityTileData(
      memberName: results[0],
      objectName: results[1],
      taskName: results[2],
      imageUrl: results[3],
    );
  }

  /// Resolves the report's display image: the first image file in the
  /// `file` collection linked to this quality doc, preferring the master.
  Future<String> _imageUrlFuture() async {
    try {
      final snap = await companyRef
          .collection('file')
          .where('qualityId', isEqualTo: doc.reference)
          .get();
      if (snap.docs.isEmpty) return '';

      final candidates = <_FileCandidate>[];
      var fallbackOrder = 0;
      for (final fileDoc in snap.docs) {
        final fileData = fileDoc.data();
        final url = _firstString(
          fileData,
          const ['downloadUrl', 'url', 'fileUrl', 'imageUrl'],
        );
        if (url == null || url.isEmpty) continue;
        final type = (fileData['fileType'] ?? fileData['mediaType'] ?? '')
            .toString()
            .toLowerCase();
        if (!type.contains('image')) continue;
        final order = fileData['order'] is num
            ? (fileData['order'] as num).toInt()
            : fallbackOrder;
        candidates.add(
          _FileCandidate(
            url: url,
            order: order,
            isMaster: fileData['isMaster'] == true,
          ),
        );
        fallbackOrder += 1;
      }
      if (candidates.isEmpty) return '';
      candidates.sort((a, b) {
        if (a.isMaster != b.isMaster) {
          return a.isMaster ? -1 : 1;
        }
        return a.order.compareTo(b.order);
      });
      return candidates.first.url;
    } catch (_) {
      return '';
    }
  }

  /// Resolves the subject member's name — denormalized field first, then the
  /// `memberId` reference.
  Future<String> _memberNameFuture(
    Map<String, dynamic> data,
    String? initial,
  ) async {
    if (initial != null && initial.trim().isNotEmpty) {
      return initial.trim();
    }
    final raw = data['memberId'];
    if (raw is! DocumentReference) return '';
    try {
      final ref = raw.withConverter<Map<String, dynamic>>(
        fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
        toFirestore: (value, _) => value,
      );
      final snap = await ref.get();
      final memberData = snap.data();
      if (memberData == null) return '';
      return _firstString(
            memberData,
            const ['name', 'displayName', 'fullName'],
          ) ??
          '';
    } catch (_) {
      return '';
    }
  }

  Future<String> _objectNameFuture(
    Map<String, dynamic> data,
    String? initial,
  ) async {
    if (initial != null && initial.trim().isNotEmpty) {
      return initial.trim();
    }
    final ref = _resolveObjectRef(data);
    if (ref == null) return '';
    try {
      final snap = await ref.get();
      final objData = snap.data();
      if (objData == null) return '';
      final local = objData['localName'] as String?;
      final name = objData['name'] as String?;
      return (local ?? name ?? '').toString().trim();
    } catch (_) {
      return '';
    }
  }

  Future<String> _taskNameFuture(
    Map<String, dynamic> data,
    String? initial,
  ) async {
    if (initial != null && initial.trim().isNotEmpty) {
      return initial.trim();
    }
    final ref = _resolveTaskRef(data);
    if (ref == null) return '';
    try {
      final snap = await ref.get();
      final taskData = snap.data();
      if (taskData == null) return '';
      final name = taskData['name'] as String?;
      final title = taskData['title'] as String?;
      return (name ?? title ?? '').toString().trim();
    } catch (_) {
      return '';
    }
  }

  DocumentReference<Map<String, dynamic>>? _resolveObjectRef(
    Map<String, dynamic> data,
  ) {
    final raw = data['companyObjectId'] ??
        data['objectId'] ??
        _firstFromList(data['objectIds']);
    return _toDocRef(raw, 'companyObject');
  }

  DocumentReference<Map<String, dynamic>>? _resolveTaskRef(
    Map<String, dynamic> data,
  ) {
    final raw = data['taskId'] ?? data['taskRef'];
    return _toDocRef(raw, 'task');
  }

  DocumentReference<Map<String, dynamic>>? _toDocRef(
    dynamic raw,
    String collection,
  ) {
    if (raw is DocumentReference) {
      return raw.withConverter<Map<String, dynamic>>(
        fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
        toFirestore: (value, _) => value,
      );
    }
    if (raw is String && raw.trim().isNotEmpty) {
      return companyRef
          .collection(collection)
          .doc(raw.trim())
          .withConverter<Map<String, dynamic>>(
            fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
            toFirestore: (value, _) => value,
          );
    }
    return null;
  }

  String? _extractMemberName(Map<String, dynamic> data) {
    return _firstString(data, const [
      'memberName',
      'memberDisplayName',
      'memberFullName',
      'memberTitle',
    ]);
  }

  String? _extractObjectName(Map<String, dynamic> data) {
    return _firstString(data, const [
      'companyObjectName',
      'objectName',
      'objectLocalName',
    ]);
  }

  String? _extractTaskName(Map<String, dynamic> data) {
    return _firstString(data, const [
      'taskName',
      'taskTitle',
      'taskDisplayName',
    ]);
  }

  String? _firstString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  dynamic _firstFromList(dynamic raw) {
    if (raw is Iterable && raw.isNotEmpty) {
      return raw.first;
    }
    return null;
  }
}

class _QualityTileData {
  const _QualityTileData({
    required this.memberName,
    required this.objectName,
    required this.taskName,
    required this.imageUrl,
  });

  final String memberName;
  final String objectName;
  final String taskName;
  final String imageUrl;
}

class _FileCandidate {
  const _FileCandidate({
    required this.url,
    required this.order,
    required this.isMaster,
  });

  final String url;
  final int order;
  final bool isMaster;
}
