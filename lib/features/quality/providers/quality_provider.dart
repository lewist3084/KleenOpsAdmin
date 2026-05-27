// features/quality/providers/quality_provider.dart
import 'package:riverpod/legacy.dart';

/// Holds the index for the active Quality tab.
final qualityTabIndexProvider = StateProvider<int>((ref) => 0);
