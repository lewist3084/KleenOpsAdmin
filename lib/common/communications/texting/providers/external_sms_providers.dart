// Gating for external (Twilio) SMS: a member can only text externally if a
// number is assigned to them (denormalized onto the member doc as
// `smsNumberE164` by the assignSmsNumberToMember callable).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';

/// The current member's assigned external-texting number (E.164), or null.
final assignedSmsNumberProvider = StreamProvider.autoDispose<String?>((ref) {
  final memberRef = ref.watch(memberDocRefProvider).value;
  if (memberRef == null) return Stream<String?>.value(null);
  return memberRef
      .snapshots()
      .map((snap) => snap.data()?['smsNumberE164'] as String?);
});

/// Whether the current member can use external SMS (has a number assigned).
final hasAssignedSmsNumberProvider = Provider.autoDispose<bool>((ref) {
  final number = ref.watch(assignedSmsNumberProvider).value;
  return number != null && number.isNotEmpty;
});

