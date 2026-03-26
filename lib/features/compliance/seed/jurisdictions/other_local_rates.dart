// lib/features/compliance/seed/jurisdictions/other_local_rates.dart
//
// Local income tax rates for states not covered by dedicated files.
// Covers: Kentucky, Alabama, Missouri, Colorado, Delaware, New York,
//         Oregon, West Virginia, New Jersey (payroll taxes).
// Effective 2025/2026 tax year.

// ═══════════════════════════════════════════════════════════════
// KENTUCKY — Occupational License Tax (cities/counties)
// ═══════════════════════════════════════════════════════════════
// ~200 cities + counties. Top metro areas shown.
const Map<String, Map<String, dynamic>> kKentuckyLocalRates = {
  'KY_LOUISVILLE':      {'name': 'Louisville/Jefferson Co', 'rate': 0.022,  'type': 'city'},
  'KY_LEXINGTON':       {'name': 'Lexington/Fayette Co',   'rate': 0.025,  'type': 'city'},
  'KY_BOWLING_GREEN':   {'name': 'Bowling Green',          'rate': 0.019,  'type': 'city'},
  'KY_OWENSBORO':       {'name': 'Owensboro',              'rate': 0.015,  'type': 'city'},
  'KY_COVINGTON':       {'name': 'Covington',              'rate': 0.025,  'type': 'city'},
  'KY_FLORENCE':        {'name': 'Florence',               'rate': 0.02,   'type': 'city'},
  'KY_HENDERSON':       {'name': 'Henderson',              'rate': 0.02,   'type': 'city'},
  'KY_HOPKINSVILLE':    {'name': 'Hopkinsville',           'rate': 0.02,   'type': 'city'},
  'KY_RICHMOND':        {'name': 'Richmond',               'rate': 0.02,   'type': 'city'},
  'KY_GEORGETOWN':      {'name': 'Georgetown',             'rate': 0.02,   'type': 'city'},
  'KY_ELIZABETHTOWN':   {'name': 'Elizabethtown',          'rate': 0.02,   'type': 'city'},
  'KY_FRANKFORT':       {'name': 'Frankfort',              'rate': 0.015,  'type': 'city'},
  'KY_PADUCAH':         {'name': 'Paducah',                'rate': 0.02,   'type': 'city'},
  'KY_ASHLAND':         {'name': 'Ashland',                'rate': 0.02,   'type': 'city'},
  'KY_MADISONVILLE':    {'name': 'Madisonville',           'rate': 0.015,  'type': 'city'},
  'KY_MURRAY':          {'name': 'Murray',                 'rate': 0.015,  'type': 'city'},
  'KY_DANVILLE':        {'name': 'Danville',               'rate': 0.018,  'type': 'city'},
  'KY_RADCLIFF':        {'name': 'Radcliff',               'rate': 0.02,   'type': 'city'},
  'KY_ERLANGER':        {'name': 'Erlanger',               'rate': 0.02,   'type': 'city'},
  'KY_INDEPENDENCE':    {'name': 'Independence',           'rate': 0.02,   'type': 'city'},
  // County-level occupational taxes
  'KY_CTY_JEFFERSON':   {'name': 'Jefferson County',       'rate': 0.02,   'type': 'county'},
  'KY_CTY_FAYETTE':     {'name': 'Fayette County',         'rate': 0.025,  'type': 'county'},
  'KY_CTY_KENTON':      {'name': 'Kenton County',          'rate': 0.018,  'type': 'county'},
  'KY_CTY_BOONE':       {'name': 'Boone County',           'rate': 0.008,  'type': 'county'},
  'KY_CTY_CAMPBELL':    {'name': 'Campbell County',        'rate': 0.01,   'type': 'county'},
  'KY_CTY_DAVIESS':     {'name': 'Daviess County',         'rate': 0.01,   'type': 'county'},
  'KY_CTY_WARREN':      {'name': 'Warren County',          'rate': 0.01,   'type': 'county'},
  'KY_CTY_HARDIN':      {'name': 'Hardin County',          'rate': 0.01,   'type': 'county'},
};

// ═══════════════════════════════════════════════════════════════
// ALABAMA — Occupational Tax (cities)
// ═══════════════════════════════════════════════════════════════
// ~500 municipalities. Top metro areas shown.
const Map<String, Map<String, dynamic>> kAlabamaLocalRates = {
  'AL_BIRMINGHAM':      {'name': 'Birmingham',       'rate': 0.01,   'type': 'city'},
  'AL_HUNTSVILLE':      {'name': 'Huntsville',       'rate': 0.01,   'type': 'city'},
  'AL_MONTGOMERY':      {'name': 'Montgomery',       'rate': 0.01,   'type': 'city'},
  'AL_MOBILE':          {'name': 'Mobile',            'rate': 0.01,   'type': 'city'},
  'AL_TUSCALOOSA':      {'name': 'Tuscaloosa',       'rate': 0.01,   'type': 'city'},
  'AL_HOOVER':          {'name': 'Hoover',            'rate': 0.01,   'type': 'city'},
  'AL_DOTHAN':          {'name': 'Dothan',            'rate': 0.01,   'type': 'city'},
  'AL_AUBURN':          {'name': 'Auburn',            'rate': 0.01,   'type': 'city'},
  'AL_DECATUR':         {'name': 'Decatur',           'rate': 0.01,   'type': 'city'},
  'AL_MADISON':         {'name': 'Madison',           'rate': 0.01,   'type': 'city'},
  'AL_FLORENCE':        {'name': 'Florence',          'rate': 0.01,   'type': 'city'},
  'AL_GADSDEN':         {'name': 'Gadsden',           'rate': 0.01,   'type': 'city'},
  'AL_VESTAVIA_HILLS':  {'name': 'Vestavia Hills',   'rate': 0.01,   'type': 'city'},
  'AL_PRATTVILLE':      {'name': 'Prattville',       'rate': 0.01,   'type': 'city'},
  'AL_PHENIX_CITY':     {'name': 'Phenix City',      'rate': 0.01,   'type': 'city'},
  'AL_OPELIKA':         {'name': 'Opelika',           'rate': 0.01,   'type': 'city'},
  'AL_HOMEWOOD':        {'name': 'Homewood',          'rate': 0.01,   'type': 'city'},
  'AL_ENTERPRISE':      {'name': 'Enterprise',       'rate': 0.01,   'type': 'city'},
  'AL_NORTHPORT':       {'name': 'Northport',        'rate': 0.01,   'type': 'city'},
  'AL_ANNISTON':        {'name': 'Anniston',          'rate': 0.01,   'type': 'city'},
  // Jefferson County — county-level tax stacks with city
  'AL_CTY_JEFFERSON':   {'name': 'Jefferson County',  'rate': 0.005,  'type': 'county'},
  'AL_CTY_MADISON':     {'name': 'Madison County',   'rate': 0.005,  'type': 'county'},
  'AL_CTY_MOBILE':      {'name': 'Mobile County',    'rate': 0.005,  'type': 'county'},
};

// ═══════════════════════════════════════════════════════════════
// MISSOURI — City Earnings Tax (only 2 cities)
// ═══════════════════════════════════════════════════════════════
const Map<String, Map<String, dynamic>> kMissouriLocalRates = {
  'MO_STL':             {'name': 'St. Louis',         'rate': 0.01,   'type': 'city'},
  'MO_KC':              {'name': 'Kansas City',       'rate': 0.01,   'type': 'city'},
};

// ═══════════════════════════════════════════════════════════════
// COLORADO — Occupational Privilege Tax (OPT) — flat monthly
// ═══════════════════════════════════════════════════════════════
const Map<String, Map<String, dynamic>> kColoradoLocalRates = {
  'CO_DENVER_OPT':      {'name': 'Denver OPT',       'taxType': 'flat_monthly', 'monthlyAmount': 5.75, 'employerMonthly': 4.00, 'type': 'city'},
  'CO_AURORA_OPT':      {'name': 'Aurora OPT',       'taxType': 'flat_monthly', 'monthlyAmount': 2.00, 'employerMonthly': 2.00, 'type': 'city'},
  'CO_GREENWOOD_V_OPT': {'name': 'Greenwood Village OPT','taxType': 'flat_monthly', 'monthlyAmount': 4.00, 'employerMonthly': 2.00, 'type': 'city'},
  'CO_GLENDALE_OPT':    {'name': 'Glendale OPT',    'taxType': 'flat_monthly', 'monthlyAmount': 10.00,'employerMonthly': 5.00, 'type': 'city'},
  'CO_SHERIDAN_OPT':    {'name': 'Sheridan OPT',     'taxType': 'flat_monthly', 'monthlyAmount': 3.00, 'employerMonthly': 3.00, 'type': 'city'},
};

// ═══════════════════════════════════════════════════════════════
// DELAWARE — Wilmington city wage tax
// ═══════════════════════════════════════════════════════════════
const Map<String, Map<String, dynamic>> kDelawareLocalRates = {
  'DE_WILMINGTON':      {'name': 'Wilmington',       'rate': 0.0125, 'type': 'city'},
};

// ═══════════════════════════════════════════════════════════════
// NEW YORK — NYC graduated + Yonkers surcharge
// ═══════════════════════════════════════════════════════════════
const Map<String, Map<String, dynamic>> kNewYorkLocalRates = {
  // NYC has graduated brackets (calculated from full jurisdiction doc)
  'NY_NYC': {
    'name': 'New York City',
    'type': 'city',
    'taxType': 'graduated',
    'brackets': [
      {'min': 0,      'max': 12000,  'rate': 0.03078},
      {'min': 12000,  'max': 25000,  'rate': 0.03762},
      {'min': 25000,  'max': 50000,  'rate': 0.03819},
      {'min': 50000,  'max': 500000, 'rate': 0.03876},
      {'min': 500000, 'max': null,   'rate': 0.03876}, // top bracket
    ],
  },
  // Yonkers is a surcharge on NY state tax (16.75% of state tax for residents)
  // For non-residents working in Yonkers: 0.5% of wages
  'NY_YONKERS': {
    'name': 'Yonkers',
    'type': 'city',
    'taxType': 'surcharge',
    'residentSurchargeRate': 0.1675, // % of NY state tax
    'nonResidentRate': 0.005,
  },
};

// ═══════════════════════════════════════════════════════════════
// OREGON — Transit taxes (Portland Metro, Lane County)
// ═══════════════════════════════════════════════════════════════
const Map<String, Map<String, dynamic>> kOregonLocalRates = {
  'OR_TRI_MET':         {'name': 'TriMet Transit District',        'rate': 0.007837, 'type': 'transit'},
  'OR_LANE_TRANSIT':    {'name': 'Lane Transit District',          'rate': 0.0077,   'type': 'transit'},
  'OR_STATEWIDE_TRANSIT':{'name': 'Oregon Statewide Transit Tax',  'rate': 0.001,    'type': 'transit'},
  'OR_PORTLAND_METRO':  {'name': 'Portland Metro Supportive Housing','rate': 0.01,   'type': 'metro',
    'note': 'Applies to taxable income over \$200k single / \$400k joint'},
  'OR_PORTLAND_PCFT':   {'name': 'Portland Clean Energy Fund',     'rate': 0.01,     'type': 'city',
    'note': 'Applies to taxable income over \$125k single / \$200k joint'},
  'OR_MULTNOMAH_PFA':   {'name': 'Multnomah Co Preschool For All','rate': 0.015,    'type': 'county',
    'note': 'Applies to taxable income over \$125k single / \$200k joint; 1.5% first bracket, 3% over \$250k/\$400k'},
};

// ═══════════════════════════════════════════════════════════════
// WEST VIRGINIA — Municipal B&O Tax (employer-side, not withheld)
// ═══════════════════════════════════════════════════════════════
const Map<String, Map<String, dynamic>> kWestVirginiaLocalRates = {
  'WV_CHARLESTON':      {'name': 'Charleston',       'rate': 0.02,   'type': 'city', 'note': 'B&O tax on gross receipts, employer-paid'},
  'WV_HUNTINGTON':      {'name': 'Huntington',       'rate': 0.02,   'type': 'city', 'note': 'B&O tax on gross receipts, employer-paid'},
  'WV_PARKERSBURG':     {'name': 'Parkersburg',      'rate': 0.02,   'type': 'city', 'note': 'B&O tax on gross receipts, employer-paid'},
  'WV_WHEELING':        {'name': 'Wheeling',         'rate': 0.02,   'type': 'city', 'note': 'B&O tax on gross receipts, employer-paid'},
  'WV_MORGANTOWN':      {'name': 'Morgantown',       'rate': 0.015,  'type': 'city', 'note': 'B&O tax on gross receipts, employer-paid'},
};

// ═══════════════════════════════════════════════════════════════
// NEW JERSEY — State Payroll Taxes (not local income but mandatory)
// ═══════════════════════════════════════════════════════════════
// NJ doesn't have local income taxes, but employers must withhold
// state-mandated payroll taxes beyond normal income tax.
const Map<String, Map<String, dynamic>> kNewJerseyPayrollTaxes = {
  'NJ_SDI':             {'name': 'NJ State Disability Insurance',  'rate': 0.0,   'employerRate': 0.005, 'type': 'state_payroll',
    'note': 'Employee rate varies by year; employer rate ~0.5% on first \$42,300'},
  'NJ_FLI':             {'name': 'NJ Family Leave Insurance',      'rate': 0.0006,'employerRate': 0.0,   'type': 'state_payroll',
    'note': 'Employee-only contribution on first \$161,400'},
  'NJ_WF':              {'name': 'NJ Workforce Development/UI',    'rate': 0.003825,'employerRate': 0.005,'type': 'state_payroll',
    'note': 'Employee 0.3825% on first \$42,300; employer rate varies by experience'},
};
