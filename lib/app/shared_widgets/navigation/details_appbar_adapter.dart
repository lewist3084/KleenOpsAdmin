// Kleenops Admin adapter around the shared DetailsAppBar.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kleenops_admin/common/menu_sections.dart';
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
  final bool showSearchToggle;
  final VoidCallback? onFilterToggle;
  final bool filterActive;
  final bool showFilterToggle;
  final String? filterTooltipActive;
  final String? filterTooltipInactive;

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
    this.showSearchToggle = true,
    this.onFilterToggle,
    this.filterActive = false,
    this.showFilterToggle = false,
    this.filterTooltipActive,
    this.filterTooltipInactive,
  });

  @override
  Size get preferredSize => const Size.fromHeight(44);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fold the caller's sections together and inject the universal drawer set
    // (My Tasks, Agent Tasks, Files, the 7 Communications, Reminders) so the
    // same fixed items appear on every screen. The universal items always
    // exist, so the menu always shows.
    final base = menuSections ??
        MenuDrawerSections(
          actions: actionItems ?? const <ContentMenuItem>[],
          resources: resourceItems ?? const <ContentMenuItem>[],
          communications: communicationItems ?? const <ContentMenuItem>[],
        );
    final MenuDrawerSections effectiveSections =
        withAdminUniversalSections(context, base);
    const effectiveShowMenu = true;

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
      menuSections: effectiveSections,
      onMenuPressed: onMenuPressed,
      showMenu: effectiveShowMenu,
      onSearchToggle: onSearchToggle,
      searchActive: searchActive,
      showSearchToggle: showSearchToggle,
      onFilterToggle: onFilterToggle,
      filterActive: filterActive,
      showFilterToggle: showFilterToggle,
      filterTooltipActive: filterTooltipActive,
      filterTooltipInactive: filterTooltipInactive,
    );
  }
}

typedef StandardAppBar = DetailsAppBar;
