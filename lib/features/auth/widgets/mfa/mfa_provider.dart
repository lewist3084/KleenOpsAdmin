// mfa_provider.dart (admin / overlord)
//
// Riverpod providers for TOTP-based MFA gating on sensitive internal screens
// (e.g. the per-company consumer-data drill-in). Mirrors the main app's MFA.
//
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Tracks when the user last completed MFA verification this session.
/// Resets to `null` on every app launch (fresh provider state).
class MfaVerifiedAtNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  void set(DateTime value) => state = value;

  void clear() => state = null;
}

final mfaVerifiedAtProvider =
    NotifierProvider<MfaVerifiedAtNotifier, DateTime?>(
        MfaVerifiedAtNotifier.new);

/// Whether the MFA gate should block access.
/// Returns `true` if the user has NOT verified MFA this session
/// or if verification was more than 30 minutes ago.
final mfaGateActiveProvider = Provider<bool>((ref) {
  final verifiedAt = ref.watch(mfaVerifiedAtProvider);
  if (verifiedAt == null) return true;
  return DateTime.now().difference(verifiedAt) > const Duration(minutes: 30);
});

/// Whether the current user has enrolled a TOTP second factor.
final mfaEnrolledProvider = FutureProvider.autoDispose<bool>((ref) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;
  final factors = await user.multiFactor.getEnrolledFactors();
  for (final f in factors) {
    if (f.factorId == 'totp') return true;
  }
  return false;
});
