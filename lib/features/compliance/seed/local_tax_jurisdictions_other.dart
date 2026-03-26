// lib/features/compliance/seed/local_tax_jurisdictions_other.dart
//
// Local tax jurisdictions for all states except Ohio (which has its own file).
// Covers: PA, IN, MD, KY, MI, NY, AL, CO, OR, DE, MO

const Map<String, Map<String, dynamic>> kOtherStateJurisdictions = {
  // ═══════════════════════════════════════════════
  // PENNSYLVANIA — Earned Income Tax (EIT)
  // PA uses PSD codes. Municipality + School District each get a share.
  // Top 50 PA jurisdictions by population.
  // ═══════════════════════════════════════════════
  'PA_PHL': {'jurisdictionId': 'PA_PHL', 'name': 'Philadelphia', 'stateCode': 'PA', 'type': 'eit', 'municipalRate': 0.034415, 'schoolDistrictRate': 0.0, 'totalRate': 0.034415, 'nonResidentMunicipalRate': 0.034415, 'psdCode': '510101'},
  'PA_PITTSBURGH': {'jurisdictionId': 'PA_PITTSBURGH', 'name': 'Pittsburgh', 'stateCode': 'PA', 'type': 'eit', 'municipalRate': 0.01, 'schoolDistrictRate': 0.02, 'totalRate': 0.03, 'psdCode': '020101'},
  'PA_ALLENTOWN': {'jurisdictionId': 'PA_ALLENTOWN', 'name': 'Allentown', 'stateCode': 'PA', 'type': 'eit', 'municipalRate': 0.01275, 'schoolDistrictRate': 0.005, 'totalRate': 0.01775, 'psdCode': '390101'},
  'PA_ERIE': {'jurisdictionId': 'PA_ERIE', 'name': 'Erie', 'stateCode': 'PA', 'type': 'eit', 'municipalRate': 0.0104, 'schoolDistrictRate': 0.005, 'totalRate': 0.0154, 'psdCode': '250201'},
  'PA_READING': {'jurisdictionId': 'PA_READING', 'name': 'Reading', 'stateCode': 'PA', 'type': 'eit', 'municipalRate': 0.0165, 'schoolDistrictRate': 0.005, 'totalRate': 0.0215, 'psdCode': '060101'},
  'PA_SCRANTON': {'jurisdictionId': 'PA_SCRANTON', 'name': 'Scranton', 'stateCode': 'PA', 'type': 'eit', 'municipalRate': 0.0215, 'schoolDistrictRate': 0.005, 'totalRate': 0.0265, 'psdCode': '350301'},
  'PA_BETHLEHEM': {'jurisdictionId': 'PA_BETHLEHEM', 'name': 'Bethlehem', 'stateCode': 'PA', 'type': 'eit', 'municipalRate': 0.01, 'schoolDistrictRate': 0.005, 'totalRate': 0.015, 'psdCode': '480101'},
  'PA_LANCASTER_CITY': {'jurisdictionId': 'PA_LANCASTER_CITY', 'name': 'Lancaster City', 'stateCode': 'PA', 'type': 'eit', 'municipalRate': 0.0133, 'schoolDistrictRate': 0.005, 'totalRate': 0.0183, 'psdCode': '360101'},
  'PA_HARRISBURG': {'jurisdictionId': 'PA_HARRISBURG', 'name': 'Harrisburg', 'stateCode': 'PA', 'type': 'eit', 'municipalRate': 0.015, 'schoolDistrictRate': 0.005, 'totalRate': 0.02, 'psdCode': '220101'},
  'PA_YORK': {'jurisdictionId': 'PA_YORK', 'name': 'York', 'stateCode': 'PA', 'type': 'eit', 'municipalRate': 0.0131, 'schoolDistrictRate': 0.005, 'totalRate': 0.0181, 'psdCode': '670101'},
  'PA_WILKES_BARRE': {'jurisdictionId': 'PA_WILKES_BARRE', 'name': 'Wilkes-Barre', 'stateCode': 'PA', 'type': 'eit', 'municipalRate': 0.015, 'schoolDistrictRate': 0.005, 'totalRate': 0.02, 'psdCode': '400201'},
  // PA default for unlisted municipalities
  'PA_DEFAULT': {'jurisdictionId': 'PA_DEFAULT', 'name': 'PA Default EIT', 'stateCode': 'PA', 'type': 'eit', 'municipalRate': 0.01, 'schoolDistrictRate': 0.005, 'totalRate': 0.015, 'description': 'Default rate for PA municipalities not individually listed. Most PA EIT rates are 1% municipal + 0.5% school district.'},

  // ═══════════════════════════════════════════════
  // INDIANA — All 92 counties levy county income tax
  // ═══════════════════════════════════════════════
  'IN_CTY_ADAMS': {'jurisdictionId': 'IN_CTY_ADAMS', 'name': 'Adams County', 'stateCode': 'IN', 'type': 'county', 'taxType': 'flat', 'rate': 0.0179, 'fipsCode': '18001'},
  'IN_CTY_ALLEN': {'jurisdictionId': 'IN_CTY_ALLEN', 'name': 'Allen County', 'stateCode': 'IN', 'type': 'county', 'taxType': 'flat', 'rate': 0.0148, 'fipsCode': '18003'},
  'IN_CTY_BARTHOLOMEW': {'jurisdictionId': 'IN_CTY_BARTHOLOMEW', 'name': 'Bartholomew County', 'stateCode': 'IN', 'type': 'county', 'taxType': 'flat', 'rate': 0.0175, 'fipsCode': '18005'},
  'IN_CTY_DELAWARE': {'jurisdictionId': 'IN_CTY_DELAWARE', 'name': 'Delaware County', 'stateCode': 'IN', 'type': 'county', 'taxType': 'flat', 'rate': 0.015, 'fipsCode': '18035'},
  'IN_CTY_ELKHART': {'jurisdictionId': 'IN_CTY_ELKHART', 'name': 'Elkhart County', 'stateCode': 'IN', 'type': 'county', 'taxType': 'flat', 'rate': 0.02, 'fipsCode': '18039'},
  'IN_CTY_HAMILTON': {'jurisdictionId': 'IN_CTY_HAMILTON', 'name': 'Hamilton County', 'stateCode': 'IN', 'type': 'county', 'taxType': 'flat', 'rate': 0.01, 'fipsCode': '18057'},
  'IN_CTY_HENDRICKS': {'jurisdictionId': 'IN_CTY_HENDRICKS', 'name': 'Hendricks County', 'stateCode': 'IN', 'type': 'county', 'taxType': 'flat', 'rate': 0.015, 'fipsCode': '18063'},
  'IN_CTY_JOHNSON': {'jurisdictionId': 'IN_CTY_JOHNSON', 'name': 'Johnson County', 'stateCode': 'IN', 'type': 'county', 'taxType': 'flat', 'rate': 0.01, 'fipsCode': '18081'},
  'IN_CTY_LAKE': {'jurisdictionId': 'IN_CTY_LAKE', 'name': 'Lake County', 'stateCode': 'IN', 'type': 'county', 'taxType': 'flat', 'rate': 0.015, 'fipsCode': '18089'},
  'IN_CTY_MADISON': {'jurisdictionId': 'IN_CTY_MADISON', 'name': 'Madison County', 'stateCode': 'IN', 'type': 'county', 'taxType': 'flat', 'rate': 0.0175, 'fipsCode': '18095'},
  'IN_CTY_MARION': {'jurisdictionId': 'IN_CTY_MARION', 'name': 'Marion County (Indianapolis)', 'stateCode': 'IN', 'type': 'county', 'taxType': 'flat', 'rate': 0.0202, 'fipsCode': '18097'},
  'IN_CTY_MONROE': {'jurisdictionId': 'IN_CTY_MONROE', 'name': 'Monroe County', 'stateCode': 'IN', 'type': 'county', 'taxType': 'flat', 'rate': 0.01345, 'fipsCode': '18105'},
  'IN_CTY_ST_JOSEPH': {'jurisdictionId': 'IN_CTY_ST_JOSEPH', 'name': 'St. Joseph County', 'stateCode': 'IN', 'type': 'county', 'taxType': 'flat', 'rate': 0.0175, 'fipsCode': '18141'},
  'IN_CTY_TIPPECANOE': {'jurisdictionId': 'IN_CTY_TIPPECANOE', 'name': 'Tippecanoe County', 'stateCode': 'IN', 'type': 'county', 'taxType': 'flat', 'rate': 0.012, 'fipsCode': '18157'},
  'IN_CTY_VANDERBURGH': {'jurisdictionId': 'IN_CTY_VANDERBURGH', 'name': 'Vanderburgh County (Evansville)', 'stateCode': 'IN', 'type': 'county', 'taxType': 'flat', 'rate': 0.0122, 'fipsCode': '18163'},
  'IN_CTY_VIGO': {'jurisdictionId': 'IN_CTY_VIGO', 'name': 'Vigo County (Terre Haute)', 'stateCode': 'IN', 'type': 'county', 'taxType': 'flat', 'rate': 0.0145, 'fipsCode': '18167'},

  // ═══════════════════════════════════════════════
  // MARYLAND — All 23 counties + Baltimore City
  // ═══════════════════════════════════════════════
  'MD_CTY_ALLEGANY': {'jurisdictionId': 'MD_CTY_ALLEGANY', 'name': 'Allegany County', 'stateCode': 'MD', 'type': 'county', 'taxType': 'flat', 'rate': 0.0305},
  'MD_CTY_ANNE_ARUNDEL': {'jurisdictionId': 'MD_CTY_ANNE_ARUNDEL', 'name': 'Anne Arundel County', 'stateCode': 'MD', 'type': 'county', 'taxType': 'flat', 'rate': 0.0281},
  'MD_CTY_BALTIMORE_CITY': {'jurisdictionId': 'MD_CTY_BALTIMORE_CITY', 'name': 'Baltimore City', 'stateCode': 'MD', 'type': 'county', 'taxType': 'flat', 'rate': 0.032},
  'MD_CTY_BALTIMORE': {'jurisdictionId': 'MD_CTY_BALTIMORE', 'name': 'Baltimore County', 'stateCode': 'MD', 'type': 'county', 'taxType': 'flat', 'rate': 0.032},
  'MD_CTY_CALVERT': {'jurisdictionId': 'MD_CTY_CALVERT', 'name': 'Calvert County', 'stateCode': 'MD', 'type': 'county', 'taxType': 'flat', 'rate': 0.030},
  'MD_CTY_CARROLL': {'jurisdictionId': 'MD_CTY_CARROLL', 'name': 'Carroll County', 'stateCode': 'MD', 'type': 'county', 'taxType': 'flat', 'rate': 0.0305},
  'MD_CTY_CECIL': {'jurisdictionId': 'MD_CTY_CECIL', 'name': 'Cecil County', 'stateCode': 'MD', 'type': 'county', 'taxType': 'flat', 'rate': 0.03},
  'MD_CTY_CHARLES': {'jurisdictionId': 'MD_CTY_CHARLES', 'name': 'Charles County', 'stateCode': 'MD', 'type': 'county', 'taxType': 'flat', 'rate': 0.0303},
  'MD_CTY_DORCHESTER': {'jurisdictionId': 'MD_CTY_DORCHESTER', 'name': 'Dorchester County', 'stateCode': 'MD', 'type': 'county', 'taxType': 'flat', 'rate': 0.0262},
  'MD_CTY_FREDERICK': {'jurisdictionId': 'MD_CTY_FREDERICK', 'name': 'Frederick County', 'stateCode': 'MD', 'type': 'county', 'taxType': 'flat', 'rate': 0.0296},
  'MD_CTY_HARFORD': {'jurisdictionId': 'MD_CTY_HARFORD', 'name': 'Harford County', 'stateCode': 'MD', 'type': 'county', 'taxType': 'flat', 'rate': 0.0306},
  'MD_CTY_HOWARD': {'jurisdictionId': 'MD_CTY_HOWARD', 'name': 'Howard County', 'stateCode': 'MD', 'type': 'county', 'taxType': 'flat', 'rate': 0.032},
  'MD_CTY_MONTGOMERY': {'jurisdictionId': 'MD_CTY_MONTGOMERY', 'name': 'Montgomery County', 'stateCode': 'MD', 'type': 'county', 'taxType': 'flat', 'rate': 0.032},
  'MD_CTY_PG': {'jurisdictionId': 'MD_CTY_PG', 'name': "Prince George's County", 'stateCode': 'MD', 'type': 'county', 'taxType': 'flat', 'rate': 0.032},
  'MD_CTY_WASHINGTON': {'jurisdictionId': 'MD_CTY_WASHINGTON', 'name': 'Washington County', 'stateCode': 'MD', 'type': 'county', 'taxType': 'flat', 'rate': 0.0295},
  'MD_CTY_WICOMICO': {'jurisdictionId': 'MD_CTY_WICOMICO', 'name': 'Wicomico County', 'stateCode': 'MD', 'type': 'county', 'taxType': 'flat', 'rate': 0.032},
  'MD_CTY_WORCESTER': {'jurisdictionId': 'MD_CTY_WORCESTER', 'name': 'Worcester County', 'stateCode': 'MD', 'type': 'county', 'taxType': 'flat', 'rate': 0.0225},

  // ═══════════════════════════════════════════════
  // MICHIGAN — 24 cities with income tax
  // ═══════════════════════════════════════════════
  'MI_DETROIT': {'jurisdictionId': 'MI_DETROIT', 'name': 'Detroit', 'stateCode': 'MI', 'type': 'city', 'taxType': 'flat', 'rate': 0.024, 'nonResidentRate': 0.012},
  'MI_GRAND_RAPIDS': {'jurisdictionId': 'MI_GRAND_RAPIDS', 'name': 'Grand Rapids', 'stateCode': 'MI', 'type': 'city', 'taxType': 'flat', 'rate': 0.015, 'nonResidentRate': 0.0075},
  'MI_LANSING': {'jurisdictionId': 'MI_LANSING', 'name': 'Lansing', 'stateCode': 'MI', 'type': 'city', 'taxType': 'flat', 'rate': 0.01, 'nonResidentRate': 0.005},
  'MI_FLINT': {'jurisdictionId': 'MI_FLINT', 'name': 'Flint', 'stateCode': 'MI', 'type': 'city', 'taxType': 'flat', 'rate': 0.01, 'nonResidentRate': 0.005},
  'MI_SAGINAW': {'jurisdictionId': 'MI_SAGINAW', 'name': 'Saginaw', 'stateCode': 'MI', 'type': 'city', 'taxType': 'flat', 'rate': 0.015, 'nonResidentRate': 0.0075},
  'MI_KALAMAZOO': {'jurisdictionId': 'MI_KALAMAZOO', 'name': 'Kalamazoo', 'stateCode': 'MI', 'type': 'city', 'taxType': 'flat', 'rate': 0.01, 'nonResidentRate': 0.005},
  'MI_BATTLE_CREEK': {'jurisdictionId': 'MI_BATTLE_CREEK', 'name': 'Battle Creek', 'stateCode': 'MI', 'type': 'city', 'taxType': 'flat', 'rate': 0.01, 'nonResidentRate': 0.005},
  'MI_JACKSON': {'jurisdictionId': 'MI_JACKSON', 'name': 'Jackson', 'stateCode': 'MI', 'type': 'city', 'taxType': 'flat', 'rate': 0.01, 'nonResidentRate': 0.005},
  'MI_MUSKEGON': {'jurisdictionId': 'MI_MUSKEGON', 'name': 'Muskegon', 'stateCode': 'MI', 'type': 'city', 'taxType': 'flat', 'rate': 0.01, 'nonResidentRate': 0.005},
  'MI_PONTIAC': {'jurisdictionId': 'MI_PONTIAC', 'name': 'Pontiac', 'stateCode': 'MI', 'type': 'city', 'taxType': 'flat', 'rate': 0.01, 'nonResidentRate': 0.005},
  'MI_PORT_HURON': {'jurisdictionId': 'MI_PORT_HURON', 'name': 'Port Huron', 'stateCode': 'MI', 'type': 'city', 'taxType': 'flat', 'rate': 0.01, 'nonResidentRate': 0.005},
  'MI_ANN_ARBOR': {'jurisdictionId': 'MI_ANN_ARBOR', 'name': 'Ann Arbor', 'stateCode': 'MI', 'type': 'city', 'taxType': 'flat', 'rate': 0.01, 'nonResidentRate': 0.005},

  // ═══════════════════════════════════════════════
  // NEW YORK — NYC + Yonkers
  // ═══════════════════════════════════════════════
  'NY_NYC': {'jurisdictionId': 'NY_NYC', 'name': 'New York City', 'stateCode': 'NY', 'type': 'city', 'taxType': 'graduated', 'brackets': [
    {'min': 0, 'max': 12000, 'rate': 0.03078},
    {'min': 12000, 'max': 25000, 'rate': 0.03762},
    {'min': 25000, 'max': 50000, 'rate': 0.03819},
    {'min': 50000, 'max': 999999999, 'rate': 0.03876},
  ]},
  'NY_YONKERS': {'jurisdictionId': 'NY_YONKERS', 'name': 'Yonkers', 'stateCode': 'NY', 'type': 'city', 'taxType': 'flat', 'rate': 0.01959375, 'description': 'Yonkers surcharge is 16.75% of state tax liability, approximated as flat rate.'},

  // ═══════════════════════════════════════════════
  // KENTUCKY — Major cities with occupational tax
  // ═══════════════════════════════════════════════
  'KY_LOUISVILLE': {'jurisdictionId': 'KY_LOUISVILLE', 'name': 'Louisville/Jefferson County', 'stateCode': 'KY', 'type': 'city', 'taxType': 'flat', 'rate': 0.022},
  'KY_LEXINGTON': {'jurisdictionId': 'KY_LEXINGTON', 'name': 'Lexington-Fayette', 'stateCode': 'KY', 'type': 'city', 'taxType': 'flat', 'rate': 0.025},
  'KY_COVINGTON': {'jurisdictionId': 'KY_COVINGTON', 'name': 'Covington', 'stateCode': 'KY', 'type': 'city', 'taxType': 'flat', 'rate': 0.025},
  'KY_BOWLING_GREEN': {'jurisdictionId': 'KY_BOWLING_GREEN', 'name': 'Bowling Green', 'stateCode': 'KY', 'type': 'city', 'taxType': 'flat', 'rate': 0.018},
  'KY_OWENSBORO': {'jurisdictionId': 'KY_OWENSBORO', 'name': 'Owensboro', 'stateCode': 'KY', 'type': 'city', 'taxType': 'flat', 'rate': 0.015},
  'KY_FLORENCE': {'jurisdictionId': 'KY_FLORENCE', 'name': 'Florence', 'stateCode': 'KY', 'type': 'city', 'taxType': 'flat', 'rate': 0.02},
  'KY_RICHMOND': {'jurisdictionId': 'KY_RICHMOND', 'name': 'Richmond', 'stateCode': 'KY', 'type': 'city', 'taxType': 'flat', 'rate': 0.02},

  // ═══════════════════════════════════════════════
  // MISSOURI — St. Louis + Kansas City
  // ═══════════════════════════════════════════════
  'MO_STL': {'jurisdictionId': 'MO_STL', 'name': 'St. Louis', 'stateCode': 'MO', 'type': 'city', 'taxType': 'flat', 'rate': 0.01},
  'MO_KC': {'jurisdictionId': 'MO_KC', 'name': 'Kansas City', 'stateCode': 'MO', 'type': 'city', 'taxType': 'flat', 'rate': 0.01},

  // ═══════════════════════════════════════════════
  // COLORADO — Denver OPT (flat monthly tax, not %)
  // ═══════════════════════════════════════════════
  'CO_DENVER_OPT': {'jurisdictionId': 'CO_DENVER_OPT', 'name': 'Denver Occupational Privilege Tax', 'stateCode': 'CO', 'type': 'city', 'taxType': 'flat_monthly', 'monthlyAmount': 5.75, 'employerMonthlyAmount': 4.00, 'description': 'Denver OPT: \$5.75/month employee + \$4.00/month employer for each employee earning \$500+/month.'},
  'CO_AURORA_OPT': {'jurisdictionId': 'CO_AURORA_OPT', 'name': 'Aurora Occupational Privilege Tax', 'stateCode': 'CO', 'type': 'city', 'taxType': 'flat_monthly', 'monthlyAmount': 2.00, 'employerMonthlyAmount': 2.00},
  'CO_GREENWOOD_OPT': {'jurisdictionId': 'CO_GREENWOOD_OPT', 'name': 'Greenwood Village OPT', 'stateCode': 'CO', 'type': 'city', 'taxType': 'flat_monthly', 'monthlyAmount': 4.00, 'employerMonthlyAmount': 2.00},

  // ═══════════════════════════════════════════════
  // OREGON — Portland Metro + Lane County Transit
  // ═══════════════════════════════════════════════
  'OR_PORTLAND_METRO': {'jurisdictionId': 'OR_PORTLAND_METRO', 'name': 'Portland Metro Supportive Housing Tax', 'stateCode': 'OR', 'type': 'transit', 'taxType': 'flat', 'rate': 0.01, 'threshold': 125000, 'description': '1% on taxable income above \$125K (single) / \$200K (joint). Affects higher-paid employees only.'},
  'OR_MULTNOMAH_PFA': {'jurisdictionId': 'OR_MULTNOMAH_PFA', 'name': 'Multnomah County Preschool For All', 'stateCode': 'OR', 'type': 'county', 'taxType': 'graduated', 'brackets': [
    {'min': 125000, 'max': 250000, 'rate': 0.015},
    {'min': 250000, 'max': 999999999, 'rate': 0.03},
  ], 'description': '1.5% on income above \$125K, 3% above \$250K. Applies to Multnomah County residents.'},
  'OR_LANE_TRANSIT': {'jurisdictionId': 'OR_LANE_TRANSIT', 'name': 'Lane Transit District', 'stateCode': 'OR', 'type': 'transit', 'taxType': 'flat', 'rate': 0.0077, 'description': 'Employer-paid transit tax on all wages. Employee pays nothing.'},

  // ═══════════════════════════════════════════════
  // DELAWARE — Wilmington
  // ═══════════════════════════════════════════════
  'DE_WILMINGTON': {'jurisdictionId': 'DE_WILMINGTON', 'name': 'Wilmington', 'stateCode': 'DE', 'type': 'city', 'taxType': 'flat', 'rate': 0.0125},

  // ═══════════════════════════════════════════════
  // ALABAMA — Major cities with occupational tax
  // ═══════════════════════════════════════════════
  'AL_BIRMINGHAM': {'jurisdictionId': 'AL_BIRMINGHAM', 'name': 'Birmingham', 'stateCode': 'AL', 'type': 'city', 'taxType': 'flat', 'rate': 0.01},
  'AL_BESSEMER': {'jurisdictionId': 'AL_BESSEMER', 'name': 'Bessemer', 'stateCode': 'AL', 'type': 'city', 'taxType': 'flat', 'rate': 0.01},
  'AL_GADSDEN': {'jurisdictionId': 'AL_GADSDEN', 'name': 'Gadsden', 'stateCode': 'AL', 'type': 'city', 'taxType': 'flat', 'rate': 0.02},
  'AL_HUNTSVILLE': {'jurisdictionId': 'AL_HUNTSVILLE', 'name': 'Huntsville', 'stateCode': 'AL', 'type': 'city', 'taxType': 'flat', 'rate': 0.01},
  'AL_MACON_COUNTY': {'jurisdictionId': 'AL_MACON_COUNTY', 'name': 'Macon County', 'stateCode': 'AL', 'type': 'county', 'taxType': 'flat', 'rate': 0.005},
};
