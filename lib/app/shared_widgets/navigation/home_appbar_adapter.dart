// Kleenops Admin adapter for the shared ContentAppBar.
// Simplified version without kleenops-specific communication/action helpers.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kleenops_admin/common/resources/resources_menu.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:shared_widgets/navigation/details_appbar.dart';

bool _isLandscape() {
  final views = WidgetsBinding.instance.platformDispatcher.views;
  if (views.isEmpty) return false;
  final size = views.first.physicalSize;
  return size.width > size.height;
}

class ContentAppBar extends ConsumerWidget implements PreferredSizeWidget {
  static const double _height = 44.0;

  final void Function(BuildContext context)? actionIconAction;
  final void Function(BuildContext context)? resourceIconAction;
  final bool showBackButton;
  final String? titleOverride;
  final WidgetBuilder? menuDrawerBuilder;
  final MenuDrawerSections? menuSections;
  final MenuSectionsBuilder? menuSectionsBuilder;
  final List<ContentMenuItem>? actionItems;
  final List<ContentMenuItem>? resourceItems;
  final List<ContentMenuItem>? communicationItems;
  final VoidCallback? onMenuPressed;

  const ContentAppBar({
    super.key,
    this.actionIconAction,
    this.resourceIconAction,
    this.showBackButton = false,
    this.titleOverride,
    this.menuDrawerBuilder,
    this.menuSections,
    this.menuSectionsBuilder,
    this.actionItems,
    this.resourceItems,
    this.communicationItems,
    this.onMenuPressed,
  });

  @override
  Size get preferredSize =>
      _isLandscape() ? Size.zero : const Size.fromHeight(_height);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (_isLandscape()) return const SizedBox.shrink();

    final scaffoldContext = Scaffold.maybeOf(context)?.context ?? context;

    // Auto-inject the canonical Resources list (Files) when a screen didn't
    // supply one, so the Files browser appears in every drawer — mirrors the
    // main app's `withFilesInSections` behaviour.
    MenuDrawerSections withResources(MenuDrawerSections s) {
      if (s.resources.isNotEmpty) return s;
      return MenuDrawerSections(
        actions: s.actions,
        resources: buildAdminResourceMenuItems(scaffoldContext),
        communications: s.communications,
      );
    }

    MenuDrawerSections buildSections() {
      if (menuSectionsBuilder != null) {
        return withResources(menuSectionsBuilder!(scaffoldContext));
      } else if (menuSections != null) {
        return withResources(menuSections!);
      } else if (actionItems != null ||
          resourceItems != null ||
          communicationItems != null) {
        return withResources(MenuDrawerSections(
          actions: actionItems ?? const <ContentMenuItem>[],
          resources: resourceItems ?? const <ContentMenuItem>[],
          communications: communicationItems ?? const <ContentMenuItem>[],
        ));
      }
      return withResources(const MenuDrawerSections());
    }

    Widget buildDrawer() {
      if (menuDrawerBuilder != null) return menuDrawerBuilder!(scaffoldContext);
      return MenuDrawer(sections: buildSections());
    }

    return StandardAppBar(
      title: '',
      showNavigationArrows: false,
      menuDrawerBuilder: (_) => buildDrawer(),
      menuSectionsBuilder: (_) => buildSections(),
      onMenuPressed:
          onMenuPressed ?? () => _openMenuDrawer(scaffoldContext, buildDrawer()),
    );
  }

  void _openMenuDrawer(BuildContext context, Widget drawer) {
    final media = MediaQuery.of(context);
    final drawerWidth =
        media.size.width >= 600 ? 420.0 : media.size.width * 0.9;

    showGeneralDialog(
      context: context,
      barrierLabel: 'Menu',
      barrierDismissible: true,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, anim, sec) {
        return SafeArea(
          child: Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: drawerWidth,
              height: media.size.height,
              child: Material(
                color: Colors.transparent,
                child: drawer,
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim, sec, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(curved),
          child: child,
        );
      },
    );
  }
}
