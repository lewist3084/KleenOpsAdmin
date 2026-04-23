// Kleenops Admin adapter around the shared DetailsAppBar.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:shared_widgets/navigation/details_appbar.dart' as shared;

class DetailsAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onAiPressed;
  final VoidCallback? onForwardPressed;
  final bool showUserMenu;
  final bool showNavigationArrows;
  final IconData? rightIcon1;
  final VoidCallback? rightAction1;
  final IconData? rightIcon2;
  final VoidCallback? rightAction2;
  final MenuDrawerSections? menuSections;
  final List<ContentMenuItem>? actionItems;
  final List<ContentMenuItem>? resourceItems;
  final List<ContentMenuItem>? communicationItems;
  final VoidCallback? onMenuPressed;
  final bool showMenu;
  final VoidCallback? onSearchToggle;
  final bool searchActive;

  const DetailsAppBar({
    super.key,
    this.title = '',
    this.onAiPressed,
    this.onForwardPressed,
    this.showUserMenu = true,
    this.showNavigationArrows = true,
    this.rightIcon1,
    this.rightAction1,
    this.rightIcon2,
    this.rightAction2,
    this.menuSections,
    this.actionItems,
    this.resourceItems,
    this.communicationItems,
    this.onMenuPressed,
    this.showMenu = false,
    this.onSearchToggle,
    this.searchActive = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(44);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasMenuItems = menuSections != null ||
        (actionItems?.isNotEmpty ?? false) ||
        (resourceItems?.isNotEmpty ?? false) ||
        (communicationItems?.isNotEmpty ?? false);
    final effectiveShowMenu = showMenu || hasMenuItems;

    return shared.StandardAppBar(
      title: title,
      onAiPressed: onAiPressed,
      onForwardPressed: onForwardPressed,
      showUserMenu: showUserMenu,
      showNavigationArrows: showNavigationArrows,
      rightIcon1: rightIcon1,
      rightAction1: rightAction1,
      rightIcon2: rightIcon2,
      rightAction2: rightAction2,
      menuSections: menuSections,
      actionItems: actionItems,
      resourceItems: resourceItems,
      communicationItems: communicationItems,
      onMenuPressed: onMenuPressed,
      showMenu: effectiveShowMenu,
      onSearchToggle: onSearchToggle,
      searchActive: searchActive,
    );
  }
}

typedef StandardAppBar = DetailsAppBar;
