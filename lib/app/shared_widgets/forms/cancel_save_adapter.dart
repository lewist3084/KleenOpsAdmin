// Kleenops Admin adapter for the shared CancelSave widget.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_widgets/buttons/cancel_save.dart' as shared;

class CancelSaveBar extends StatelessWidget {
  final VoidCallback? onCancel;
  final Future<void> Function()? onSave;
  final bool isSaving;
  final String? cancelLabel;
  final String? saveLabel;
  final double extraBottomPadding;
  final bool showTopBorder;
  final bool clipTopShadow;
  final Color? topBorderColor;
  final bool showBorder;

  const CancelSaveBar({
    super.key,
    this.onCancel,
    this.onSave,
    this.isSaving = false,
    this.cancelLabel,
    this.saveLabel,
    this.extraBottomPadding = 0.0,
    this.showTopBorder = false,
    this.clipTopShadow = false,
    this.topBorderColor,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottomInset = media.viewInsets.bottom;
    final navPadding =
        bottomInset > 0 ? 0.0 : media.viewPadding.bottom;
    final effectiveCancelLabel = cancelLabel ?? 'Cancel';
    final effectiveSaveLabel = saveLabel ?? 'Save';

    final bar = shared.CancelSave(
      onCancel: () {
        if (isSaving) return;
        onCancel?.call();
      },
      onSave: () {
        if (isSaving || onSave == null) return;
        unawaited(onSave!());
      },
      cancelLabel: effectiveCancelLabel,
      saveLabel: effectiveSaveLabel,
      showBorder: showBorder,
    );

    final overlays = <Widget>[];

    if (isSaving) {
      overlays.add(const Positioned.fill(child: AbsorbPointer(child: SizedBox())));
      overlays.add(
        const Positioned.fill(
          child: IgnorePointer(
            ignoring: true,
            child: Center(
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        ),
      );
    } else {
      if (onSave == null) {
        overlays.add(
          const Positioned.fill(
            child: Row(
              children: [
                Expanded(child: IgnorePointer(ignoring: true, child: SizedBox())),
                Expanded(child: AbsorbPointer(child: SizedBox())),
              ],
            ),
          ),
        );
      }
      if (onCancel == null) {
        overlays.add(
          const Positioned.fill(
            child: Row(
              children: [
                Expanded(child: AbsorbPointer(child: SizedBox())),
                Expanded(child: IgnorePointer(ignoring: true, child: SizedBox())),
              ],
            ),
          ),
        );
      }
    }

    Widget content = Stack(
      children: [
        Opacity(
          opacity: isSaving ? 0.75 : 1.0,
          child: bar,
        ),
        ...overlays,
      ],
    );

    if (clipTopShadow) {
      content = ClipRect(child: content);
    }

    if (showTopBorder) {
      content = DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(
              color: topBorderColor ?? Colors.grey.shade300,
              width: 1,
            ),
          ),
        ),
        child: content,
      );
    }

    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        minimum: EdgeInsets.only(bottom: extraBottomPadding + navPadding),
        child: content,
      ),
    );
  }
}

typedef FormSaveBar = CancelSaveBar;
