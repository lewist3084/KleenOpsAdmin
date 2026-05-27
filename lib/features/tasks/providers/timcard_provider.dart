import 'package:riverpod/riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';

class TimecardState {
  final bool isClockedIn;
  final Timestamp? clockInTime;
  final DocumentReference<Object?>? activeTaskRef;
  final DocumentReference<Map<String, dynamic>>? memberDocRef;

  TimecardState({
    required this.isClockedIn,
    this.clockInTime,
    this.activeTaskRef,
    this.memberDocRef,
  });

  TimecardState copyWith({
    bool? isClockedIn,
    Timestamp? clockInTime,
    DocumentReference<Object?>? activeTaskRef,
    DocumentReference<Map<String, dynamic>>? memberDocRef,
  }) {
    return TimecardState(
      isClockedIn: isClockedIn ?? this.isClockedIn,
      clockInTime: clockInTime ?? this.clockInTime,
      activeTaskRef: activeTaskRef ?? this.activeTaskRef,
      memberDocRef: memberDocRef ?? this.memberDocRef,
    );
  }
}

// A StreamProvider that listens to the current user's active member document in Firestore in real time.
final userTimecardProvider = StreamProvider.autoDispose<TimecardState>((ref) {
  TimecardState emptyState() => TimecardState(
        isClockedIn: false,
        clockInTime: null,
        activeTaskRef: null,
        memberDocRef: null,
      );

  final memberRefAsync = ref.watch(memberDocRefProvider);
  return memberRefAsync.when(
    data: (memberRef) {
      if (memberRef == null) {
        return Stream.value(emptyState());
      }

      return memberRef.snapshots().map((snapshot) {
        if (!snapshot.exists) {
          return emptyState();
        }
        final data = snapshot.data() ?? <String, dynamic>{};
        return TimecardState(
          isClockedIn: data['clockedIn'] == true,
          clockInTime: data['clockInTime'] as Timestamp?,
          activeTaskRef: data['activeTaskId'] as DocumentReference<Object?>?,
          memberDocRef: snapshot.reference,
        );
      });
    },
    loading: () => Stream.value(emptyState()),
    error: (err, stack) => Stream.error(err, stack),
  );
});
