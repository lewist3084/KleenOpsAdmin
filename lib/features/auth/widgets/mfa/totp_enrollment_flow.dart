// totp_enrollment_flow.dart (admin / overlord)
//
// First-time TOTP MFA enrollment: generates a secret, shows QR code,
// and verifies the user's 6-digit code to complete enrollment.
//
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_plugin/qr_plugin.dart';

import 'mfa_provider.dart';

class TotpEnrollmentFlow extends ConsumerStatefulWidget {
  const TotpEnrollmentFlow({super.key});

  @override
  ConsumerState<TotpEnrollmentFlow> createState() =>
      _TotpEnrollmentFlowState();
}

enum _EnrollStep { loading, showQr, done, error }

class _TotpEnrollmentFlowState extends ConsumerState<TotpEnrollmentFlow> {
  _EnrollStep _step = _EnrollStep.loading;
  TotpSecret? _secret;
  String? _qrUri;
  String? _errorMessage;
  final _codeCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _generateSecret();
  }

  Future<void> _generateSecret() async {
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final session = await user.multiFactor.getSession();
      final secret =
          await TotpMultiFactorGenerator.generateSecret(session);
      final uri = await secret.generateQrCodeUrl(
        accountName: user.email ?? user.uid,
        issuer: 'KleenOps Admin',
      );
      if (!mounted) return;
      setState(() {
        _secret = secret;
        _qrUri = uri;
        _step = _EnrollStep.showQr;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to generate secret: $e';
        _step = _EnrollStep.error;
      });
    }
  }

  Future<void> _verifyCode() async {
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
      final user = FirebaseAuth.instance.currentUser!;
      final assertion =
          await TotpMultiFactorGenerator.getAssertionForEnrollment(
        _secret!,
        code,
      );
      await user.multiFactor.enroll(assertion, displayName: 'Authenticator');

      if (!mounted) return;
      // Mark MFA as verified for this session.
      ref.read(mfaVerifiedAtProvider.notifier).set(DateTime.now());
      // Invalidate enrolled check so the gate re-evaluates.
      ref.invalidate(mfaEnrolledProvider);
      setState(() => _step = _EnrollStep.done);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message ?? 'Invalid verification code';
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
      case _EnrollStep.loading:
        return const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Setting up two-factor authentication...'),
          ],
        );

      case _EnrollStep.showQr:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.security, size: 48, color: Colors.blueGrey),
            const SizedBox(height: 12),
            const Text(
              'Set Up Two-Factor Authentication',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Scan the QR code below with your authenticator app '
              '(e.g., Google Authenticator, Authy).',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (_qrUri != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: QrImageView(
                  data: _qrUri!,
                  version: QrVersions.auto,
                  size: 200,
                ),
              ),
            const SizedBox(height: 20),
            Text(
              'Then enter the 6-digit code from your authenticator app:',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
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
                onPressed: _submitting ? null : _verifyCode,
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
                    : const Text('Verify & Enable'),
              ),
            ),
          ],
        );

      case _EnrollStep.done:
        return const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text(
              'Two-Factor Authentication Enabled',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Your account is now protected with TOTP.'),
          ],
        );

      case _EnrollStep.error:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage ?? 'An error occurred'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() => _step = _EnrollStep.loading);
                _generateSecret();
              },
              child: const Text('Retry'),
            ),
          ],
        );
    }
  }
}
