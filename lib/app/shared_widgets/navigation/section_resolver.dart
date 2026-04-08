import 'package:kleenops_admin/app/routes.dart';

String resolveAppSection(String path) {
  if (path.startsWith('/tasks')) return 'tasks';
  if (path.startsWith('/facilities')) return 'facilities';
  if (path.startsWith('/marketplace')) return 'marketplace';
  if (path.startsWith('/processes')) return 'processes';
  if (path.startsWith('/scheduling')) return 'scheduling';
  if (path.startsWith('/supervision')) return 'supervision';
  if (path.startsWith('/training')) return 'training';
  if (path.startsWith('/quality')) return 'quality';
  if (path.startsWith('/safety')) return 'safety';
  if (path.startsWith('/occupancy')) return 'occupancy';
  if (path.startsWith('/engagement')) return 'engagement';
  if (path.startsWith('/legal')) return 'legal';
  if (path.startsWith('/companies')) return 'companies';
  if (path.startsWith('/billing')) return 'billing';
  if (path.startsWith('/finance')) return 'finance';
  if (path.startsWith('/hr')) return 'hr';
  if (path.startsWith('/admin')) return 'admin';
  if (path.startsWith('/sales')) return 'sales';
  if (path.startsWith('/purchasing')) return 'purchasing';
  if (path.startsWith('/inventory')) return 'inventory';
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
