import 'package:kleenops_admin/app/routes.dart';

String resolveAppSection(String path) {
  if (path.startsWith('/legal')) return 'legal';
  if (path.startsWith('/companies')) return 'companies';
  if (path.startsWith('/billing')) return 'billing';
  if (path.startsWith('/ai-usage')) return 'aiUsage';
  if (path.startsWith('/storage')) return 'storage';
  if (path.startsWith('/users')) return 'users';
  if (path.startsWith('/onboarding')) return 'onboarding';
  if (path.startsWith('/support')) return 'support';
  if (path.startsWith('/catalog')) return 'catalog';
  if (path.startsWith('/device-registry')) return 'deviceRegistry';
  if (path == AppRoutePaths.dashboard || path == '/') return 'dashboard';

  final segments = Uri.parse(path).pathSegments;
  if (segments.isEmpty) return 'dashboard';
  return segments.first;
}
