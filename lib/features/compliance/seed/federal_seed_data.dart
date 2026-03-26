// lib/features/compliance/seed/federal_seed_data.dart

/// 2026 Federal employment and tax rules.
/// Sources: IRS, DOL, SSA projections based on 2025 actuals + CPI adjustments.
const Map<String, dynamic> kFederalRule2026 = {
  'effectiveYear': 2026,

  // ─── Wages & Overtime ───
  'federalMinimumWage': 7.25,
  'overtimeThresholdWeekly': 40,

  // ─── FICA (Social Security + Medicare) ───
  'ficaRate': 0.0765,
  'socialSecurityRate': 0.062,
  'socialSecurityWageCap': 176100,
  'medicareRate': 0.0145,
  'additionalMedicareThreshold': 200000,
  'additionalMedicareRate': 0.009,

  // ─── FUTA (Federal Unemployment) ───
  'futaRate': 0.006,
  'futaWageCap': 7000,

  // ─── ACA ───
  'acaBenefitsThreshold': 30, // hours/week → full-time for benefits

  // ─── FMLA ───
  'fmla': {
    'eligible': true,
    'employeeThreshold': 50,
    'weeksEntitled': 12,
    'description':
        'Employers with 50+ employees must provide up to 12 weeks unpaid leave for qualifying events.',
  },

  // ─── OSHA ───
  'osha': {
    'recordkeepingThreshold': 10,
    'form300Required': true,
    'form301Required': true,
    'description':
        'Employers with 10+ employees must maintain injury/illness logs (Forms 300, 300A, 301).',
  },

  // ─── ADA ───
  'ada': {
    'employeeThreshold': 15,
    'reasonableAccommodationRequired': true,
    'description':
        'Employers with 15+ employees must provide reasonable accommodations for disabilities.',
  },

  // ─── EIN ───
  'ein': {
    'required': true,
    'irsApplyUrl':
        'https://www.irs.gov/businesses/small-businesses-self-employed/apply-for-an-employer-identification-number-ein-online',
    'description':
        'All employers must have an EIN to report taxes and file returns.',
  },

  // ─── E-Verify ───
  'eVerify': {
    'federalContractorsRequired': true,
    'url': 'https://www.e-verify.gov/',
    'description':
        'Required for federal contractors. Some states mandate for all employers.',
  },

  // ─── Tax Filing Schedule ───
  'taxFilingSchedule': [
    {
      'formId': '941',
      'name': 'Quarterly Federal Tax Return',
      'frequency': 'quarterly',
      'months': [1, 4, 7, 10],
      'dayDue': 30,
      'description':
          'Report income taxes, Social Security, and Medicare taxes withheld from employee paychecks.',
      'url': 'https://www.irs.gov/forms-pubs/about-form-941',
    },
    {
      'formId': '940',
      'name': 'Annual FUTA Return',
      'frequency': 'annual',
      'month': 1,
      'dayDue': 31,
      'description':
          'Report and pay federal unemployment tax. Due January 31 for the prior year.',
      'url': 'https://www.irs.gov/forms-pubs/about-form-940',
    },
    {
      'formId': 'W-2',
      'name': 'W-2 Wage and Tax Statements',
      'frequency': 'annual',
      'month': 1,
      'dayDue': 31,
      'description':
          'Furnish to employees and file with SSA by January 31.',
      'url': 'https://www.irs.gov/forms-pubs/about-form-w-2',
    },
    {
      'formId': 'W-3',
      'name': 'W-3 Transmittal of Wage Statements',
      'frequency': 'annual',
      'month': 1,
      'dayDue': 31,
      'description': 'Transmittal form filed with W-2s to SSA.',
      'url': 'https://www.irs.gov/forms-pubs/about-form-w-3',
    },
    {
      'formId': '1099-NEC',
      'name': 'Non-Employee Compensation',
      'frequency': 'annual',
      'month': 1,
      'dayDue': 31,
      'description':
          'Report payments of \$600+ to independent contractors.',
      'url': 'https://www.irs.gov/forms-pubs/about-form-1099-nec',
    },
    {
      'formId': '944',
      'name': 'Annual Federal Tax Return (Small Employers)',
      'frequency': 'annual',
      'month': 1,
      'dayDue': 31,
      'description':
          'Alternative to 941 for employers with \$1,000 or less in annual employment tax liability.',
      'url': 'https://www.irs.gov/forms-pubs/about-form-944',
    },
  ],

  // ─── Required Federal Workplace Postings ───
  'requiredPostings': [
    {
      'name': 'Federal Minimum Wage (FLSA)',
      'url':
          'https://www.dol.gov/agencies/whd/posters/flsa',
      'required': true,
      'threshold': 0,
    },
    {
      'name': 'OSHA Job Safety and Health',
      'url':
          'https://www.osha.gov/publications/poster',
      'required': true,
      'threshold': 0,
    },
    {
      'name': 'Equal Employment Opportunity (EEO)',
      'url':
          'https://www.eeoc.gov/poster',
      'required': true,
      'requiredAbove': 15,
    },
    {
      'name': 'Family and Medical Leave Act (FMLA)',
      'url':
          'https://www.dol.gov/agencies/whd/posters/fmla',
      'required': true,
      'requiredAbove': 50,
    },
    {
      'name': 'Employee Polygraph Protection Act',
      'url':
          'https://www.dol.gov/agencies/whd/posters/employee-polygraph-protection-act',
      'required': true,
      'threshold': 0,
    },
    {
      'name': 'Uniformed Services (USERRA)',
      'url':
          'https://www.dol.gov/agencies/vets/programs/userra/poster',
      'required': true,
      'threshold': 0,
    },
  ],

  // ─── Federal Income Tax Brackets (2026 Single) ───
  'taxBracketsSingle': [
    {'min': 0, 'max': 11925, 'rate': 0.10},
    {'min': 11925, 'max': 48475, 'rate': 0.12},
    {'min': 48475, 'max': 103350, 'rate': 0.22},
    {'min': 103350, 'max': 197300, 'rate': 0.24},
    {'min': 197300, 'max': 250525, 'rate': 0.32},
    {'min': 250525, 'max': 626350, 'rate': 0.35},
    {'min': 626350, 'max': 999999999, 'rate': 0.37},
  ],
  'taxBracketsMarried': [
    {'min': 0, 'max': 23850, 'rate': 0.10},
    {'min': 23850, 'max': 96950, 'rate': 0.12},
    {'min': 96950, 'max': 206700, 'rate': 0.22},
    {'min': 206700, 'max': 394600, 'rate': 0.24},
    {'min': 394600, 'max': 501050, 'rate': 0.32},
    {'min': 501050, 'max': 752800, 'rate': 0.35},
    {'min': 752800, 'max': 999999999, 'rate': 0.37},
  ],
  'standardDeductions': {
    'single': 15000,
    'married': 30000,
    'headOfHousehold': 22500,
  },
};
