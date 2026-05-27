// features/safety/providers/safety_provider.dart
import 'package:riverpod/legacy.dart';

/// Holds the index for the active Safety Analysis tab.
final safetyTabIndexProvider = StateProvider<int>((ref) => 0);
