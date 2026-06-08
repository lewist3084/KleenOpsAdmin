// totp_verification_flow.dart (admin / overlord)
//
// Returning-user TOTP verification: re-authenticates the user to trigger
// the MFA challenge, then resolves with the user's 6-digit TOTP code.
//
// Web-first (the admin console runs on the web): Google users re-auth via
// `reauthenticateWithProvider` (no google_sign_in dependency); email/password
// users re-auth with their password.
//
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'mfa_provider.dart';

class TotpVerificationFlow extends ConsumerStatefulWidget {
  const TotpVerificationFlow({super.key});

  @override
  ConsumerState<TotpVerificationFlow> createState() =>
      _TotpVerificationFlowState();
}

enum _VerifyStep { reauth, codeEntry, done, error }

class _TotpVerificationFlowState
    extends ConsumerState<TotpVerificationFlow> {
  _VerifyStep _step = _VerifyStep.reauth;
  MultiFactorResolver? _resolver;
  String? _errorMessage;
  final _codeCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _submitting = false;

  // Detect if user signed in with Google vs email/password.
  bool get _isGoogleUser {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    return user.providerData.any((p) => p.providerId == 'google.com');
  }

  @override
  void initState() {
    super.initState();
    // For Google users, attempt re-auth immediately.
    if (_isGoogleUser) {
      _reauthWithGoogle();
    }
    // For email/password users, show password prompt (_step stays reauth).
  }

  Future<void> _reauthWithGoogle() async {
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser!;
      await user.reauthenticateWithProvider(GoogleAuthProvider());

      // If re-auth succeeds without MFA challenge, user is verified.
      if (!mounted) return;
      ref.read(mfaVerifiedAtProvider.notifier).set(DateTime.now());
      setState(() => _step = _VerifyStep.done);
    } on FirebaseAuthMultiFactorException catch (e) {
      // MFA challenge triggered — show code entry.
      if (!mounted) return;
      setState(() {
        _resolver = e.resolver;
        _step = _VerifyStep.codeEntry;
        _submitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Re-authentication failed: $e';
        _step = _VerifyStep.error;
        _submitting = false;
      });
    }
  }

  Future<void> _reauthWithPassword() async {
    final pw = _pwCtrl.text.trim();
    if (pw.isEmpty) {
      setState(() => _errorMessage = 'Please enter your password');
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: pw,
      );
      await user.reauthenticateWithCredential(credential);

      // If re-auth succeeds without MFA challenge, user is verified.
      if (!mounted) return;
      ref.read(mfaVerifiedAtProvider.notifier).set(DateTime.now());
      setState(() => _step = _VerifyStep.done);
    } on FirebaseAuthMultiFactorException catch (e) {
      if (!mounted) return;
      setState(() {
        _resolver = e.resolver;
        _step = _VerifyStep.codeEntry;
        _submitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Re-authentication failed: $e';
        _submitting = false;
      });
    }
  }

  Future<void> _submitCode() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Please enter a 6-digit code');
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      // Find the TOTP hint from the resolver.
      final hints = _resolver!.hints;
      MultiFactorInfo? totpHint;
      for (final h in hints) {
        if (h.factorId == 'totp') {
          totpHint = h;
          break;
        }
      }
      if (totpHint == null) {
        throw Exception('No TOTP factor found in MFA challenge');
      }

      final assertion =
          await TotpMultiFactorGenerator.getAssertionForSignIn(
        totpHint.uid,
        code,
      );
      await _resolver!.resolveSignIn(assertion);

      if (!mounted) return;
      ref.read(mfaVerifiedAtProvider.notifier).set(DateTime.now());
      setState(() => _step = _VerifyStep.done);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message ?? 'Invalid code. Please try again.';
        _submitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Verification failed: $e';
        _submitting = false;
      });
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: _buildContent(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_step) {
      case _VerifyStep.reauth:
        // Only shown for email/password users who need to enter password.
        if (_isGoogleUser) {
          return const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Verifying your identity...'),
            ],
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48, color: Colors.blueGrey),
            const SizedBox(height: 12),
            const Text(
              'Verify Your Identity',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter your password to continue.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _pwCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              textInputAction: TextInputAction.done,
              onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _reauthWithPassword,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Continue'),
              ),
            ),
          ],
        );

      case _VerifyStep.codeEntry:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.security, size: 48, color: Colors.blueGrey),
            const SizedBox(height: 12),
            const Text(
              'Two-Factor Authentication',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter the 6-digit code from your authenticator app.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 180,
              child: TextField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  letterSpacing: 8,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '000000',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 16,
                  ),
                ),
                textInputAction: TextInputAction.done,
                onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submitCode,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Verify'),
              ),
            ),
          ],
        );

      case _VerifyStep.done:
        return const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text(
              'Identity Verified',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        );

      case _VerifyStep.error:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'An error occurred',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _step = _VerifyStep.reauth;
                  _errorMessage = null;
                  _submitting = false;
                });
                if (_isGoogleUser) _reauthWithGoogle();
              },
              child: const Text('Retry'),
            ),
          ],
        );
    }
  }
}
