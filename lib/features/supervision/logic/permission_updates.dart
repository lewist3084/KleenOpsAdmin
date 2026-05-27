// lib/features/supervision/logic/permission_updates.dart

/// Builds a Firestore update map for a permission toggle and clears any
/// dependent task settings when the permission is revoked.
Map<String, Object?> buildPermissionUpdate({
  required String permissionKey,
  required bool enabled,
}) {
  final updates = <String, Object?>{permissionKey: enabled};

  // When access is revoked, ensure any gated task settings are also reset.
  if (!enabled) {
    switch (permissionKey) {
      case 'canDisablePacing':
        updates['disablePacing'] = false;
        break;
      case 'canOverride':
        updates['overrideActionFilter'] = false;
        break;
      default:
        break;
    }
  }

  return updates;
}
