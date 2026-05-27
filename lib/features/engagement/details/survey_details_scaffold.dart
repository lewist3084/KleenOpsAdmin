// lib/features/requests/details/survey_details_scaffold.dart

import 'package:flutter/material.dart';

class SurveyDetailsScaffold extends StatelessWidget {
  const SurveyDetailsScaffold({
    super.key,
    required this.title,
    required this.child,
    this.onEdit,
    this.padding = const EdgeInsets.all(16),
    this.showMenu = false,
  });

  final String title;
  final Widget child;
  final VoidCallback? onEdit;
  final EdgeInsetsGeometry padding;
  final bool showMenu;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: showMenu
            ? [
                Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu),
                    tooltip: 'Menu',
                    onPressed: () => Scaffold.maybeOf(context)?.openEndDrawer(),
                  ),
                ),
              ]
            : null,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: padding,
          child: child,
        ),
      ),
      floatingActionButton: onEdit == null
          ? null
          : FloatingActionButton(
              onPressed: onEdit,
              child: const Icon(Icons.edit_outlined),
            ),
    );
  }
}
