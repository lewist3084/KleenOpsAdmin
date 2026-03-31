// lib/app/router.dart

import 'package:cloud_firestore/cloud_firestore.dart';
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
import '../features/legal/screens/legal_home.dart';
import '../features/legal/screens/legal_documents.dart';
import '../features/legal/screens/legal_compliance.dart';
import '../features/legal/screens/legal_contracts.dart';
import '../features/legal/screens/legal_stats.dart';
import '../features/support/screens/support_home.dart';
import '../features/catalog/screens/catalog_home.dart';
import '../features/catalog/screens/scrape_jobs_wrapper.dart';
import '../features/catalog/screens/brand_owners_wrapper.dart';
import '../features/catalog/screens/staging_review_wrapper.dart';
import '../features/device_registry/screens/device_registry_home.dart';
import '../features/finances/screens/financeHome.dart';
import '../features/finances/screens/financeCustomers.dart';
import '../features/finances/screens/financeInvoices.dart';
import '../features/finances/screens/financeBills.dart';
import '../features/finances/screens/financePayments.dart';
import '../features/finances/tabs/ledgerTabs.dart';
import '../features/finances/screens/financeAccounts.dart';
import '../features/finances/screens/financeStats.dart';
import '../features/finances/screens/financeBanking.dart';
import '../features/finances/screens/financeSetupWizard.dart';
import '../features/finances/screens/financePayroll.dart';
import '../features/finances/details/financePayrollRunDetails.dart';
import '../features/finances/details/financePayStubDetails.dart';
import '../features/finances/forms/financePayrollRunForm.dart';
import '../features/finances/screens/financeW2Generation.dart';
import '../features/hr/details/hrEmployeeDetails.dart';
import '../features/hr/details/hrOnboardingDetails.dart';
import '../features/hr/details/hrBenefitPlanDetails.dart';
import '../features/hr/forms/hr_team_form.dart';
import '../features/hr/forms/hr_benefit_plan_form.dart';
import '../features/hr/forms/hr_benefit_enrollment_form.dart';
import '../features/hr/screens/hrHome.dart';
import '../features/hr/screens/hrTeam.dart';
import '../features/hr/screens/hrRoles.dart';
import '../features/hr/screens/hrTimeOff.dart';
import '../features/hr/screens/hrDocuments.dart';
import '../features/hr/tabs/hrEmployeeTabs.dart';
import '../features/hr/screens/hrStats.dart';
import '../features/hr/screens/hrOnboarding.dart';
import '../features/hr/screens/hrBenefits.dart';
import '../features/hr/screens/hrTimeEntry.dart';
import '../features/hr/screens/hrNewHireChecklist.dart';
import '../features/admin/screens/adminHome.dart';
import '../features/admin/tabs/adminCompanyTabs.dart';
import '../features/admin/screens/adminPolicies.dart';
import '../features/admin/screens/adminCompliance.dart';
import '../features/admin/screens/adminTaxMonitor.dart';
import '../features/admin/forms/adminStateRuleForm.dart';
import '../features/admin/forms/adminFederalRuleForm.dart';
import '../features/admin/screens/adminSetupWizard.dart';
import '../features/sales/screens/salesHome.dart';
import '../features/sales/screens/customer_portal_requests.dart';
import '../features/sales/screens/customer_invite_screen.dart';
import '../features/sales/tabs/salesTabs.dart';
import '../features/sales/tabs/marketingTabs.dart';
import '../features/sales/screens/salesStats.dart';
import '../features/sales/details/marketingAdsDetails.dart';
import '../features/purchasing/screens/purchasingHome.dart';
import '../features/purchasing/screens/purchasingRequests.dart';
import '../features/purchasing/tabs/objectsTabs.dart';
import '../features/purchasing/screens/purchasingVendors.dart';
import '../features/purchasing/screens/purchasingStats.dart';
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
      // Legal sub-routes
      GoRoute(
        path: AppRoutePaths.legalHome,
        name: AppRouteIds.legalHome,
        builder: (context, state) => const LegalHome(),
      ),
      GoRoute(
        path: AppRoutePaths.legalDocuments,
        name: AppRouteIds.legalDocuments,
        builder: (context, state) => const LegalDocumentsScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.legalCompliance,
        name: AppRouteIds.legalCompliance,
        builder: (context, state) => const LegalComplianceScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.legalContracts,
        name: AppRouteIds.legalContracts,
        builder: (context, state) => const LegalContractsScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.legalStats,
        name: AppRouteIds.legalStats,
        builder: (context, state) => const LegalStatsScreen(),
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
      GoRoute(
        path: AppRoutePaths.catalogBrandOwners,
        name: AppRouteIds.catalogBrandOwners,
        builder: (context, state) => const BrandOwnersWrapper(),
      ),
      GoRoute(
        path: AppRoutePaths.deviceRegistry,
        name: AppRouteIds.deviceRegistryHome,
        builder: (context, state) => const DeviceRegistryHome(),
      ),
      // Finance routes
      GoRoute(
        path: AppRoutePaths.financeHome,
        name: AppRouteIds.financeHome,
        builder: (_, __) => const FinancesHomeScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.financeLedger,
        name: AppRouteIds.financeLedger,
        builder: (_, __) => const FinanceLedgerTabsScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.financeCustomers,
        name: AppRouteIds.financeCustomers,
        builder: (_, __) => const FinanceCustomersScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.financeInvoices,
        name: AppRouteIds.financeInvoices,
        builder: (_, __) => const FinanceInvoicesScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.financeBills,
        name: AppRouteIds.financeBills,
        builder: (_, __) => const FinanceBillsScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.financePayments,
        name: AppRouteIds.financePayments,
        builder: (_, __) => const FinancePaymentsScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.financeAccounts,
        name: AppRouteIds.financeAccounts,
        builder: (_, __) => const FinanceAccountsScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.financeStats,
        name: AppRouteIds.financeStats,
        builder: (_, __) => const FinancesStatsScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.financeBanking,
        name: AppRouteIds.financeBanking,
        builder: (_, __) => const FinanceBankingScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.financeSetupWizard,
        name: AppRouteIds.financeSetupWizard,
        builder: (_, __) => const FinanceSetupWizardScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.financePayroll,
        name: AppRouteIds.financePayroll,
        builder: (_, __) => const FinancePayrollScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.financePayrollRunDetails,
        name: AppRouteIds.financePayrollRunDetails,
        pageBuilder: (_, state) => _noTransitionPage(
          state,
          FinancePayrollRunDetailsScreen.fromExtra(
            state.extra as Map<String, dynamic>?,
          ),
        ),
      ),
      GoRoute(
        path: AppRoutePaths.financePayrollRunForm,
        name: AppRouteIds.financePayrollRunForm,
        pageBuilder: (_, state) => _noTransitionPage(
          state,
          CompanyWrapper(
            builder: (companyRef) => FinancePayrollRunForm(
              companyRef: companyRef,
            ),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutePaths.financePayStubDetails,
        name: AppRouteIds.financePayStubDetails,
        pageBuilder: (_, state) => _noTransitionPage(
          state,
          FinancePayStubDetailsScreen.fromExtra(
            state.extra as Map<String, dynamic>?,
          ),
        ),
      ),
      GoRoute(
        path: AppRoutePaths.financeW2Generation,
        name: AppRouteIds.financeW2Generation,
        builder: (_, __) => const FinanceW2GenerationScreen(),
      ),
      // HR routes
      GoRoute(
        path: AppRoutePaths.hrHome,
        name: AppRouteIds.hrHome,
        builder: (_, __) => const HrHomeScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.hrEmployees,
        name: AppRouteIds.hrEmployees,
        builder: (_, __) => const HrEmployeeTabsScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.hrRoles,
        name: AppRouteIds.hrRoles,
        builder: (_, __) => const HrRolesScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.hrTeam,
        name: AppRouteIds.hrTeam,
        builder: (_, __) => const HrTeamScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.hrTeamForm,
        name: AppRouteIds.hrTeamForm,
        builder: (_, state) {
          final args = state.extra as HrTeamFormArgs?;
          if (args == null) {
            return CompanyWrapper(
              builder: (companyRef) => HrTeamForm(companyRef: companyRef),
            );
          }
          return HrTeamForm(
            companyRef: args.companyRef,
            teamRef: args.teamRef,
          );
        },
      ),
      GoRoute(
        path: AppRoutePaths.hrStats,
        name: AppRouteIds.hrStats,
        builder: (_, __) => const HrStatsScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.hrOnboarding,
        name: AppRouteIds.hrOnboarding,
        builder: (_, __) => const HrOnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.hrBenefits,
        name: AppRouteIds.hrBenefits,
        builder: (_, __) => const HrBenefitsScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.hrTimeEntry,
        name: AppRouteIds.hrTimeEntry,
        builder: (_, __) => const HrTimeEntryScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.hrNewHireChecklist,
        name: AppRouteIds.hrNewHireChecklist,
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return HrNewHireChecklistScreen.fromExtra(extra);
        },
      ),
      GoRoute(
        path: AppRoutePaths.hrBenefitPlanDetails,
        name: AppRouteIds.hrBenefitPlanDetails,
        pageBuilder: (_, state) => _noTransitionPage(
          state,
          HrBenefitPlanDetailsScreen.fromExtra(
            state.extra as Map<String, dynamic>?,
          ),
        ),
      ),
      GoRoute(
        path: AppRoutePaths.hrBenefitPlanForm,
        name: AppRouteIds.hrBenefitPlanForm,
        pageBuilder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final docId = extra?['docId'] as String?;
          return _noTransitionPage(
            state,
            CompanyWrapper(
              builder: (companyRef) => HrBenefitPlanForm(
                companyRef: companyRef,
                docId: docId,
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutePaths.hrBenefitEnrollmentForm,
        name: AppRouteIds.hrBenefitEnrollmentForm,
        pageBuilder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return _noTransitionPage(
            state,
            CompanyWrapper(
              builder: (companyRef) => HrBenefitEnrollmentForm(
                companyRef: companyRef,
                memberId: extra?['memberId'] as String?,
                planId: extra?['planId'] as String?,
                planName: extra?['planName'] as String?,
                enrollmentId: extra?['enrollmentId'] as String?,
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutePaths.hrOnboardingDetails,
        name: AppRouteIds.hrOnboardingDetails,
        pageBuilder: (_, state) => _noTransitionPage(
          state,
          HrOnboardingDetailsScreen.fromExtra(
            state.extra as Map<String, dynamic>?,
          ),
        ),
      ),
      GoRoute(
        path: AppRoutePaths.hrTimeOff,
        name: AppRouteIds.hrTimeOff,
        builder: (_, __) => const HrTimeOffScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.hrDocuments,
        name: AppRouteIds.hrDocuments,
        builder: (_, __) => const HrDocumentsScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.hrEmployeesDetails,
        name: AppRouteIds.hrEmployeesDetails,
        pageBuilder: (_, state) => _noTransitionPage(
          state,
          HrEmployeesDetailsScreen.fromExtra(
            state.extra as Map<String, dynamic>?,
          ),
        ),
      ),
      // Administration routes
      GoRoute(
        path: AppRoutePaths.adminHome,
        name: AppRouteIds.adminHome,
        builder: (_, __) => const AdminHomeScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.adminCompany,
        name: AppRouteIds.adminCompany,
        builder: (_, __) => const AdminCompanyTabsScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.adminPolicies,
        name: AppRouteIds.adminPolicies,
        builder: (_, __) => const AdminPoliciesScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.adminCompliance,
        name: AppRouteIds.adminCompliance,
        builder: (_, __) => const AdminComplianceScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.adminTaxMonitor,
        name: AppRouteIds.adminTaxMonitor,
        builder: (_, __) => const AdminTaxMonitorScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.adminStateRuleForm,
        name: AppRouteIds.adminStateRuleForm,
        pageBuilder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final stateCode = extra?['stateCode'] as String?;
          return _noTransitionPage(
            state,
            CompanyWrapper(
              builder: (companyRef) => AdminStateRuleForm(
                companyRef: companyRef,
                stateCode: stateCode,
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutePaths.adminFederalRuleForm,
        name: AppRouteIds.adminFederalRuleForm,
        pageBuilder: (_, state) => _noTransitionPage(
          state,
          CompanyWrapper(
            builder: (companyRef) =>
                AdminFederalRuleForm(companyRef: companyRef),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutePaths.adminSetupWizard,
        name: AppRouteIds.adminSetupWizard,
        builder: (_, __) => const AdminSetupWizardScreen(),
      ),
      // Sales routes
      GoRoute(
        path: AppRoutePaths.salesHome,
        name: AppRouteIds.salesHome,
        builder: (_, __) => const SalesHomeScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.salesSales,
        name: AppRouteIds.salesSales,
        builder: (_, __) => const SalesTabsScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.salesMarketing,
        name: AppRouteIds.salesMarketing,
        builder: (_, __) => const SalesMarketingTabsScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.salesMarketingAdsDetails,
        name: AppRouteIds.salesMarketingAdsDetails,
        builder: (_, state) {
          final cid = state.uri.queryParameters['cid'] ?? '';
          final docId = state.uri.queryParameters['docId'] ?? '';
          final docRef = FirebaseFirestore.instance
              .collection('company')
              .doc(cid)
              .collection('marketingAd')
              .doc(docId);
          return MarketingAdsDetailsScreen(docRef: docRef);
        },
      ),
      GoRoute(
        path: AppRoutePaths.salesStats,
        name: AppRouteIds.salesStats,
        builder: (_, __) => const SalesStatsScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.salesCustomerPortalRequests,
        name: AppRouteIds.salesCustomerPortalRequests,
        builder: (_, __) => const CustomerPortalRequestsScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.salesCustomerInvite,
        name: AppRouteIds.salesCustomerInvite,
        builder: (_, state) {
          final qp = state.uri.queryParameters;
          return CustomerInviteScreen(
            customerId: qp['customerId'] ?? '',
          );
        },
      ),
      // Purchasing routes
      GoRoute(
        path: AppRoutePaths.purchasingHome,
        name: AppRouteIds.purchasingHome,
        builder: (_, __) => const PurchasingHomeScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.purchasingOrders,
        name: AppRouteIds.purchasingOrders,
        builder: (_, __) => const PurchasingRequestsScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.purchasingObjects,
        name: AppRouteIds.purchasingObjects,
        builder: (_, __) => const ObjectsTabsScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.purchasingVendors,
        name: AppRouteIds.purchasingVendors,
        builder: (_, __) => const PurchasingVendorsScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.purchasingStats,
        name: AppRouteIds.purchasingStats,
        builder: (_, __) => const PurchasingStatsScreen(),
      ),
    ],
  );
});

// Detail routes keep the bottom nav; skip transitions to avoid re-animating it.
Page<void> _noTransitionPage(GoRouterState state, Widget child) {
  return NoTransitionPage<void>(key: state.pageKey, child: child);
}

/// Wrapper that resolves the current user's company and passes it to [builder].
class CompanyWrapper extends ConsumerWidget {
  const CompanyWrapper({required this.builder, super.key});
  final Widget Function(DocumentReference<Map<String, dynamic>> companyId)
      builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncRef = ref.watch(companyIdProvider);
    return asyncRef.when(
      data: (raw) {
        if (raw == null) {
          return const Scaffold(
            body: Center(child: Text('Error: No company ID')),
          );
        }
        final typed = raw.withConverter<Map<String, dynamic>>(
          fromFirestore: (s, _) => s.data()!,
          toFirestore: (m, _) => m,
        );
        return builder(typed);
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Error: $e')),
      ),
    );
  }
}
