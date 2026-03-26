// lib/features/sales/providers/marketingProvider.dart
import 'package:riverpod/legacy.dart';

/// Holds the index for the active Marketing tab.
final marketingTabIndexProvider = StateProvider<int>((ref) => 0);
