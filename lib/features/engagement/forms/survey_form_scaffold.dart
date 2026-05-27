// lib/features/requests/forms/survey_form_scaffold.dart

import 'package:flutter/material.dart';
import 'package:shared_widgets/buttons/cancel_save.dart';
import 'package:kleenops_admin/widgets/layout/bookended_canvas.dart';

class SurveyFormScaffold extends StatelessWidget {
  const SurveyFormScaffold({
    super.key,
    required this.title,
    required this.child,
    this.formKey,
    this.onSave,
    this.onCancel,
    this.padding = const EdgeInsets.all(16),
    this.showMenu = false,
  });

  final String title;
  final Widget child;
  final GlobalKey<FormState>? formKey;
  final VoidCallback? onSave;
  final VoidCallback? onCancel;
  final EdgeInsetsGeometry padding;
  final bool showMenu;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: null,
      body: BookendedCanvas(
        child: Column(
          children: [
            Expanded(
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  padding: padding,
                  child: child,
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: CancelSave(
                onCancel: onCancel ?? () => Navigator.of(context).maybePop(),
                onSave: onSave ?? () {},
              ),
            ),
          ],
        ),
      ),
    );
  }
}
