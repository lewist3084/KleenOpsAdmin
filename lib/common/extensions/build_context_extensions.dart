// lib/common/extensions/build_context_extensions.dart
import 'package:flutter/material.dart';

extension ShellDialogs on BuildContext {
  /// Shows a dialog that is *scoped* to the navigator of the current
  /// ShellRoute (the one you created with `_contentKey` in router.dart).
  Future<T?> showShellDialog<T>({
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: this,
      useRootNavigator: false,      // ← keeps it inside the content shell
      barrierDismissible: barrierDismissible,
      builder: builder,
    );
  }
}
