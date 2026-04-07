/* ────────────────────────────────────────────────────────────
   lib/features/onboarding/guides/guide_dismissal_provider.dart
   – Tracks which setup guides have been dismissed:
     * Session-level (in-memory, resets on restart)
     * Permanent (Firestore user doc, survives restarts)
   ──────────────────────────────────────────────────────────── */
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:kleenops_admin/constants/firestore_paths.dart';

/* ─── Session dismissals (in-memory) ──────────────────────── */

/// Set of guide keys dismissed for this session only.
/// Resets when the app restarts.
final sessionDismissedGuidesProvider =
    NotifierProvider<_SessionDismissedNotifier, Set<String>>(
        _SessionDismissedNotifier.new);

class _SessionDismissedNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  void dismiss(String guideKey) => state = {...state, guideKey};
}

/* ─── Permanent dismissals (Firestore) ────────────────────── */

/// Streams the set of permanently dismissed guide keys from
/// the user doc's `dismissedGuides` map.
final permanentDismissedGuidesProvider = StreamProvider<Set<String>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value(<String>{});

  return FirebaseFirestore.instance
      .collection(colUser)
      .doc(user.uid)
      .snapshots()
      .map((snap) {
    final data = snap.data();
    if (data == null) return <String>{};
    final map = data['dismissedGuides'];
    if (map is Map) {
      return map.entries
          .where((e) => e.value == true)
          .map((e) => e.key as String)
          .toSet();
    }
    return <String>{};
  });
});

/* ─── Combined: should a guide be shown? ──────────────────── */

/// Returns true if the guide should be shown (not dismissed
/// either for this session or permanently).
final shouldShowGuideProvider =
    Provider.family<bool, String>((ref, guideKey) {
  // Check permanent dismissals
  final permanentSet =
      ref.watch(permanentDismissedGuidesProvider).asData?.value ?? {};
  if (permanentSet.contains(guideKey)) return false;

  // Check session dismissals
  final sessionSet = ref.watch(sessionDismissedGuidesProvider);
  if (sessionSet.contains(guideKey)) return false;

  return true;
});

/* ─── Actions ─────────────────────────────────────────────── */

/// Dismiss a guide for the current session only.
void dismissGuideForSession(WidgetRef ref, String guideKey) {
  ref.read(sessionDismissedGuidesProvider.notifier).dismiss(guideKey);
}

/// Permanently dismiss a guide (saves to Firestore).
Future<void> dismissGuidePermanently(String guideKey) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  await FirebaseFirestore.instance
      .collection(colUser)
      .doc(user.uid)
      .set({
    'dismissedGuides': {guideKey: true},
  }, SetOptions(merge: true));
}
