// lib/app/router.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'shared_widgets/navigation/details_appbar_adapter.dart';
import 'shared_widgets/navigation/home_navbar_adapter.dart';

import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/admin_auth_screen.dart';
import '../features/dashboard/screens/dashboard_home.dart';
import '../features/companies/screens/companies_home.dart';
import '../features/companies/screens/company_details.dart';
import '../features/billing/screens/billing_home.dart';
import '../features/billing/screens/corp_tools_invoices_screen.dart';
import '../features/ai_usage/screens/ai_usage_home.dart';
import '../features/storage_usage/screens/storage_home.dart';
import '../features/users/screens/users_home.dart';
import '../features/onboarding_review/screens/onboarding_home.dart';
import '../features/me/tabs/me_info_tabs.dart';
import '../features/onboarding/screens/setup_dashboard_screen.dart';
import '../services/analytics_navigator_observer.dart';
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
import '../common/communications/phone/screens/call_history_screen.dart';
import '../common/communications/texting/screens/text_conversations_screen.dart';
import '../common/communications/messageboard/screens/message_board_screen.dart';
import '../common/communications/calendar/communications_calendar_screen.dart';
import '../common/communications/calendar/calendar_event_form_screen.dart';
import '../features/me/screens/my_tasks_screen.dart';
import '../features/me/screens/reminders_screen.dart';
import '../features/occupancy/screens/agent_tasks_list_screen.dart';
import '../features/files/screens/drives_screen.dart';
import '../features/notes/screens/notes_home_screen.dart';
import '../features/notes/screens/notes_folder_screen.dart';
import '../features/notes/screens/notes_content_detail_screen.dart';
import '../features/notes/screens/meeting_minutes_screen.dart';
import '../common/communications/screens/comm_placeholder_screen.dart';
import '../common/communications/email/screens/email_inbox_screen.dart';
import '../common/communications/screens/directory_screen.dart';
import '../common/communications/screens/intercom_screen.dart';
import '../features/onboarding/guides/setup_guide_data.dart';
import '../features/onboarding/guides/setup_guide_gate.dart';
import '../features/finances/screens/finance_home.dart';
import '../features/finances/screens/finance_customers.dart';
import '../features/finances/screens/finance_invoices.dart';
import '../features/finances/screens/finance_bills.dart';
import '../features/finances/screens/finance_payments.dart';
import '../features/finances/tabs/ledger_tabs.dart';
import '../features/finances/screens/finance_accounts.dart';
import '../features/finances/screens/finance_stats.dart';
import '../features/finances/screens/finance_banking.dart';
import '../features/finances/screens/finance_reconciliation.dart';
import '../features/finances/screens/finance_classify_transactions.dart';
import '../features/finances/screens/finance_ai_bookkeeper.dart';
import '../features/finances/screens/plaid_oauth_screen.dart';
import '../features/finances/screens/finance_setup_wizard.dart';
import '../features/finances/screens/finance_payroll.dart';
import '../features/finances/details/finance_payroll_run_details.dart';
import '../features/finances/details/finance_pay_stub_details.dart';
import '../features/finances/forms/finance_payroll_run_form.dart';
import '../features/finances/screens/finance_w2_generation.dart';
import '../features/hr/details/hr_employee_details.dart';
import '../features/hr/details/hr_onboarding_details.dart';
import '../features/hr/details/hr_benefit_plan_details.dart';
import '../features/hr/forms/hr_team_form.dart';
import '../features/hr/forms/hr_onboarding_profile_form.dart';
import '../features/hr/forms/hr_benefit_plan_form.dart';
import '../features/hr/forms/hr_benefit_enrollment_form.dart';
import '../features/hr/screens/hr_home.dart';
import '../features/hr/screens/hr_team.dart';
import '../features/hr/screens/hr_roles.dart';
import '../features/hr/screens/hr_time_off.dart';
import '../features/hr/screens/hr_documents.dart';
import '../features/hr/tabs/hr_employee_tabs.dart';
import '../features/hr/screens/hr_stats.dart';
import '../features/hr/screens/hr_onboarding.dart';
import '../features/hr/screens/hr_benefits.dart';
import '../features/hr/screens/hr_time_entry.dart';
import '../features/hr/screens/hr_new_hire_checklist.dart';
import '../features/admin/screens/admin_home.dart';
import '../features/admin/tabs/admin_company_tabs.dart';
import '../features/admin/screens/admin_policies.dart';
import '../features/admin/screens/admin_compliance.dart';
import '../features/admin/screens/admin_tax_monitor.dart';
import '../features/admin/forms/admin_state_rule_form.dart';
import '../features/admin/forms/admin_federal_rule_form.dart';
import '../features/admin/screens/admin_setup_wizard.dart';
import '../features/sales/screens/sales_home.dart';
import '../features/sales/screens/customer_portal_requests.dart';
import '../features/sales/screens/customer_invite_screen.dart';
import '../features/sales/tabs/sales_tabs.dart';
import '../features/sales/tabs/marketing_tabs.dart';
import '../features/sales/screens/sales_stats.dart';
import '../features/sales/details/marketing_ads_details.dart';
import '../features/inventory/screens/inventory_home.dart';
import '../features/inventory/screens/inventory_fulfillment.dart';
import '../features/inventory/screens/inventory_request_form.dart';
import '../features/inventory/screens/inventory_stats.dart';
import '../features/purchasing/screens/purchasing_home.dart';
import '../features/purchasing/screens/purchasing_requests.dart';
import '../features/purchasing/tabs/objects_tabs.dart';
import '../features/purchasing/screens/purchasing_vendors.dart';
import '../features/purchasing/screens/purchasing_stats.dart';
import '../features/tasks/screens/tasks_home.dart';
import '../features/tasks/screens/tasks_message.dart';
import '../features/tasks/screens/tasks_quality.dart';
import '../features/tasks/screens/tasks_dependability.dart';
import '../features/tasks/screens/tasks_performance.dart';
import '../features/tasks/screens/tasks_timecard.dart';
import '../features/tasks/screens/tasks_employee_tasks.dart';
import '../features/tasks/screens/task_completion.dart';
import '../features/tasks/screens/task_contributor_list.dart';
import '../features/tasks/details/tasks_message_details.dart';
import '../features/tasks/details/tasks_quality_details.dart';
import '../features/tasks/forms/task_alert_form.dart';
import '../features/tasks/forms/tasks_tasks_form.dart';
import '../features/tasks/forms/tasks_timecard_form.dart';
import '../features/tasks/tabs/task_details_tabs.dart';
import '../features/tasks/tabs/tasks_timecard_tabs.dart';
import '../features/facilities/screens/facilities_home.dart';
import '../features/facilities/forms/property_type_form.dart';
import '../features/facilities/details/property_type_details.dart';
import '../features/marketplace/screens/marketplace_home.dart';
import '../features/marketplace/screens/marketplace_resell.dart';
import '../features/objects/screens/objects_home.dart' as objects_home;
import '../features/objects/screens/objects_objects.dart' as objects_objects;
import '../features/objects/screens/objects_stats.dart' as objects_stats;
import '../features/objects/screens/ai_prompts.dart' as objects_ai_prompts;
import '../features/processes/screens/processes_home.dart';
import '../features/processes/tabs/processes_tabs.dart' as processes_tabs;
import '../features/processes/screens/processes_category_list.dart';
import '../features/processes/screens/processes_measurements.dart';
import '../features/processes/screens/processes_stats.dart';
import '../features/scheduling/screens/scheduling_home.dart';
import '../features/supervision/screens/supervision_home.dart';
import '../features/supervision/tabs/supervision_stats_tabs.dart';
import '../features/training/screens/training_home.dart';
import '../features/training/screens/training_teams.dart';
import '../features/training/tabs/training_employees_tabs.dart';
import '../features/quality/screens/quality_home.dart';
import '../features/quality/screens/quality_inspections.dart';
import '../features/quality/screens/quality_stats.dart';
import '../features/quality/screens/quality_teams.dart';
import '../features/safety/screens/safety_home.dart';
import '../features/safety/screens/safety_analysis.dart';
import '../features/safety/screens/safety_response.dart';
import '../features/safety/screens/safety_stats.dart';
import '../features/occupancy/screens/occupancy_home.dart';
import '../features/engagement/screens/engagement_home.dart';
import '../features/engagement/screens/engagement_platform_screen.dart';
import '../features/engagement/screens/engagement_reports.dart' as engagement_reports;
import '../features/engagement/screens/engagement_stats.dart' as engagement_stats;
import '../features/compliance/screens/compliance_home.dart';
import '../features/compliance/screens/compliance_dashboard_screen.dart';
import '../features/compliance/screens/compliance_item_detail_screen.dart';
import '../features/registration/providers/registration_provider.dart';
import '../features/registration/screens/registration_fork_screen.dart';
import '../features/registration/screens/registration_join_qr_screen.dart';
import '../features/registration/screens/registration_business_type_screen.dart';
import '../features/registration/screens/registration_internal_setup_screen.dart';
import 'routes.dart';

final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  final needsRegistration = ref.watch(needsRegistrationProvider);
  // Owners whose kleenops doc pre-dates the fork-style registration
  // flow (no businessType / propertyType) get caught here and routed
  // back through the fork screens to backfill those fields.
  final profileGate = ref.watch(kleenopsProfileGateProvider).asData?.value;

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutePaths.dashboard,
    observers: [AnalyticsNavigatorObserver()],
    redirect: (context, state) {
      final isLoggedIn = authState.maybeWhen(
        data: (user) => user != null,
        orElse: () => false,
      );
      final here = state.matchedLocation;
      final isLoginRoute = here == AppRoutePaths.login;
      final isRegistrationRoute = here.startsWith('/registration');

      if (!isLoggedIn && !isLoginRoute) return AppRoutePaths.login;
      // Plaid OAuth callback — always let an authenticated session land here so
      // resumePlaidOauthIfPending() can finish the bank link, never bounce it.
      if (here == AppRoutePaths.plaidOauth) return null;
      if (isLoggedIn && isLoginRoute) return AppRoutePaths.dashboard;

      if (isLoggedIn) {
        // Wait for the registration check to resolve before deciding.
        final needs = needsRegistration.asData?.value;
        if (needs == null) return null;

        if (needs == true && !isRegistrationRoute) {
          return AppRoutePaths.registrationFork;
        }

        // Onboarded owner with an incomplete kleenops doc -> backfill.
        if (needs == false &&
            profileGate != null &&
            profileGate.isOwner &&
            !profileGate.profileComplete &&
            !isRegistrationRoute) {
          if (profileGate.businessType == 'internalUse') {
            return AppRoutePaths.registrationInternalSetup;
          }
          // Default fork (covers null businessType and any other case).
          return AppRoutePaths.registrationBusinessType;
        }

        if (needs == false &&
            isRegistrationRoute &&
            (profileGate == null || profileGate.profileComplete)) {
          return AppRoutePaths.dashboard;
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutePaths.login,
        name: AppRouteIds.login,
        builder: (context, state) => const AdminAuthScreen(),
      ),
      // Registration (first-time onboarding) routes
      GoRoute(
        path: AppRoutePaths.registrationFork,
        name: AppRouteIds.registrationFork,
        builder: (context, state) => const RegistrationForkScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.registrationJoinQr,
        name: AppRouteIds.registrationJoinQr,
        builder: (context, state) => const RegistrationJoinQrScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.registrationBusinessType,
        name: AppRouteIds.registrationBusinessType,
        builder: (context, state) => const RegistrationBusinessTypeScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.registrationInternalSetup,
        name: AppRouteIds.registrationInternalSetup,
        builder: (context, state) => const RegistrationInternalSetupScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.dashboard,
        name: AppRouteIds.dashboard,
        builder: (context, state) => SetupGuideGate(
          guide: mainGuide,
          child: const DashboardHome(),
        ),
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
        path: AppRoutePaths.corpToolsInvoices,
        name: AppRouteIds.corpToolsInvoices,
        builder: (context, state) => const CorpToolsInvoicesScreen(),
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
        path: AppRoutePaths.meInfo,
        name: AppRouteIds.meInfo,
        builder: (context, state) => const MeInfoTabsScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.setupDashboard,
        name: AppRouteIds.setupDashboard,
        builder: (context, state) => const SetupDashboardScreen(),
      ),
      // Legal sub-routes
      GoRoute(
        path: AppRoutePaths.legalHome,
        name: AppRouteIds.legalHome,
        builder: (context, state) => SetupGuideGate(
          guide: legalGuide,
          child: const LegalHome(),
        ),
      ),
      GoRoute(
        path: AppRoutePaths.legalDocuments,
        name: AppRouteIds.legalDocuments,
        builder: (context, state) => SetupGuideGate(
          guide: legalGuide,
          child: const LegalDocumentsScreen(),
        ),
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
        builder: (context, state) => SetupGuideGate(
          guide: objectsGuide,
          child: const CatalogHome(),
        ),
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
        builder: (_, __) => SetupGuideGate(
          guide: financeGuide,
          child: const FinancesHomeScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutePaths.financeLedger,
        name: AppRouteIds.financeLedger,
        builder: (_, __) => SetupGuideGate(
          guide: financeGuide,
          child: const FinanceLedgerTabsScreen(),
        ),
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
        path: AppRoutePaths.financeReconciliation,
        name: AppRouteIds.financeReconciliation,
        builder: (_, __) => const FinanceReconciliationScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.financeClassify,
        name: AppRouteIds.financeClassify,
        builder: (_, __) => const FinanceClassifyTransactionsScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.financeAiBookkeeper,
        name: AppRouteIds.financeAiBookkeeper,
        builder: (_, __) => const FinanceAiBookkeeperScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.plaidOauth,
        name: AppRouteIds.plaidOauth,
        builder: (_, __) => const PlaidOauthScreen(),
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
        builder: (_, __) => SetupGuideGate(
          guide: hrGuide,
          child: const HrHomeScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutePaths.hrEmployees,
        name: AppRouteIds.hrEmployees,
        builder: (_, __) => SetupGuideGate(
          guide: hrGuide,
          child: const HrEmployeeTabsScreen(),
        ),
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
        path: AppRoutePaths.hrOnboardingProfileForm,
        name: AppRouteIds.hrOnboardingProfileForm,
        pageBuilder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final docId = extra?['docId'] as String?;
          return _noTransitionPage(
            state,
            CompanyWrapper(
              builder: (companyRef) => HrOnboardingProfileForm(
                companyRef: companyRef,
                docId: docId,
              ),
            ),
          );
        },
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
        builder: (_, __) => SetupGuideGate(
          guide: adminGuide,
          child: const AdminHomeScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutePaths.adminCompany,
        name: AppRouteIds.adminCompany,
        builder: (_, __) => SetupGuideGate(
          guide: adminGuide,
          child: const AdminCompanyTabsScreen(),
        ),
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
        builder: (_, __) => SetupGuideGate(
          guide: salesGuide,
          child: const SalesHomeScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutePaths.salesSales,
        name: AppRouteIds.salesSales,
        builder: (_, __) => SetupGuideGate(
          guide: salesGuide,
          child: const SalesTabsScreen(),
        ),
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
      // Inventory routes
      GoRoute(
        path: AppRoutePaths.inventoryHome,
        name: AppRouteIds.inventoryHome,
        builder: (_, __) => SetupGuideGate(
          guide: inventoryGuide,
          child: const InventoryHomeScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutePaths.inventoryFulfillment,
        name: AppRouteIds.inventoryFulfillment,
        builder: (_, __) => SetupGuideGate(
          guide: inventoryGuide,
          child: const InventoryFulfillmentScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutePaths.inventoryRequestForm,
        name: AppRouteIds.inventoryRequestForm,
        builder: (_, __) => const InventoryRequestFormScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.inventoryStats,
        name: AppRouteIds.inventoryStats,
        builder: (_, __) => const InventoryStatsScreen(),
      ),
      // Purchasing routes
      GoRoute(
        path: AppRoutePaths.purchasingHome,
        name: AppRouteIds.purchasingHome,
        builder: (_, __) => SetupGuideGate(
          guide: purchasingGuide,
          child: const PurchasingHomeScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutePaths.purchasingOrders,
        name: AppRouteIds.purchasingOrders,
        builder: (_, __) => SetupGuideGate(
          guide: purchasingGuide,
          child: const PurchasingRequestsScreen(),
        ),
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

      // ── New overlord feature routes ─────────────────────────────────
      // Action routes (the ones the dashboard buttons go to) are gated;
      // *Home alias routes are not, since they share the same screen.
      GoRoute(
        path: AppRoutePaths.tasksHome,
        name: AppRouteIds.tasksHome,
        builder: (_, __) => const TasksHome(),
      ),
      GoRoute(
        path: AppRoutePaths.tasksTasks,
        name: AppRouteIds.tasksTasks,
        builder: (_, __) => SetupGuideGate(
          guide: tasksGuide,
          child: const TasksHome(),
        ),
      ),
      GoRoute(
        path: AppRoutePaths.tasksMessage,
        name: AppRouteIds.tasksMessage,
        builder: (_, __) => CompanyWrapper(
          builder: (companyRef) => Consumer(
            builder: (context, ref, _) {
              final memberRef = ref.watch(memberDocRefProvider).value;
              if (memberRef == null) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              return _FeatureContentScaffold(
                title: 'Messages',
                child: TasksMessageContent(
                  pendingDocs: const [],
                  memberRef: memberRef,
                ),
              );
            },
          ),
        ),
      ),
      GoRoute(
        path: AppRoutePaths.tasksMessageDetails,
        name: AppRouteIds.tasksMessageDetails,
        pageBuilder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final docRef = extra?['docRef'] as DocumentReference<Map<String, dynamic>>?;
          final memberRef = extra?['memberRef'] as DocumentReference<Map<String, dynamic>>?;
          if (docRef == null || memberRef == null) {
            return _noTransitionPage(state, const Scaffold(
              body: Center(child: Text('Missing message reference')),
            ));
          }
          return _noTransitionPage(state, TasksMessageDetails(
            docRef: docRef,
            memberRef: memberRef,
          ));
        },
      ),
      GoRoute(
        path: AppRoutePaths.tasksQuality,
        name: AppRouteIds.tasksQuality,
        builder: (_, __) => const _FeatureContentScaffold(
          title: 'Quality',
          child: TasksQualityContent(),
        ),
      ),
      GoRoute(
        path: AppRoutePaths.tasksQualityDetails,
        name: AppRouteIds.tasksQualityDetails,
        pageBuilder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final companyRef = extra?['companyId'] as DocumentReference<Map<String, dynamic>>?;
          final docId = extra?['docId'] as String?;
          if (companyRef == null || docId == null) {
            return _noTransitionPage(state, const Scaffold(
              body: Center(child: Text('Missing quality reference')),
            ));
          }
          return _noTransitionPage(state, TasksQualityDetails(
            companyId: companyRef,
            docId: docId,
          ));
        },
      ),
      GoRoute(
        path: AppRoutePaths.tasksDependability,
        name: AppRouteIds.tasksDependability,
        builder: (_, __) => const _FeatureContentScaffold(
          title: 'Dependability',
          child: TasksDependabilityContent(),
        ),
      ),
      GoRoute(
        path: AppRoutePaths.tasksPerformance,
        name: AppRouteIds.tasksPerformance,
        builder: (_, __) => const _FeatureContentScaffold(
          title: 'Performance',
          child: TasksPerformanceContent(),
        ),
      ),
      GoRoute(
        path: AppRoutePaths.tasksTimecard,
        name: AppRouteIds.tasksTimecard,
        builder: (_, __) => const _FeatureContentScaffold(
          title: 'Timecard',
          child: TasksTimecardContent(),
        ),
      ),
      GoRoute(
        path: AppRoutePaths.tasksTimecardTabs,
        name: AppRouteIds.tasksTimecardTabs,
        builder: (_, __) => const TasksTimecardTabsScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.tasksTimecardForm,
        name: AppRouteIds.tasksTimecardForm,
        pageBuilder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final docId = extra?['docId'] as String?;
          return _noTransitionPage(state, CompanyWrapper(
            builder: (companyRef) => TasksTimecardForm(
              companyId: companyRef,
              docId: docId,
            ),
          ));
        },
      ),
      GoRoute(
        path: AppRoutePaths.tasksEmployeeTasks,
        name: AppRouteIds.tasksEmployeeTasks,
        builder: (_, __) => const _FeatureContentScaffold(
          title: 'Employee Tasks',
          child: TasksEmployeeTasksContent(),
        ),
      ),
      GoRoute(
        path: AppRoutePaths.taskCompletion,
        name: AppRouteIds.taskCompletion,
        builder: (_, state) {
          final qp = state.uri.queryParameters;
          return TaskCompletion(
            companyId: qp['companyId'] ?? '',
            docId: qp['docId'] ?? '',
          );
        },
      ),
      GoRoute(
        path: AppRoutePaths.taskContributorList,
        name: AppRouteIds.taskContributorList,
        builder: (_, state) {
          final qp = state.uri.queryParameters;
          return TaskContributorList(
            companyId: qp['companyId'] ?? '',
            docId: qp['docId'] ?? '',
          );
        },
      ),
      GoRoute(
        path: AppRoutePaths.taskDetailsTabs,
        name: AppRouteIds.taskDetailsTabs,
        builder: (_, state) {
          final qp = state.uri.queryParameters;
          return TaskDetailsTabs(
            routineId: qp['routineId'] ?? '',
            companyId: qp['companyId'] ?? '',
            teamId: qp['teamId'],
          );
        },
      ),
      GoRoute(
        path: AppRoutePaths.taskAlertForm,
        name: AppRouteIds.taskAlertForm,
        pageBuilder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final timelineRef = extra?['timelineRef']
              as DocumentReference<Map<String, dynamic>>?;
          if (timelineRef == null) {
            return _noTransitionPage(state, const Scaffold(
              body: Center(child: Text('Missing timeline reference')),
            ));
          }
          return _noTransitionPage(state, TaskAlertForm(timelineRef: timelineRef));
        },
      ),
      GoRoute(
        path: AppRoutePaths.facilitiesHome,
        name: AppRouteIds.facilitiesHome,
        builder: (_, __) => const FacilitiesHome(),
      ),
      GoRoute(
        path: AppRoutePaths.facilitiesProperties,
        name: AppRouteIds.facilitiesProperties,
        builder: (_, __) => SetupGuideGate(
          guide: facilitiesGuide,
          child: const FacilitiesHome(),
        ),
      ),
      GoRoute(
        path: AppRoutePaths.facilitiesPropertyTypeForm,
        name: AppRouteIds.facilitiesPropertyTypeForm,
        pageBuilder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final docId = extra?['docId'] as String?;
          return _noTransitionPage(state, PropertyTypeForm(docId: docId));
        },
      ),
      GoRoute(
        path: AppRoutePaths.facilitiesPropertyTypeDetails,
        name: AppRouteIds.facilitiesPropertyTypeDetails,
        pageBuilder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final docId = (extra?['docId'] ?? '') as String;
          return _noTransitionPage(
            state,
            PropertyTypeDetailsScreen(docId: docId),
          );
        },
      ),
      GoRoute(
        path: AppRoutePaths.marketplaceHome,
        name: AppRouteIds.marketplaceHome,
        builder: (_, __) => SetupGuideGate(
          guide: marketplaceGuide,
          child: const MarketplaceHome(),
        ),
      ),
      GoRoute(
        path: AppRoutePaths.marketplaceResell,
        name: AppRouteIds.marketplaceResell,
        builder: (_, __) => SetupGuideGate(
          guide: marketplaceGuide,
          child: const MarketplaceResellScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutePaths.objectsHome,
        name: AppRouteIds.objectsHome,
        builder: (_, __) => const objects_home.ObjectsHomeScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.objectsObjects,
        name: AppRouteIds.objectsObjects,
        builder: (_, __) => const _FeatureContentScaffold(
          title: 'Objects',
          child: objects_objects.ObjectsObjectsContent(),
        ),
      ),
      GoRoute(
        path: AppRoutePaths.objectsStats,
        name: AppRouteIds.objectsStats,
        builder: (_, __) => const objects_stats.ObjectsStatsScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.objectsAiPrompts,
        name: AppRouteIds.objectsAiPrompts,
        builder: (_, __) => const objects_ai_prompts.AiPromptsScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.processesHome,
        name: AppRouteIds.processesHome,
        builder: (_, __) => SetupGuideGate(
          guide: processesGuide,
          child: const ProcessesHome(),
        ),
      ),
      GoRoute(
        path: AppRoutePaths.processesTabs,
        name: AppRouteIds.processesTabs,
        builder: (_, __) => const processes_tabs.ProcessesTabsScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.processesCategoryList,
        name: AppRouteIds.processesCategoryList,
        builder: (_, __) => const _FeatureContentScaffold(
          title: 'Categories',
          child: ProcessesCategoryListScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutePaths.processesMeasurements,
        name: AppRouteIds.processesMeasurements,
        builder: (_, __) => const _FeatureContentScaffold(
          title: 'Measurements',
          child: ProcessesMeasurementsContent(),
        ),
      ),
      GoRoute(
        path: AppRoutePaths.processesStats,
        name: AppRouteIds.processesStats,
        builder: (_, __) => const ProcessesStatsScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.schedulingHome,
        name: AppRouteIds.schedulingHome,
        builder: (_, __) => const SchedulingHome(),
      ),
      GoRoute(
        path: AppRoutePaths.schedulingTeams,
        name: AppRouteIds.schedulingTeams,
        builder: (_, __) => SetupGuideGate(
          guide: schedulingGuide,
          child: const SchedulingHome(),
        ),
      ),
      GoRoute(
        path: AppRoutePaths.supervisionHome,
        name: AppRouteIds.supervisionHome,
        builder: (_, __) => const SupervisionHome(),
      ),
      GoRoute(
        path: AppRoutePaths.supervisionTeams,
        name: AppRouteIds.supervisionTeams,
        builder: (_, __) => SetupGuideGate(
          guide: supervisionGuide,
          child: const SupervisionHome(),
        ),
      ),
      GoRoute(
        path: AppRoutePaths.supervisionStats,
        name: AppRouteIds.supervisionStats,
        builder: (_, __) => const SupervisionStatsTabs(),
      ),
      GoRoute(
        path: AppRoutePaths.trainingHome,
        name: AppRouteIds.trainingHome,
        builder: (_, __) => SetupGuideGate(
          guide: trainingGuide,
          child: const TrainingHome(),
        ),
      ),
      GoRoute(
        path: AppRoutePaths.trainingTeams,
        name: AppRouteIds.trainingTeams,
        builder: (_, __) => const TrainingTeamsScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.trainingEmployees,
        name: AppRouteIds.trainingEmployees,
        builder: (_, __) => const TrainingEmployeesTabsScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.qualityHome,
        name: AppRouteIds.qualityHome,
        builder: (_, __) => const QualityHome(),
      ),
      GoRoute(
        path: AppRoutePaths.qualityTeams,
        name: AppRouteIds.qualityTeams,
        builder: (_, __) => const QualityTeamsScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.qualityInspections,
        name: AppRouteIds.qualityInspections,
        builder: (_, __) => const QualityInspectionsScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.qualityStats,
        name: AppRouteIds.qualityStats,
        builder: (_, __) => const QualityStatsScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.safetyHome,
        name: AppRouteIds.safetyHome,
        builder: (_, __) => const SafetyHome(),
      ),
      GoRoute(
        path: AppRoutePaths.safetyAnalysis,
        name: AppRouteIds.safetyAnalysis,
        builder: (_, __) => const SafetyAnalysisScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.safetyResponse,
        name: AppRouteIds.safetyResponse,
        builder: (_, __) => const SafetyResponseScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.safetyStats,
        name: AppRouteIds.safetyStats,
        builder: (_, __) => const SafetyStatsScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.occupancyHome,
        name: AppRouteIds.occupancyHome,
        builder: (_, __) => const OccupancyHome(),
      ),
      GoRoute(
        path: AppRoutePaths.occupancyProperty,
        name: AppRouteIds.occupancyProperty,
        builder: (_, __) => SetupGuideGate(
          guide: occupancyGuide,
          child: const OccupancyHome(),
        ),
      ),
      GoRoute(
        path: AppRoutePaths.engagementHome,
        name: AppRouteIds.engagementHome,
        builder: (_, __) => const EngagementHome(),
      ),
      GoRoute(
        path: AppRoutePaths.engagementMobile,
        name: AppRouteIds.engagementMobile,
        builder: (_, __) =>
            const EngagementPlatformScreen(platform: 'mobile', title: 'Mobile'),
      ),
      GoRoute(
        path: AppRoutePaths.engagementWeb,
        name: AppRouteIds.engagementWeb,
        builder: (_, __) =>
            const EngagementPlatformScreen(platform: 'web', title: 'Web'),
      ),
      GoRoute(
        path: AppRoutePaths.engagementReports,
        name: AppRouteIds.engagementReports,
        builder: (_, __) => const engagement_reports.EngagementReportsScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.engagementStats,
        name: AppRouteIds.engagementStats,
        builder: (_, __) => const engagement_stats.EngagementStatsScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.complianceHome,
        name: AppRouteIds.complianceHome,
        builder: (_, __) => const ComplianceHome(),
      ),
      GoRoute(
        path: AppRoutePaths.complianceDashboard,
        name: AppRouteIds.complianceDashboard,
        builder: (_, __) => const ComplianceDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.complianceItemDetail,
        name: AppRouteIds.complianceItemDetail,
        pageBuilder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return _noTransitionPage(
            state,
            ComplianceItemDetailScreen.fromExtra(extra),
          );
        },
      ),

      // ── Communication routes ──────────────────────────────────────────
      GoRoute(
        path: AppRoutePaths.commInternalMessages,
        name: AppRouteIds.commInternalMessages,
        builder: (_, __) => const TextConversationsScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.commMessageBoard,
        name: AppRouteIds.commMessageBoard,
        builder: (_, __) => const MessageBoardScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.commExternalMessages,
        name: AppRouteIds.commExternalMessages,
        builder: (_, __) => const CommPlaceholderScreen(
          title: 'External Messages',
          icon: Icons.sms_outlined,
          description:
              'SMS messaging with external contacts will be available '
              'once Twilio SMS integration is configured.',
        ),
      ),
      GoRoute(
        path: AppRoutePaths.commEmail,
        name: AppRouteIds.commEmail,
        builder: (_, __) => const EmailInboxScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.commCalendar,
        name: AppRouteIds.commCalendar,
        builder: (_, __) => const CommunicationsCalendarScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.commDirectory,
        name: AppRouteIds.commDirectory,
        builder: (_, __) => const AdminDirectoryScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.commIntercom,
        name: AppRouteIds.commIntercom,
        builder: (_, __) => const AdminIntercomScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.commPhone,
        name: AppRouteIds.commPhone,
        builder: (_, __) =>
            const AdminCallHistoryScreen(kind: CallHistoryKind.voice),
      ),
      GoRoute(
        path: AppRoutePaths.commVideoCall,
        name: AppRouteIds.commVideoCall,
        builder: (_, __) =>
            const AdminCallHistoryScreen(kind: CallHistoryKind.video),
      ),

      // ── Resource routes ───────────────────────────────────────────────
      GoRoute(
        path: AppRoutePaths.drawerFiles,
        name: AppRouteIds.drawerFiles,
        builder: (_, __) => const DrivesScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.drawerMyTasks,
        name: AppRouteIds.drawerMyTasks,
        builder: (_, __) => const MyTasksScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.drawerReminders,
        name: AppRouteIds.drawerReminders,
        builder: (_, __) => const RemindersScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.agentTasks,
        name: AppRouteIds.agentTasks,
        builder: (_, __) => const AgentTasksListScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.drawerCalendarForm,
        name: AppRouteIds.drawerCalendarForm,
        builder: (context, state) {
          final docId = state.uri.queryParameters['docId'];
          final dateRaw = state.uri.queryParameters['date'];
          final initialDate =
              dateRaw == null ? null : DateTime.tryParse(dateRaw);
          return CalendarEventFormScreen(
            docId: docId,
            initialDate: initialDate,
          );
        },
      ),

      // ── Notes + Meeting Minutes routes ────────────────────────────────
      GoRoute(
        path: AppRoutePaths.drawerNotes,
        name: AppRouteIds.drawerNotes,
        builder: (_, __) => const NotesHomeScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.drawerNotesFolder,
        name: AppRouteIds.drawerNotesFolder,
        builder: (context, state) {
          final folderId = state.uri.queryParameters['folderId'] ?? '';
          return NotesFolderScreen(folderId: folderId);
        },
      ),
      GoRoute(
        path: AppRoutePaths.drawerNotesContent,
        name: AppRouteIds.drawerNotesContent,
        builder: (context, state) {
          final contentId = state.uri.queryParameters['contentId'] ?? '';
          return NotesContentDetailScreen(contentId: contentId);
        },
      ),
      GoRoute(
        path: AppRoutePaths.drawerMeetingMinutes,
        name: AppRouteIds.drawerMeetingMinutes,
        builder: (_, __) => const MeetingMinutesScreen(),
      ),
    ],
  );
});

// Detail routes keep the bottom nav; skip transitions to avoid re-animating it.
Page<void> _noTransitionPage(GoRouterState state, Widget child) {
  return NoTransitionPage<void>(key: state.pageKey, child: child);
}

/// Wraps a hub sub-screen "Content" widget in the bookend Scaffold chrome
/// admin uses for its hub sub-screens (DetailsAppBar + HomeNavBarAdapter).
class _FeatureContentScaffold extends StatelessWidget {
  const _FeatureContentScaffold({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: StandardCanvas(
        child: SafeArea(
          top: true,
          bottom: false,
          child: Stack(
            children: [
              Positioned.fill(child: child),
              const Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: CanvasTopBookend(),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(title: title),
          const HomeNavBarAdapter(),
        ],
      ),
    );
  }
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
