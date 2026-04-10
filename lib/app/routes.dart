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
  static const hrOnboardingProfile = 'hrOnboardingProfile';
  static const hrOnboardingProfileForm = 'hrOnboardingProfileForm';
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

  // Inventory
  static const inventoryHome = 'inventoryHome';
  static const inventoryFulfillment = 'inventoryFulfillment';
  static const inventoryRequestForm = 'inventoryRequestForm';
  static const inventoryStats = 'inventoryStats';

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

  // Registration (first-time onboarding)
  static const registrationFork = 'registrationFork';
  static const registrationJoinQr = 'registrationJoinQr';
  static const registrationBusinessType = 'registrationBusinessType';
  static const registrationInternalSetup = 'registrationInternalSetup';

  // Tasks
  static const tasksHome = 'tasksHome';
  static const tasksTasks = 'tasksTasks';

  // Facilities
  static const facilitiesHome = 'facilitiesHome';
  static const facilitiesProperties = 'facilitiesProperties';

  // Marketplace
  static const marketplaceHome = 'marketplaceHome';
  static const marketplaceResell = 'marketplaceResell';

  // Objects
  static const objectsHome = 'objectsHome';

  // Processes
  static const processesHome = 'processesHome';

  // Scheduling
  static const schedulingHome = 'schedulingHome';
  static const schedulingTeams = 'schedulingTeams';

  // Supervision
  static const supervisionHome = 'supervisionHome';
  static const supervisionTeams = 'supervisionTeams';

  // Training
  static const trainingHome = 'trainingHome';

  // Quality
  static const qualityHome = 'qualityHome';
  static const qualityTeams = 'qualityTeams';

  // Safety
  static const safetyHome = 'safetyHome';
  static const safetyAnalysis = 'safetyAnalysis';

  // Occupancy
  static const occupancyHome = 'occupancyHome';
  static const occupancyProperty = 'occupancyProperty';

  // Engagement
  static const engagementHome = 'engagementHome';
  static const engagementReports = 'engagementReports';

  // Setup dashboard (post-registration card-based onboarding)
  static const setupDashboard = 'setupDashboard';

  // Me (admin's own profile + onboarding)
  static const meInfo = 'meInfo';

  // Communications
  static const commInternalMessages = 'commInternalMessages';
  static const commExternalMessages = 'commExternalMessages';
  static const commMessageBoard = 'commMessageBoard';
  static const commEmail = 'commEmail';
  static const commCalendar = 'commCalendar';
  static const commDirectory = 'commDirectory';
  static const commIntercom = 'commIntercom';
  static const commVideoCall = 'commVideoCall';
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
  static const hrOnboardingProfile = '/hr/onboarding/profile';
  static const hrOnboardingProfileForm = '/hr/onboarding/profile/form';
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

  // Inventory
  static const inventoryHome = '/inventory/home';
  static const inventoryFulfillment = '/inventory/fulfillment';
  static const inventoryRequestForm = '/inventory/request/form';
  static const inventoryStats = '/inventory/stats';

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

  // Registration (first-time onboarding)
  static const registrationFork = '/registration';
  static const registrationJoinQr = '/registration/join';
  static const registrationBusinessType = '/registration/business-type';
  static const registrationInternalSetup = '/registration/internal-setup';

  // Tasks
  static const tasksHome = '/tasks/home';
  static const tasksTasks = '/tasks/tasks';

  // Facilities
  static const facilitiesHome = '/facilities/home';
  static const facilitiesProperties = '/facilities/properties';

  // Marketplace
  static const marketplaceHome = '/marketplace/home';
  static const marketplaceResell = '/marketplace/resell';

  // Objects
  static const objectsHome = '/objects';

  // Processes
  static const processesHome = '/processes/home';

  // Scheduling
  static const schedulingHome = '/scheduling/home';
  static const schedulingTeams = '/scheduling/teams';

  // Supervision
  static const supervisionHome = '/supervision/home';
  static const supervisionTeams = '/supervision/teams';

  // Training
  static const trainingHome = '/training/home';

  // Quality
  static const qualityHome = '/quality/home';
  static const qualityTeams = '/quality/teams';

  // Safety
  static const safetyHome = '/safety/home';
  static const safetyAnalysis = '/safety/analysis';

  // Occupancy
  static const occupancyHome = '/occupancy/home';
  static const occupancyProperty = '/occupancy/property';

  // Engagement
  static const engagementHome = '/engagement/home';
  static const engagementReports = '/engagement/reports';

  // Setup dashboard (post-registration card-based onboarding)
  static const setupDashboard = '/setup';

  // Me (admin's own profile + onboarding)
  static const meInfo = '/me/info';

  // Communications
  static const commInternalMessages = '/comm/internal-messages';
  static const commExternalMessages = '/comm/external-messages';
  static const commMessageBoard = '/comm/message-board';
  static const commEmail = '/comm/email';
  static const commCalendar = '/comm/calendar';
  static const commDirectory = '/comm/directory';
  static const commIntercom = '/comm/intercom';
  static const commVideoCall = '/comm/video-call';
}
