// lib/features/training/providers/training_filter_notifier.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

class TrainingFilterNotifier extends ChangeNotifier {
  bool showArchived = false;

  void toggleArchived(bool value) {
    showArchived = value;
    notifyListeners();
  }
}

// The Riverpod provider that you actually import & use elsewhere
final trainingFilterNotifierProvider =
    ChangeNotifierProvider<TrainingFilterNotifier>((ref) {
  return TrainingFilterNotifier();
});
