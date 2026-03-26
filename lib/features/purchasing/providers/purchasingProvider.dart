// features/purchasing/providers/purchasingProvider.dart
import 'package:riverpod/legacy.dart';

/// Holds the index for the active Purchasing Orders tab.
final purchasingTabIndexProvider = StateProvider<int>((ref) => 0);
