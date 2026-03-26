// lib/features/compliance/seed/state_tax_brackets_data.dart
//
// Graduated state income tax brackets for all states that use them.
// Sources: State tax authority websites, Tax Foundation 2025-2026 data.
// These brackets are for single filers; married brackets are typically 2x.

/// Tax brackets for graduated-rate states missing from the main seed data.
/// Key = state code, Value = list of bracket maps.
const Map<String, List<Map<String, dynamic>>> kStateTaxBrackets = {
  // Alabama — already in main seed
  // Arkansas — already in main seed
  // California — already in main seed

  'CT': [
    {'min': 0, 'max': 10000, 'rate': 0.02},
    {'min': 10000, 'max': 50000, 'rate': 0.045},
    {'min': 50000, 'max': 100000, 'rate': 0.055},
    {'min': 100000, 'max': 200000, 'rate': 0.06},
    {'min': 200000, 'max': 250000, 'rate': 0.065},
    {'min': 250000, 'max': 500000, 'rate': 0.069},
    {'min': 500000, 'max': 999999999, 'rate': 0.0699},
  ],

  'DE': [
    {'min': 0, 'max': 2000, 'rate': 0.0},
    {'min': 2000, 'max': 5000, 'rate': 0.022},
    {'min': 5000, 'max': 10000, 'rate': 0.039},
    {'min': 10000, 'max': 20000, 'rate': 0.048},
    {'min': 20000, 'max': 25000, 'rate': 0.052},
    {'min': 25000, 'max': 60000, 'rate': 0.0555},
    {'min': 60000, 'max': 999999999, 'rate': 0.066},
  ],

  'HI': [
    {'min': 0, 'max': 2400, 'rate': 0.014},
    {'min': 2400, 'max': 4800, 'rate': 0.032},
    {'min': 4800, 'max': 9600, 'rate': 0.055},
    {'min': 9600, 'max': 14400, 'rate': 0.064},
    {'min': 14400, 'max': 19200, 'rate': 0.068},
    {'min': 19200, 'max': 24000, 'rate': 0.072},
    {'min': 24000, 'max': 36000, 'rate': 0.076},
    {'min': 36000, 'max': 48000, 'rate': 0.079},
    {'min': 48000, 'max': 150000, 'rate': 0.0825},
    {'min': 150000, 'max': 175000, 'rate': 0.09},
    {'min': 175000, 'max': 200000, 'rate': 0.10},
    {'min': 200000, 'max': 999999999, 'rate': 0.11},
  ],

  'KS': [
    {'min': 0, 'max': 15000, 'rate': 0.031},
    {'min': 15000, 'max': 30000, 'rate': 0.0525},
    {'min': 30000, 'max': 999999999, 'rate': 0.057},
  ],

  'ME': [
    {'min': 0, 'max': 24500, 'rate': 0.058},
    {'min': 24500, 'max': 58050, 'rate': 0.0675},
    {'min': 58050, 'max': 999999999, 'rate': 0.0715},
  ],

  'MD': [
    {'min': 0, 'max': 1000, 'rate': 0.02},
    {'min': 1000, 'max': 2000, 'rate': 0.03},
    {'min': 2000, 'max': 3000, 'rate': 0.04},
    {'min': 3000, 'max': 100000, 'rate': 0.0475},
    {'min': 100000, 'max': 125000, 'rate': 0.05},
    {'min': 125000, 'max': 150000, 'rate': 0.0525},
    {'min': 150000, 'max': 250000, 'rate': 0.055},
    {'min': 250000, 'max': 999999999, 'rate': 0.0575},
  ],

  'MN': [
    {'min': 0, 'max': 30070, 'rate': 0.0535},
    {'min': 30070, 'max': 98760, 'rate': 0.068},
    {'min': 98760, 'max': 183340, 'rate': 0.0785},
    {'min': 183340, 'max': 999999999, 'rate': 0.0985},
  ],

  'NE': [
    {'min': 0, 'max': 3700, 'rate': 0.0246},
    {'min': 3700, 'max': 22170, 'rate': 0.0351},
    {'min': 22170, 'max': 35730, 'rate': 0.0501},
    {'min': 35730, 'max': 999999999, 'rate': 0.0584},
  ],

  'NJ': [
    {'min': 0, 'max': 20000, 'rate': 0.014},
    {'min': 20000, 'max': 35000, 'rate': 0.0175},
    {'min': 35000, 'max': 40000, 'rate': 0.035},
    {'min': 40000, 'max': 75000, 'rate': 0.05525},
    {'min': 75000, 'max': 500000, 'rate': 0.0637},
    {'min': 500000, 'max': 1000000, 'rate': 0.0897},
    {'min': 1000000, 'max': 999999999, 'rate': 0.1075},
  ],

  'NM': [
    {'min': 0, 'max': 5500, 'rate': 0.017},
    {'min': 5500, 'max': 11000, 'rate': 0.032},
    {'min': 11000, 'max': 16000, 'rate': 0.047},
    {'min': 16000, 'max': 210000, 'rate': 0.049},
    {'min': 210000, 'max': 315000, 'rate': 0.059},
    {'min': 315000, 'max': 999999999, 'rate': 0.059},
  ],

  // New York — already in main seed

  'OH': [
    {'min': 0, 'max': 26050, 'rate': 0.0},
    {'min': 26050, 'max': 100000, 'rate': 0.02765},
    {'min': 100000, 'max': 999999999, 'rate': 0.035},
  ],

  'OR': [
    {'min': 0, 'max': 4050, 'rate': 0.0475},
    {'min': 4050, 'max': 10200, 'rate': 0.0675},
    {'min': 10200, 'max': 125000, 'rate': 0.0875},
    {'min': 125000, 'max': 999999999, 'rate': 0.099},
  ],

  'RI': [
    {'min': 0, 'max': 73450, 'rate': 0.0375},
    {'min': 73450, 'max': 166950, 'rate': 0.0475},
    {'min': 166950, 'max': 999999999, 'rate': 0.0599},
  ],

  'SC': [
    {'min': 0, 'max': 3200, 'rate': 0.0},
    {'min': 3200, 'max': 16040, 'rate': 0.03},
    {'min': 16040, 'max': 999999999, 'rate': 0.064},
  ],

  'VT': [
    {'min': 0, 'max': 45400, 'rate': 0.0335},
    {'min': 45400, 'max': 110050, 'rate': 0.066},
    {'min': 110050, 'max': 229550, 'rate': 0.076},
    {'min': 229550, 'max': 999999999, 'rate': 0.0875},
  ],

  'VA': [
    {'min': 0, 'max': 3000, 'rate': 0.02},
    {'min': 3000, 'max': 5000, 'rate': 0.03},
    {'min': 5000, 'max': 17000, 'rate': 0.05},
    {'min': 17000, 'max': 999999999, 'rate': 0.0575},
  ],

  'WV': [
    {'min': 0, 'max': 10000, 'rate': 0.0236},
    {'min': 10000, 'max': 25000, 'rate': 0.0315},
    {'min': 25000, 'max': 40000, 'rate': 0.0354},
    {'min': 40000, 'max': 60000, 'rate': 0.0472},
    {'min': 60000, 'max': 999999999, 'rate': 0.0512},
  ],

  'WI': [
    {'min': 0, 'max': 14320, 'rate': 0.0354},
    {'min': 14320, 'max': 28640, 'rate': 0.0465},
    {'min': 28640, 'max': 315310, 'rate': 0.053},
    {'min': 315310, 'max': 999999999, 'rate': 0.0765},
  ],

  'DC': [
    {'min': 0, 'max': 10000, 'rate': 0.04},
    {'min': 10000, 'max': 40000, 'rate': 0.06},
    {'min': 40000, 'max': 60000, 'rate': 0.065},
    {'min': 60000, 'max': 250000, 'rate': 0.085},
    {'min': 250000, 'max': 500000, 'rate': 0.0925},
    {'min': 500000, 'max': 1000000, 'rate': 0.0975},
    {'min': 1000000, 'max': 999999999, 'rate': 0.1075},
  ],
};

/// Local income tax rates for major cities.
/// Key = "stateCode_cityCode", e.g., "NY_NYC" or "PA_PHL".
const Map<String, Map<String, dynamic>> kLocalIncomeTaxes = {
  'NY_NYC': {
    'cityName': 'New York City',
    'stateCode': 'NY',
    'taxType': 'graduated',
    'brackets': [
      {'min': 0, 'max': 12000, 'rate': 0.03078},
      {'min': 12000, 'max': 25000, 'rate': 0.03762},
      {'min': 25000, 'max': 50000, 'rate': 0.03819},
      {'min': 50000, 'max': 999999999, 'rate': 0.03876},
    ],
    'description': 'NYC residents are subject to city income tax in addition to state.',
  },

  'PA_PHL': {
    'cityName': 'Philadelphia',
    'stateCode': 'PA',
    'taxType': 'flat',
    'rate': 0.038,
    'nonResidentRate': 0.034415,
    'description': 'Philadelphia Wage Tax applies to all who work in the city.',
  },

  'OH_CLE': {
    'cityName': 'Cleveland',
    'stateCode': 'OH',
    'taxType': 'flat',
    'rate': 0.025,
    'description': 'Cleveland Municipal Income Tax.',
  },

  'OH_COL': {
    'cityName': 'Columbus',
    'stateCode': 'OH',
    'taxType': 'flat',
    'rate': 0.025,
    'description': 'Columbus City Income Tax.',
  },

  'OH_CIN': {
    'cityName': 'Cincinnati',
    'stateCode': 'OH',
    'taxType': 'flat',
    'rate': 0.018,
    'description': 'Cincinnati Earnings Tax.',
  },

  'MI_DET': {
    'cityName': 'Detroit',
    'stateCode': 'MI',
    'taxType': 'flat',
    'rate': 0.024,
    'nonResidentRate': 0.012,
    'description': 'Detroit City Income Tax.',
  },

  'MO_STL': {
    'cityName': 'St. Louis',
    'stateCode': 'MO',
    'taxType': 'flat',
    'rate': 0.01,
    'description': 'St. Louis Earnings Tax.',
  },

  'MO_KC': {
    'cityName': 'Kansas City',
    'stateCode': 'MO',
    'taxType': 'flat',
    'rate': 0.01,
    'description': 'Kansas City Earnings Tax.',
  },

  'IN_COUNTY': {
    'cityName': 'Indiana County Tax (varies)',
    'stateCode': 'IN',
    'taxType': 'flat',
    'rate': 0.015, // Average — actual varies by county (0.5% - 3.38%)
    'description': 'Indiana counties levy their own income tax. Rate varies by county.',
  },

  'KY_LOCAL': {
    'cityName': 'Kentucky Occupational Tax (varies)',
    'stateCode': 'KY',
    'taxType': 'flat',
    'rate': 0.0225, // Average — Louisville is 2.2%, Lexington is 2.5%
    'description': 'Many KY cities levy occupational license taxes on wages.',
  },

  'MD_COUNTY': {
    'cityName': 'Maryland County Tax (varies)',
    'stateCode': 'MD',
    'taxType': 'flat',
    'rate': 0.032, // Average — ranges from 2.25% to 3.20%
    'description': 'All MD counties levy a local income tax piggyback on state tax.',
  },
};
