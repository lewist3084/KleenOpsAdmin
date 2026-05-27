// lib/features/tasks/providers/tasks_provider.dart

import 'package:riverpod/riverpod.dart';
import 'package:riverpod/legacy.dart';

// Keeps track of the currently selected tab index in TasksTasksTabs
final tasksTabIndexProvider = StateProvider<int>((ref) => 0);

// NOTE (admin port, foundation phase): `userDocProvider` was stripped here
// — it depended on `userRepositoryProvider` from
// `package:kleenops/repositories/user_repository.dart`, which admin does
// not yet provide. Re-introduce when the repository layer (or a direct
// FirebaseFirestore-based equivalent) lands in admin.
