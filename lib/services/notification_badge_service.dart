import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Slim badge-clearing service for the admin app. Ported from the main
/// KleenOps app, trimmed to the Firestore side only — the admin app has no
/// FCM / local-notifications wiring, so there is no OS-icon badge handling.
///
/// The per-modality counters live on the signed-in overlord member doc
/// (`kleenops/{id}/member/{mid}`) and feed the drawer badges via
/// `menu_badges.dart`. A screen calls the matching `clear*` method on open to
/// zero its counter for snappy UI; Cloud Functions recompute the count on the
/// next notification.
///
/// Note: there is intentionally no `clearTextBadge` / `clearEmailBadge` —
/// `unreadTextCount` / `unreadEmailCount` are true unread counts maintained
/// server-side and drop as individual messages are marked read.
class NotificationBadgeService {
  NotificationBadgeService._();
  static final NotificationBadgeService instance =
      NotificationBadgeService._();

  Future<void> clearVoiceCallBadge(
          DocumentReference<Map<String, dynamic>>? memberRef) =>
      _clearField('missedVoiceCallCount', memberRef);

  Future<void> clearVideoCallBadge(
          DocumentReference<Map<String, dynamic>>? memberRef) =>
      _clearField('missedVideoCallCount', memberRef);

  Future<void> clearBulletinBadge(
          DocumentReference<Map<String, dynamic>>? memberRef) =>
      _clearField('unreadBulletinCount', memberRef);

  Future<void> _clearField(
    String firestoreField,
    DocumentReference<Map<String, dynamic>>? memberRef,
  ) async {
    if (memberRef == null) return;
    try {
      await memberRef.update({firestoreField: 0});
    } catch (e) {
      debugPrint('NotificationBadgeService clear $firestoreField failed: $e');
    }
  }
}
