// features/objects/providers/objects_provider.dart
import 'package:riverpod/legacy.dart';

/// Holds the index for the active Objects tab.
final objectsTabIndexProvider =
    StateProvider.autoDispose<int>((ref) => 0);
