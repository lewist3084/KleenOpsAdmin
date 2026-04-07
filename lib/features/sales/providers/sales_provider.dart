// lib/features/sales/providers/sales_provider.dart
import 'package:riverpod/legacy.dart';

/// Holds the index for the active Sales tab.
final salesTabIndexProvider = StateProvider<int>((ref) => 0);

/// Holds the index for the active Customer tab.
final customerTabIndexProvider = StateProvider<int>((ref) => 0);
