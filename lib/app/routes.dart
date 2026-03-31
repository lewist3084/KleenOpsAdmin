// lib/app/routes.dart

class AppRouteIds {
  // Auth
  static const login = 'login';

  // Dashboard
  static const dashboard = 'dashboard';

  // Companies
  static const companiesHome = 'companiesHome';
  static const companiesDetails = 'companiesDetails';

  // Billing
  static const billingHome = 'billingHome';

  // AI Usage
  static const aiUsageHome = 'aiUsageHome';

  // Storage
  static const storageHome = 'storageHome';

  // Users
  static const usersHome = 'usersHome';

  // Onboarding Review
  static const onboardingHome = 'onboardingHome';

  // Legal
  static const legalHome = 'legalHome';
  static const legalDocuments = 'legalDocuments';
  static const legalCompliance = 'legalCompliance';
  static const legalContracts = 'legalContracts';
  static const legalStats = 'legalStats';

  // Support
  static const supportHome = 'supportHome';

  // Catalog
  static const catalogHome = 'catalogHome';
  static const catalogScrapeJobs = 'catalogScrapeJobs';
  static const catalogStagingReview = 'catalogStagingReview';
  static const catalogBrandOwners = 'catalogBrandOwners';

  // Device Registry
  static const deviceRegistryHome = 'deviceRegistryHome';

  // Finance
  static const financeHome = 'financeHome';
  static const financeLedger = 'financeLedger';
  static const financeCustomers = 'financeCustomers';
  static const financeInvoices = 'financeInvoices';
  static const financeBills = 'financeBills';
  static const financePayments = 'financePayments';
  static const financeAccounts = 'financeAccounts';
  static const financeStats = 'financeStats';
  static const financeBanking = 'financeBanking';
  static const financeSetupWizard = 'financeSetupWizard';
  static const financePayroll = 'financePayroll';
  static const financePayrollRunDetails = 'financePayrollRunDetails';
  static const financePayrollRunForm = 'financePayrollRunForm';
  static const financePayStubDetails = 'financePayStubDetails';
  static const financeW2Generation = 'financeW2Generation';

  // HR
  static const hrHome = 'hrHome';
  static const hrEmployees = 'hrEmployees';
  static const hrEmployeesDetails = 'hrEmployeesDetails';
  static const hrRoles = 'hrRoles';
  static const hrTeam = 'hrTeam';
  static const hrTeamForm = 'hrTeamForm';
  static const hrTimeOff = 'hrTimeOff';
  static const hrDocuments = 'hrDocuments';
  static const hrTicketScanner = 'hrTicketScanner';
  static const hrStats = 'hrStats';
  static const hrOnboarding = 'hrOnboarding';
  static const hrOnboardingDetails = 'hrOnboardingDetails';
  static const hrBenefits = 'hrBenefits';
  static const hrBenefitPlanDetails = 'hrBenefitPlanDetails';
  static const hrBenefitPlanForm = 'hrBenefitPlanForm';
  static const hrBenefitEnrollmentForm = 'hrBenefitEnrollmentForm';
  static const hrOnboardingTemplateForm = 'hrOnboardingTemplateForm';
  static const hrTimeEntry = 'hrTimeEntry';
  static const hrNewHireChecklist = 'hrNewHireChecklist';

  // Administration
  static const adminHome = 'adminHome';
  static const adminCompany = 'adminCompany';
  static const adminPolicies = 'adminPolicies';
  static const adminCompliance = 'adminCompliance';
  static const adminStateRuleForm = 'adminStateRuleForm';
  static const adminFederalRuleForm = 'adminFederalRuleForm';
  static const adminTaxMonitor = 'adminTaxMonitor';
  static const adminSetupWizard = 'adminSetupWizard';

  // Sales
  static const salesHome = 'salesHome';
  static const salesSales = 'salesSales';
  static const salesMarketing = 'salesMarketing';
  static const salesMarketingAdsDetails = 'salesMarketingAdsDetails';
  static const salesStats = 'salesStats';
  static const salesCustomerPortalRequests = 'salesCustomerPortalRequests';
  static const salesCustomerInvite = 'salesCustomerInvite';

  // Purchasing
  static const purchasingHome = 'purchasingHome';
  static const purchasingObjects = 'purchasingObjects';
  static const purchasingObjectsDetails = 'purchasingObjectsDetails';
  static const purchasingObjectsForm = 'purchasingObjectsForm';
  static const purchasingOrders = 'purchasingOrders';
  static const purchasingVendors = 'purchasingVendors';
  static const purchasingStats = 'purchasingStats';
}

class AppRoutePaths {
  static const login = '/login';
  static const dashboard = '/';
  static const companies = '/companies';
  static const companiesDetails = '/companies/details';
  static const billing = '/billing';
  static const aiUsage = '/ai-usage';
  static const storage = '/storage';
  static const users = '/users';
  static const onboarding = '/onboarding';
  static const support = '/support';

  // Legal
  static const legalHome = '/legal/home';
  static const legalDocuments = '/legal/documents';
  static const legalCompliance = '/legal/compliance';
  static const legalContracts = '/legal/contracts';
  static const legalStats = '/legal/stats';

  // Catalog
  static const catalog = '/catalog';
  static const catalogScrapeJobs = '/catalog/scrape-jobs';
  static const catalogStagingReview = '/catalog/staging-review';
  static const catalogBrandOwners = '/catalog/brand-owners';

  // Device Registry
  static const deviceRegistry = '/device-registry';

  // Finance
  static const financeHome = '/finance/home';
  static const financeLedger = '/finance/ledger';
  static const financeCustomers = '/finance/customers';
  static const financeInvoices = '/finance/invoices';
  static const financeBills = '/finance/bills';
  static const financePayments = '/finance/payments';
  static const financeAccounts = '/finance/accounts';
  static const financeStats = '/finance/stats';
  static const financeBanking = '/finance/banking';
  static const financeSetupWizard = '/finance/setup-wizard';
  static const financePayroll = '/finance/payroll';
  static const financePayrollRunDetails = '/finance/payroll/details';
  static const financePayrollRunForm = '/finance/payroll/form';
  static const financePayStubDetails = '/finance/payroll/paystub';
  static const financeW2Generation = '/finance/w2';

  // HR
  static const hrHome = '/hr/home';
  static const hrEmployees = '/hr/employees';
  static const hrEmployeesDetails = '/hr/employees/details';
  static const hrRoles = '/hr/roles';
  static const hrTeam = '/hr/team';
  static const hrTeamForm = '/hr/team/form';
  static const hrTimeOff = '/hr/timeoff';
  static const hrDocuments = '/hr/documents';
  static const hrTicketScanner = '/hr/ticket/scanner';
  static const hrStats = '/hr/stats';
  static const hrOnboarding = '/hr/onboarding';
  static const hrOnboardingDetails = '/hr/onboarding/details';
  static const hrBenefits = '/hr/benefits';
  static const hrBenefitPlanDetails = '/hr/benefits/details';
  static const hrBenefitPlanForm = '/hr/benefits/form';
  static const hrBenefitEnrollmentForm = '/hr/benefits/enrollment/form';
  static const hrOnboardingTemplateForm = '/hr/onboarding/template/form';
  static const hrTimeEntry = '/hr/time-entry';
  static const hrNewHireChecklist = '/hr/new-hire-checklist';

  // Administration
  static const adminHome = '/admin/home';
  static const adminCompany = '/admin/company';
  static const adminPolicies = '/admin/policies';
  static const adminCompliance = '/admin/compliance';
  static const adminStateRuleForm = '/admin/compliance/state/form';
  static const adminFederalRuleForm = '/admin/compliance/federal/form';
  static const adminTaxMonitor = '/admin/compliance/tax-monitor';
  static const adminSetupWizard = '/admin/setup-wizard';

  // Sales
  static const salesHome = '/sales/home';
  static const salesSales = '/sales/sales';
  static const salesMarketing = '/sales/marketing';
  static const salesMarketingAdsDetails = '/sales/marketing/ads/details';
  static const salesStats = '/sales/stats';
  static const salesCustomerPortalRequests = '/sales/customer-portal-requests';
  static const salesCustomerInvite = '/sales/customer-invite';

  // Purchasing
  static const purchasingHome = '/purchasing/home';
  static const purchasingObjects = '/purchasing/objects';
  static const purchasingObjectsDetails = '/purchasing/objects/details';
  static const purchasingObjectsForm = '/purchasing/objects/form';
  static const purchasingOrders = '/purchasing/orders';
  static const purchasingVendors = '/purchasing/vendors';
  static const purchasingStats = '/purchasing/stats';
}
