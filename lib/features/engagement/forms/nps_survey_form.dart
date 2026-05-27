// lib/features/requests/forms/nps_survey_form.dart

import 'package:flutter/material.dart';
import 'package:kleenops_admin/features/engagement/forms/survey_form_scaffold.dart';

class NpsSurveyFormScreen extends StatelessWidget {
  const NpsSurveyFormScreen({
    super.key,
    required this.title,
    required this.formFields,
    this.formKey,
    this.onSave,
    this.onCancel,
    this.header,
    this.padding = const EdgeInsets.all(16),
  });

  final String title;
  final Widget formFields;
  final GlobalKey<FormState>? formKey;
  final VoidCallback? onSave;
  final VoidCallback? onCancel;
  final Widget? header;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final content = header == null
        ? formFields
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header!,
              const SizedBox(height: 12),
              formFields,
            ],
          );

    return SurveyFormScaffold(
      title: title,
      formKey: formKey,
      onSave: onSave,
      onCancel: onCancel,
      padding: padding,
      child: content,
    );
  }
}
