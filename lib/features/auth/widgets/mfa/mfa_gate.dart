// mfa_gate.dart (admin / overlord)
//
// Wraps sensitive content (e.g. the per-company consumer-data drill-in) behind
// a TOTP MFA check. If the user hasn't verified MFA this session, shows
// enrollment (first time) or verification (returning). Satisfies "MFA on
// internal systems that store or process consumer data."
//
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mfa_provider.dart';
import 'totp_enrollment_flow.dart';
import 'totp_verification_flow.dart';

class MfaGate extends ConsumerWidget {
  const MfaGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gateActive = ref.watch(mfaGateActiveProvider);

    if (!gateActive) return child;

    final enrolledAsync = ref.watch(mfaEnrolledProvider);

    return enrolledAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error checking MFA status: $e'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(mfaEnrolledProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (enrolled) {
        return Stack(
          children: [
            if (enrolled)
              const TotpVerificationFlow()
            else
              const TotpEnrollmentFlow(),
            Positioned(
              top: 16,
              left: 16,
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Back'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
