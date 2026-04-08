// lib/features/registration/screens/registration_join_qr_screen.dart
//
// Shown when the user picks "Join an Existing Company" on the first
// registration fork. Displays the user's UID as a QR code so an existing
// admin can scan it to add them as a member.

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_plugin/qr_plugin.dart';

import '../../../app/routes.dart';
import '../../../theme/palette.dart';

class RegistrationJoinQrScreen extends StatelessWidget {
  const RegistrationJoinQrScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const palette = adminPalette;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    /* ─── Circular icon ─── */
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: palette.primary3.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.qr_code_2,
                          size: 56, color: palette.primary3),
                    ),
                    const SizedBox(height: 32),

                    /* ─── Title ─── */
                    Text(
                      'Join an Existing Company',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: palette.primary3,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    /* ─── Body ─── */
                    Text(
                      'Have your admin scan this code to add you to their '
                      'organization.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.grey.shade700,
                            height: 1.5,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),

                    /* ─── QR code ─── */
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: palette.primary3.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: uid.isEmpty
                          ? const SizedBox(
                              width: 240,
                              height: 240,
                              child: Center(
                                child: Text('Not signed in'),
                              ),
                            )
                          : QrImageView(data: uid, size: 240),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Waiting for an admin to scan...',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade500,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            // Back arrow last so it sits on top of the scroll view.
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back',
                onPressed: () => context.go(AppRoutePaths.registrationFork),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
