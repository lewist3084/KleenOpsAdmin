import 'package:flutter/widgets.dart';
import 'package:kleenops_admin/l10n/app_localizations.dart';

typedef LocalizedStringResolver = String Function(AppLocalizations loc);
typedef LocalizedCountStringResolver = String Function(
  AppLocalizations loc,
  int count,
);

String resolveLocalizedText(
  BuildContext context, {
  String? text,
  LocalizedStringResolver? resolver,
  String? fallback,
}) {
  final loc = AppLocalizations.of(context);
  if (resolver != null && loc != null) {
    return resolver(loc);
  }
  if (text != null) {
    return text;
  }
  if (fallback != null) {
    return fallback;
  }
  return '';
}

String resolveLocalizedCountText(
  BuildContext context, {
  required int count,
  String? text,
  LocalizedCountStringResolver? resolver,
  String? fallback,
}) {
  final loc = AppLocalizations.of(context);
  if (resolver != null && loc != null) {
    return resolver(loc, count);
  }
  if (text != null) {
    return text;
  }
  if (fallback != null) {
    return fallback;
  }
  return '';
}
