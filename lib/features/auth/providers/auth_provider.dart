// lib/features/auth/providers/auth_provider.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stream of Firebase Auth state changes.
final authStateChangesProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// Whether the current user is authenticated.
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authAsync = ref.watch(authStateChangesProvider);
  return authAsync.maybeWhen(data: (user) => user != null, orElse: () => false);
});

/// Current user UID (null if not authenticated).
final currentUidProvider = Provider<String?>((ref) {
  final authAsync = ref.watch(authStateChangesProvider);
  return authAsync.maybeWhen(data: (user) => user?.uid, orElse: () => null);
});
