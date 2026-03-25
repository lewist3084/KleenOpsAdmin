// lib/app/router.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/admin_auth_screen.dart';
import '../features/dashboard/screens/dashboard_home.dart';
import '../features/companies/screens/companies_home.dart';
import '../features/companies/screens/company_details.dart';
import '../features/billing/screens/billing_home.dart';
import '../features/ai_usage/screens/ai_usage_home.dart';
import '../features/storage_usage/screens/storage_home.dart';
import '../features/users/screens/users_home.dart';
import '../features/onboarding_review/screens/onboarding_home.dart';
import '../features/support/screens/support_home.dart';
import '../features/catalog/screens/catalog_home.dart';
import '../features/catalog/screens/scrape_jobs_wrapper.dart';
import '../features/catalog/screens/staging_review_wrapper.dart';
import 'routes.dart';

final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateChangesProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutePaths.dashboard,
    redirect: (context, state) {
      final isLoggedIn = authState.maybeWhen(
        data: (user) => user != null,
        orElse: () => false,
      );
      final isLoginRoute = state.matchedLocation == AppRoutePaths.login;

      if (!isLoggedIn && !isLoginRoute) return AppRoutePaths.login;
      if (isLoggedIn && isLoginRoute) return AppRoutePaths.dashboard;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutePaths.login,
        name: AppRouteIds.login,
        builder: (context, state) => const AdminAuthScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.dashboard,
        name: AppRouteIds.dashboard,
        builder: (context, state) => const DashboardHome(),
      ),
      GoRoute(
        path: AppRoutePaths.companies,
        name: AppRouteIds.companiesHome,
        builder: (context, state) => const CompaniesHome(),
      ),
      GoRoute(
        path: AppRoutePaths.companiesDetails,
        name: AppRouteIds.companiesDetails,
        builder: (context, state) {
          final companyId = state.uri.queryParameters['id'] ?? '';
          return CompanyDetails(companyId: companyId);
        },
      ),
      GoRoute(
        path: AppRoutePaths.billing,
        name: AppRouteIds.billingHome,
        builder: (context, state) => const BillingHome(),
      ),
      GoRoute(
        path: AppRoutePaths.aiUsage,
        name: AppRouteIds.aiUsageHome,
        builder: (context, state) => const AiUsageHome(),
      ),
      GoRoute(
        path: AppRoutePaths.storage,
        name: AppRouteIds.storageHome,
        builder: (context, state) => const StorageHome(),
      ),
      GoRoute(
        path: AppRoutePaths.users,
        name: AppRouteIds.usersHome,
        builder: (context, state) => const UsersHome(),
      ),
      GoRoute(
        path: AppRoutePaths.onboarding,
        name: AppRouteIds.onboardingHome,
        builder: (context, state) => const OnboardingHome(),
      ),
      GoRoute(
        path: AppRoutePaths.support,
        name: AppRouteIds.supportHome,
        builder: (context, state) => const SupportHome(),
      ),
      GoRoute(
        path: AppRoutePaths.catalog,
        name: AppRouteIds.catalogHome,
        builder: (context, state) => const CatalogHome(),
      ),
      GoRoute(
        path: AppRoutePaths.catalogScrapeJobs,
        name: AppRouteIds.catalogScrapeJobs,
        builder: (context, state) => const ScrapeJobsWrapper(),
      ),
      GoRoute(
        path: AppRoutePaths.catalogStagingReview,
        name: AppRouteIds.catalogStagingReview,
        builder: (context, state) => const StagingReviewWrapper(),
      ),
    ],
  );
});
