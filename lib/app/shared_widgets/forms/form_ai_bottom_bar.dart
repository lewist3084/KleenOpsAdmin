import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kleenops_admin/app/shared_widgets/forms/cancel_save_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/services/ai/ai_context_service.dart';

class FormAiBottomBar extends ConsumerWidget {
  const FormAiBottomBar({
    super.key,
    required this.onCancel,
    required this.onSave,
    this.isSaving = false,
    this.title = '',
    this.showMenu = false,
    this.showUserMenu = true,
    this.showNavigationArrows = true,
    this.extraBottomPadding = 0,
    this.showTopBorder = true,
    this.clipTopShadow = true,
    this.topBorderColor,
    this.onAiPressed,
  });

  final VoidCallback? onCancel;
  final Future<void> Function()? onSave;
  final bool isSaving;
  final String title;
  final bool showMenu;
  final bool showUserMenu;
  final bool showNavigationArrows;
  final double extraBottomPadding;
  final bool showTopBorder;
  final bool clipTopShadow;
  final Color? topBorderColor;
  final VoidCallback? onAiPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(aiCanvasControllerProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CancelSaveBar(
          onCancel: onCancel,
          onSave: onSave,
          isSaving: isSaving,
          extraBottomPadding: extraBottomPadding,
          showTopBorder: showTopBorder,
          clipTopShadow: clipTopShadow,
          topBorderColor: topBorderColor,
          // Stacked above DetailsAppBar — the OS nav-bar inset is reserved
          // once below, by HomeNavBarAdapter (the lowest bar). Without this the
          // bar would reserve the inset here, leaving a gap above DetailsAppBar.
          reserveNavBarSpace: false,
        ),
        DetailsAppBar(
          title: title,
          onAiPressed: onAiPressed ?? controller.toggle,
          showMenu: showMenu,
          showUserMenu: showUserMenu,
          showNavigationArrows: showNavigationArrows,
        ),
        // Lowest bar — reserves the OS navigation-bar inset itself.
        const HomeNavBarAdapter(),
      ],
    );
  }
}
