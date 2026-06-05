// lib/common/resources/menu_badges.dart
//
// Live unread / missed counters for the menu-drawer Communications section.
// Ported from the main KleenOps app. Each provider streams a server-maintained
// counter off the signed-in overlord member doc (`kleenops/{id}/member/{mid}`)
// so the red badges in the drawer reflect reality.
//
// The counters are written by Cloud Functions notification triggers
// (`unreadTextCount`, `unreadEmailCount`, `missedVoiceCallCount`,
// `missedVideoCallCount`, `unreadBulletinCount`) and cleared to 0 by the
// matching screen when the user opens it (see NotificationBadgeService).
// They degrade gracefully to 0 when the field is absent on the overlord doc.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';

/// Streams the signed-in member doc. One Firestore listener feeds every
/// per-modality communication badge below.
final _memberBadgeDocProvider =
    StreamProvider.autoDispose<Map<String, dynamic>>((ref) {
  final memberRef = ref.watch(memberDocRefProvider).value;
  if (memberRef == null) {
    return const Stream<Map<String, dynamic>>.empty();
  }
  return memberRef
      .snapshots()
      .map((snap) => snap.data() ?? const <String, dynamic>{});
});

int _count(AsyncValue<Map<String, dynamic>> doc, String key) {
  return doc.maybeWhen(
    data: (data) => (data[key] as num?)?.toInt() ?? 0,
    orElse: () => 0,
  );
}

/// Unread text-message conversations.
final unreadTextBadgeProvider = Provider.autoDispose<int>(
  (ref) => _count(ref.watch(_memberBadgeDocProvider), 'unreadTextCount'),
);

/// Unread INBOX emails.
final unreadEmailBadgeProvider = Provider.autoDispose<int>(
  (ref) => _count(ref.watch(_memberBadgeDocProvider), 'unreadEmailCount'),
);

/// Missed voice (phone) calls.
final missedVoiceCallBadgeProvider = Provider.autoDispose<int>(
  (ref) => _count(ref.watch(_memberBadgeDocProvider), 'missedVoiceCallCount'),
);

/// Missed video calls.
final missedVideoCallBadgeProvider = Provider.autoDispose<int>(
  (ref) => _count(ref.watch(_memberBadgeDocProvider), 'missedVideoCallCount'),
);

/// New (unread) message-board posts.
final unreadBulletinBadgeProvider = Provider.autoDispose<int>(
  (ref) => _count(ref.watch(_memberBadgeDocProvider), 'unreadBulletinCount'),
);

/// Pending "My Tasks" action items assigned to the signed-in member
/// (`kleenops/{id}/member/{mid}/myTask` where status == 'pending').
final myTasksBadgeProvider = StreamProvider.autoDispose<int>((ref) {
  final memberRef = ref.watch(memberDocRefProvider).value;
  if (memberRef == null) return Stream<int>.value(0);
  return memberRef
      .collection('myTask')
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((snap) => snap.docs.length);
});

/// Plain-int view of [myTasksBadgeProvider] for the menu drawer badge.
final myTasksPendingCountProvider = Provider.autoDispose<int>(
  (ref) => ref.watch(myTasksBadgeProvider).maybeWhen(
        data: (value) => value,
        orElse: () => 0,
      ),
);

/// Scheduled reminders owned by the signed-in member
/// (`kleenops/{id}/reminder` where ownerMemberId == me && status == 'scheduled').
final remindersBadgeProvider = StreamProvider.autoDispose<int>((ref) {
  final memberRef = ref.watch(memberDocRefProvider).value;
  final companyRef = ref.watch(companyIdProvider).value;
  if (memberRef == null || companyRef == null) return Stream<int>.value(0);
  return companyRef
      .collection('reminder')
      .where('ownerMemberId', isEqualTo: memberRef.id)
      .where('status', isEqualTo: 'scheduled')
      .snapshots()
      .map((snap) => snap.docs.length);
});

/// Plain-int view of [remindersBadgeProvider] for the menu drawer badge.
final remindersPendingCountProvider = Provider.autoDispose<int>(
  (ref) => ref.watch(remindersBadgeProvider).maybeWhen(
        data: (value) => value,
        orElse: () => 0,
      ),
);

/// Builds a reactive red badge widget for a [ContentMenuItem.badge] slot,
/// bound to one of the badge providers above. The drawer overlays it on
/// the top-right corner of the row's icon.
Widget menuBadge(Provider<int> provider) {
  return Consumer(
    builder: (_, ref, __) => MenuBadge(count: ref.watch(provider)),
  );
}

/// Small round red count badge for the menu drawer, overlaid on the
/// top-right corner of a Communications icon. Renders an empty box (no
/// badge) when [count] is zero — so it can be dropped into a
/// [ContentMenuItem.badge] slot unconditionally.
class MenuBadge extends StatelessWidget {
  const MenuBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFE53935), // red 600
        borderRadius: BorderRadius.circular(10),
        // White ring so the pill reads clearly when it overlaps the icon.
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          height: 1.0,
        ),
      ),
    );
  }
}
