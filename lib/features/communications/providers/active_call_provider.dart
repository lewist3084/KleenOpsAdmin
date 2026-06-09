// Tracks who the current user is currently calling/messaging via the
// communications strip pop-up picker. The ActiveParticipantsBanner
// (mounted above CanvasTopBookend) reads from here so it persists
// across screen navigation as long as the participants list is non-
// empty.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/features/hr/utils/member_file_images.dart';
import 'package:shared_widgets/avatars/avatar_strip_picker.dart';
import 'package:shared_widgets/banners/active_participants_banner.dart';

class ActiveCallParticipant extends BannerParticipant {
  ActiveCallParticipant({
    required super.id,
    required super.name,
    super.imageUrl,
    super.state,
    this.memberRef,
  });

  final DocumentReference<Map<String, dynamic>>? memberRef;

  ActiveCallParticipant copyWith({
    String? name,
    String? imageUrl,
    ParticipantConnectionState? state,
    DocumentReference<Map<String, dynamic>>? memberRef,
  }) {
    return ActiveCallParticipant(
      id: id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      state: state ?? this.state,
      memberRef: memberRef ?? this.memberRef,
    );
  }
}

class ActiveCallNotifier extends StateNotifier<List<ActiveCallParticipant>> {
  ActiveCallNotifier() : super(const <ActiveCallParticipant>[]);

  void add(ActiveCallParticipant participant) {
    if (state.any((p) => p.id == participant.id)) return;
    state = [...state, participant];
  }

  /// Update a single participant's connection state. No-op if [id] is
  /// not in the current list (caller adds first via [add]).
  void setParticipantState(String id, ParticipantConnectionState newState) {
    var changed = false;
    final next = <ActiveCallParticipant>[];
    for (final p in state) {
      if (p.id == id && p.state != newState) {
        next.add(p.copyWith(state: newState));
        changed = true;
      } else {
        next.add(p);
      }
    }
    if (changed) state = next;
  }

  /// Bulk update — pass a map of {memberId: newState}.
  void applyStates(Map<String, ParticipantConnectionState> states) {
    var changed = false;
    final next = <ActiveCallParticipant>[];
    for (final p in state) {
      final s = states[p.id];
      if (s != null && s != p.state) {
        next.add(p.copyWith(state: s));
        changed = true;
      } else {
        next.add(p);
      }
    }
    if (changed) state = next;
  }

  void remove(String id) {
    state = [
      for (final p in state)
        if (p.id != id) p,
    ];
  }

  void clear() => state = const <ActiveCallParticipant>[];
}

final activeCallProvider =
    StateNotifierProvider<ActiveCallNotifier, List<ActiveCallParticipant>>(
  (ref) => ActiveCallNotifier(),
);

/// Candidates for the comms-strip pop-up picker: members of the
/// current user's primary team, excluding the user themselves.
///
/// Intentionally does NOT watch [activeCallProvider]. Filtering out
/// already-selected participants happens at the call site so adding
/// someone to the call doesn't invalidate this future and force the
/// picker row to flash a loading spinner.
final commsPickerCandidatesProvider =
    FutureProvider.autoDispose<List<PickerCandidate>>((ref) async {
  // ADMIN: calling is scoped to the tenant company the overlord is a member of
  // (where call invitees actually ring), resolved from the mailbox member ref —
  // company = member.parent.parent. The kleenops primary-team restriction is
  // dropped so the overlord can call any active company member.
  final selfMemberRef = ref.watch(mailboxMemberRefProvider).asData?.value;
  final companyRef = selfMemberRef?.parent.parent;
  if (companyRef == null) return const [];

  final snapshot = await companyRef
      .collection('member')
      .where('active', isEqualTo: true)
      .get();

  final candidates = <PickerCandidate>[];
  for (final doc in snapshot.docs) {
    if (selfMemberRef != null && doc.reference.path == selfMemberRef.path) {
      continue;
    }
    final data = doc.data();
    final name = (data['name'] as String?)?.trim().isNotEmpty == true
        ? data['name'] as String
        : doc.id;
    String? imageUrl;
    try {
      imageUrl = await MemberFileImages.primaryProfileImageUrl(
        companyRef: companyRef,
        memberId: doc.id,
      );
    } catch (_) {
      imageUrl = null;
    }
    candidates.add(PickerCandidate(
      id: doc.id,
      name: name,
      imageUrl: (imageUrl != null && imageUrl.isNotEmpty) ? imageUrl : null,
    ));
  }
  candidates.sort((a, b) => a.name.compareTo(b.name));
  return candidates;
});
