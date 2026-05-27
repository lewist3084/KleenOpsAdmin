// features/inventory/providers/inventory_provider.dart
import 'package:riverpod/legacy.dart';

/// Holds the index for the active Inventory Fulfillment tab.
/// 0 = Requests, 1 = Fulfillment, 2 = Restocking.
final inventoryTabIndexProvider = StateProvider<int>((ref) => 0);
