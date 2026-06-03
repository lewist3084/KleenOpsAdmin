import 'package:cloud_firestore/cloud_firestore.dart';

enum DriveType { personal, shared, public }

DriveType _parseDriveType(String? raw) {
  switch (raw) {
    case 'personal':
      return DriveType.personal;
    case 'shared':
      return DriveType.shared;
    case 'public':
      return DriveType.public;
    default:
      return DriveType.shared;
  }
}

String driveTypeKey(DriveType t) {
  switch (t) {
    case DriveType.personal:
      return 'personal';
    case DriveType.shared:
      return 'shared';
    case DriveType.public:
      return 'public';
  }
}

/// A drive is the access boundary for files.
///
/// - `personal` â€” exactly one per member, auto-created. `ownerMemberId` is the
///   only principal with access. Cannot be shared, cannot be deleted.
/// - `shared`   â€” manually created (HR, Operations, Finance, â€¦). Access is
///   granted via `memberIds` and/or `teamIds`. Anyone listed has full access.
/// - `public`   â€” visible and writable by every company member. The one
///   auto-created company-wide drive is a public drive flagged
///   `isCompanyDrive: true`; additional public drives can also be created.
class DriveModel {
  DriveModel({
    required this.id,
    required this.ref,
    required this.type,
    required this.name,
    this.description,
    this.icon,
    this.color,
    this.isCompanyDrive = false,
    this.ownerMemberId,
    this.memberIds = const [],
    this.teamIds = const [],
    this.createdAt,
    this.createdBy,
  });

  final String id;
  final DocumentReference<Map<String, dynamic>> ref;
  final DriveType type;
  final String name;
  final String? description;
  final String? icon;
  final String? color;

  /// True for the single auto-created company-wide drive ("Company Drive").
  /// It is a public drive that cannot be deleted or renamed.
  final bool isCompanyDrive;

  /// Set for `personal` drives only. Equals the member doc id (which mirrors
  /// the auth uid in this codebase).
  final String? ownerMemberId;

  /// Member doc ids with access (for `shared` drives).
  final List<String> memberIds;

  /// Team doc ids whose members all have access (for `shared` drives).
  final List<String> teamIds;

  final DateTime? createdAt;
  final DocumentReference<Map<String, dynamic>>? createdBy;

  /// System drives are auto-managed and cannot be renamed or deleted by users.
  bool get isSystem => type == DriveType.personal || isCompanyDrive;

  /// Drive description, falling back to a sensible default per drive kind so
  /// every drive header reads with both a name and a short note about its
  /// contents even before anyone sets a custom description.
  String get descriptionOrDefault {
    final d = description?.trim();
    if (d != null && d.isNotEmpty) return d;
    if (isCompanyDrive) {
      return 'Files shared across the whole company. Everyone can view and add.';
    }
    switch (type) {
      case DriveType.personal:
        return 'Your private files. Only you can see what you keep here.';
      case DriveType.shared:
        return 'Files shared with the people and teams granted access.';
      case DriveType.public:
        return 'Files available to everyone in the company.';
    }
  }

  /// Short label shown under the drive name on a drive card.
  String get typeLabel {
    if (isCompanyDrive) return 'Company drive';
    switch (type) {
      case DriveType.personal:
        return 'Personal';
      case DriveType.shared:
        return 'Shared drive';
      case DriveType.public:
        return 'Public drive';
    }
  }

  bool canAccess({
    required String memberId,
    required Set<String> userTeamIds,
  }) {
    switch (type) {
      case DriveType.public:
        return true;
      case DriveType.personal:
        return ownerMemberId == memberId;
      case DriveType.shared:
        if (memberIds.contains(memberId)) return true;
        for (final t in teamIds) {
          if (userTeamIds.contains(t)) return true;
        }
        return false;
    }
  }

  factory DriveModel.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final d = snap.data() ?? {};
    return DriveModel(
      id: snap.id,
      ref: snap.reference,
      type: _parseDriveType(d['type'] as String?),
      name: (d['name'] as String?) ?? '',
      description: d['description'] as String?,
      icon: d['icon'] as String?,
      color: d['color'] as String?,
      isCompanyDrive: (d['isCompanyDrive'] as bool?) ?? false,
      ownerMemberId: d['ownerMemberId'] as String?,
      memberIds: List<String>.from(d['memberIds'] as List? ?? const []),
      teamIds: List<String>.from(d['teamIds'] as List? ?? const []),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      createdBy:
          d['createdBy'] as DocumentReference<Map<String, dynamic>>?,
    );
  }

  Map<String, dynamic> toCreateMap() => {
        'type': driveTypeKey(type),
        'name': name,
        if (description != null) 'description': description,
        if (icon != null) 'icon': icon,
        if (color != null) 'color': color,
        if (isCompanyDrive) 'isCompanyDrive': true,
        if (ownerMemberId != null) 'ownerMemberId': ownerMemberId,
        'memberIds': memberIds,
        'teamIds': teamIds,
        'createdAt': FieldValue.serverTimestamp(),
        if (createdBy != null) 'createdBy': createdBy,
      };
}

