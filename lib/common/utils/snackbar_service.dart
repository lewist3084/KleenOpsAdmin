// lib/common/utils/snackbar_service.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kleenops_admin/app/my_app.dart' show scaffoldMessengerKey;

/// App-wide entry point for showing SnackBars.
///
/// Every snackbar in the app goes through this service. On top of Flutter's
/// own behaviour it guarantees:
///  * the queue is cleared first, so messages never stack up and look "stuck";
///  * a watchdog timer force-clears the snackbar even if Flutter's own
///    auto-dismiss timer never starts (a known cause of "frozen" snackbars
///    when the entrance animation is interrupted by a rebuild/navigation).
///
/// Prefer [showSnackBar] when you have a configured [SnackBar], or [show] for
/// a quick text message.
class SnackbarService {
  const SnackbarService._();
  static const SnackbarService instance = SnackbarService._();

  /// The standard, app-wide snackbar display duration.
  static const Duration defaultDuration = Duration(seconds: 5);

  /// Entrance animation (~250ms) plus a small margin.
  static const Duration _watchdogGrace = Duration(milliseconds: 750);

  static Timer? _watchdog;

  /// Shows a fully-configured [bar] through the app's global messenger.
  ///
  /// Returns the controller (e.g. for awaiting `.closed`), or `null` if no
  /// messenger is currently mounted.
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showSnackBar(
    SnackBar bar,
  ) {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return null;

    messenger.clearSnackBars();
    final controller = messenger.showSnackBar(bar);

    _watchdog?.cancel();
    _watchdog = Timer(bar.duration + _watchdogGrace, () {
      scaffoldMessengerKey.currentState?.clearSnackBars();
    });

    return controller;
  }

  /// Convenience for a simple text snackbar.
  void show(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    Color? backgroundColor,
    Duration duration = defaultDuration,
  }) {
    showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        backgroundColor: backgroundColor,
        action: (actionLabel != null && onAction != null)
            ? SnackBarAction(label: actionLabel, onPressed: onAction)
            : null,
      ),
    );
  }
}
