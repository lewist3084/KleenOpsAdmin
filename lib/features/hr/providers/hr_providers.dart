// lib/services/providers.dart

import 'package:riverpod/riverpod.dart';
import 'employee_repository.dart';

/// Riverpod provider for EmployeeRepository.
final employeeRepositoryProvider = Provider<EmployeeRepository>((ref) {
  return EmployeeRepository();
});

/// Riverpod FutureProvider for fetching team names.
final teamNamesProvider = FutureProvider.family<Map<String, String>, String>((ref, companyId) async {
  final repository = ref.watch(employeeRepositoryProvider);
  return await repository.getTeamNames(companyId);
});

/// Riverpod FutureProvider for fetching role names.
final roleNamesProvider = FutureProvider.family<Map<String, String>, String>((ref, companyId) async {
  final repository = ref.watch(employeeRepositoryProvider);
  return await repository.getRoleNames(companyId);
});
