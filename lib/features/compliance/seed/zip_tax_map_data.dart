// lib/features/compliance/seed/zip_tax_map_data.dart
//
// ZIP code to local tax jurisdiction mappings.
// Each entry maps a 5-digit ZIP to: stateCode, countyName, cityName,
// and a list of applicable local tax jurisdictions.
//
// This file contains representative mappings for major metro areas.
// Full coverage (~15,000 ZIPs) should be generated from Census/HUD data.
//
// For ZIPs not in this map, the system falls back to the employee's
// manually-entered workCity + workState for local tax lookup.

const Map<String, Map<String, dynamic>> kZipTaxMap = {
  // ═══════════════════ OHIO ═══════════════════
  // Columbus
  '43215': {'stateCode': 'OH', 'countyName': 'Franklin', 'cityName': 'Columbus', 'jurisdictions': [{'jurisdictionId': 'OH_COLUMBUS', 'name': 'Columbus', 'type': 'city', 'rate': 0.025}]},
  '43201': {'stateCode': 'OH', 'countyName': 'Franklin', 'cityName': 'Columbus', 'jurisdictions': [{'jurisdictionId': 'OH_COLUMBUS', 'name': 'Columbus', 'type': 'city', 'rate': 0.025}]},
  '43202': {'stateCode': 'OH', 'countyName': 'Franklin', 'cityName': 'Columbus', 'jurisdictions': [{'jurisdictionId': 'OH_COLUMBUS', 'name': 'Columbus', 'type': 'city', 'rate': 0.025}]},
  '43204': {'stateCode': 'OH', 'countyName': 'Franklin', 'cityName': 'Columbus', 'jurisdictions': [{'jurisdictionId': 'OH_COLUMBUS', 'name': 'Columbus', 'type': 'city', 'rate': 0.025}]},
  '43206': {'stateCode': 'OH', 'countyName': 'Franklin', 'cityName': 'Columbus', 'jurisdictions': [{'jurisdictionId': 'OH_COLUMBUS', 'name': 'Columbus', 'type': 'city', 'rate': 0.025}]},
  '43210': {'stateCode': 'OH', 'countyName': 'Franklin', 'cityName': 'Columbus', 'jurisdictions': [{'jurisdictionId': 'OH_COLUMBUS', 'name': 'Columbus', 'type': 'city', 'rate': 0.025}]},
  // Cleveland
  '44101': {'stateCode': 'OH', 'countyName': 'Cuyahoga', 'cityName': 'Cleveland', 'jurisdictions': [{'jurisdictionId': 'OH_CLEVELAND', 'name': 'Cleveland', 'type': 'city', 'rate': 0.025}]},
  '44102': {'stateCode': 'OH', 'countyName': 'Cuyahoga', 'cityName': 'Cleveland', 'jurisdictions': [{'jurisdictionId': 'OH_CLEVELAND', 'name': 'Cleveland', 'type': 'city', 'rate': 0.025}]},
  '44103': {'stateCode': 'OH', 'countyName': 'Cuyahoga', 'cityName': 'Cleveland', 'jurisdictions': [{'jurisdictionId': 'OH_CLEVELAND', 'name': 'Cleveland', 'type': 'city', 'rate': 0.025}]},
  '44104': {'stateCode': 'OH', 'countyName': 'Cuyahoga', 'cityName': 'Cleveland', 'jurisdictions': [{'jurisdictionId': 'OH_CLEVELAND', 'name': 'Cleveland', 'type': 'city', 'rate': 0.025}]},
  '44113': {'stateCode': 'OH', 'countyName': 'Cuyahoga', 'cityName': 'Cleveland', 'jurisdictions': [{'jurisdictionId': 'OH_CLEVELAND', 'name': 'Cleveland', 'type': 'city', 'rate': 0.025}]},
  '44114': {'stateCode': 'OH', 'countyName': 'Cuyahoga', 'cityName': 'Cleveland', 'jurisdictions': [{'jurisdictionId': 'OH_CLEVELAND', 'name': 'Cleveland', 'type': 'city', 'rate': 0.025}]},
  // Cincinnati
  '45201': {'stateCode': 'OH', 'countyName': 'Hamilton', 'cityName': 'Cincinnati', 'jurisdictions': [{'jurisdictionId': 'OH_CINCINNATI', 'name': 'Cincinnati', 'type': 'city', 'rate': 0.018}]},
  '45202': {'stateCode': 'OH', 'countyName': 'Hamilton', 'cityName': 'Cincinnati', 'jurisdictions': [{'jurisdictionId': 'OH_CINCINNATI', 'name': 'Cincinnati', 'type': 'city', 'rate': 0.018}]},
  '45203': {'stateCode': 'OH', 'countyName': 'Hamilton', 'cityName': 'Cincinnati', 'jurisdictions': [{'jurisdictionId': 'OH_CINCINNATI', 'name': 'Cincinnati', 'type': 'city', 'rate': 0.018}]},
  // Toledo
  '43601': {'stateCode': 'OH', 'countyName': 'Lucas', 'cityName': 'Toledo', 'jurisdictions': [{'jurisdictionId': 'OH_TOLEDO', 'name': 'Toledo', 'type': 'city', 'rate': 0.025}]},
  '43604': {'stateCode': 'OH', 'countyName': 'Lucas', 'cityName': 'Toledo', 'jurisdictions': [{'jurisdictionId': 'OH_TOLEDO', 'name': 'Toledo', 'type': 'city', 'rate': 0.025}]},
  // Akron
  '44301': {'stateCode': 'OH', 'countyName': 'Summit', 'cityName': 'Akron', 'jurisdictions': [{'jurisdictionId': 'OH_AKRON', 'name': 'Akron', 'type': 'city', 'rate': 0.025}]},
  '44302': {'stateCode': 'OH', 'countyName': 'Summit', 'cityName': 'Akron', 'jurisdictions': [{'jurisdictionId': 'OH_AKRON', 'name': 'Akron', 'type': 'city', 'rate': 0.025}]},
  '44304': {'stateCode': 'OH', 'countyName': 'Summit', 'cityName': 'Akron', 'jurisdictions': [{'jurisdictionId': 'OH_AKRON', 'name': 'Akron', 'type': 'city', 'rate': 0.025}]},
  // Dayton
  '45401': {'stateCode': 'OH', 'countyName': 'Montgomery', 'cityName': 'Dayton', 'jurisdictions': [{'jurisdictionId': 'OH_DAYTON', 'name': 'Dayton', 'type': 'city', 'rate': 0.025}]},
  '45402': {'stateCode': 'OH', 'countyName': 'Montgomery', 'cityName': 'Dayton', 'jurisdictions': [{'jurisdictionId': 'OH_DAYTON', 'name': 'Dayton', 'type': 'city', 'rate': 0.025}]},
  // Youngstown
  '44501': {'stateCode': 'OH', 'countyName': 'Mahoning', 'cityName': 'Youngstown', 'jurisdictions': [{'jurisdictionId': 'OH_YOUNGSTOWN', 'name': 'Youngstown', 'type': 'city', 'rate': 0.025}]},
  '44502': {'stateCode': 'OH', 'countyName': 'Mahoning', 'cityName': 'Youngstown', 'jurisdictions': [{'jurisdictionId': 'OH_YOUNGSTOWN', 'name': 'Youngstown', 'type': 'city', 'rate': 0.025}]},

  // ═══════════════════ PENNSYLVANIA ═══════════════════
  // Philadelphia
  '19101': {'stateCode': 'PA', 'countyName': 'Philadelphia', 'cityName': 'Philadelphia', 'jurisdictions': [{'jurisdictionId': 'PA_PHL', 'name': 'Philadelphia', 'type': 'eit', 'municipalRate': 0.034415, 'schoolDistrictRate': 0.0, 'totalRate': 0.034415}]},
  '19102': {'stateCode': 'PA', 'countyName': 'Philadelphia', 'cityName': 'Philadelphia', 'jurisdictions': [{'jurisdictionId': 'PA_PHL', 'name': 'Philadelphia', 'type': 'eit', 'municipalRate': 0.034415, 'schoolDistrictRate': 0.0, 'totalRate': 0.034415}]},
  '19103': {'stateCode': 'PA', 'countyName': 'Philadelphia', 'cityName': 'Philadelphia', 'jurisdictions': [{'jurisdictionId': 'PA_PHL', 'name': 'Philadelphia', 'type': 'eit', 'municipalRate': 0.034415, 'schoolDistrictRate': 0.0, 'totalRate': 0.034415}]},
  '19104': {'stateCode': 'PA', 'countyName': 'Philadelphia', 'cityName': 'Philadelphia', 'jurisdictions': [{'jurisdictionId': 'PA_PHL', 'name': 'Philadelphia', 'type': 'eit', 'municipalRate': 0.034415, 'schoolDistrictRate': 0.0, 'totalRate': 0.034415}]},
  // Pittsburgh
  '15201': {'stateCode': 'PA', 'countyName': 'Allegheny', 'cityName': 'Pittsburgh', 'jurisdictions': [{'jurisdictionId': 'PA_PITTSBURGH', 'name': 'Pittsburgh', 'type': 'eit', 'municipalRate': 0.01, 'schoolDistrictRate': 0.02, 'totalRate': 0.03}]},
  '15213': {'stateCode': 'PA', 'countyName': 'Allegheny', 'cityName': 'Pittsburgh', 'jurisdictions': [{'jurisdictionId': 'PA_PITTSBURGH', 'name': 'Pittsburgh', 'type': 'eit', 'municipalRate': 0.01, 'schoolDistrictRate': 0.02, 'totalRate': 0.03}]},
  '15222': {'stateCode': 'PA', 'countyName': 'Allegheny', 'cityName': 'Pittsburgh', 'jurisdictions': [{'jurisdictionId': 'PA_PITTSBURGH', 'name': 'Pittsburgh', 'type': 'eit', 'municipalRate': 0.01, 'schoolDistrictRate': 0.02, 'totalRate': 0.03}]},
  // Harrisburg
  '17101': {'stateCode': 'PA', 'countyName': 'Dauphin', 'cityName': 'Harrisburg', 'jurisdictions': [{'jurisdictionId': 'PA_HARRISBURG', 'name': 'Harrisburg', 'type': 'eit', 'municipalRate': 0.015, 'schoolDistrictRate': 0.005, 'totalRate': 0.02}]},

  // ═══════════════════ INDIANA ═══════════════════
  // Indianapolis (Marion County)
  '46201': {'stateCode': 'IN', 'countyName': 'Marion', 'cityName': 'Indianapolis', 'jurisdictions': [{'jurisdictionId': 'IN_CTY_MARION', 'name': 'Marion County', 'type': 'county', 'rate': 0.0202}]},
  '46202': {'stateCode': 'IN', 'countyName': 'Marion', 'cityName': 'Indianapolis', 'jurisdictions': [{'jurisdictionId': 'IN_CTY_MARION', 'name': 'Marion County', 'type': 'county', 'rate': 0.0202}]},
  '46204': {'stateCode': 'IN', 'countyName': 'Marion', 'cityName': 'Indianapolis', 'jurisdictions': [{'jurisdictionId': 'IN_CTY_MARION', 'name': 'Marion County', 'type': 'county', 'rate': 0.0202}]},
  // Fort Wayne (Allen County)
  '46801': {'stateCode': 'IN', 'countyName': 'Allen', 'cityName': 'Fort Wayne', 'jurisdictions': [{'jurisdictionId': 'IN_CTY_ALLEN', 'name': 'Allen County', 'type': 'county', 'rate': 0.0148}]},
  '46802': {'stateCode': 'IN', 'countyName': 'Allen', 'cityName': 'Fort Wayne', 'jurisdictions': [{'jurisdictionId': 'IN_CTY_ALLEN', 'name': 'Allen County', 'type': 'county', 'rate': 0.0148}]},
  // South Bend (St. Joseph County)
  '46601': {'stateCode': 'IN', 'countyName': 'St. Joseph', 'cityName': 'South Bend', 'jurisdictions': [{'jurisdictionId': 'IN_CTY_ST_JOSEPH', 'name': 'St. Joseph County', 'type': 'county', 'rate': 0.0175}]},

  // ═══════════════════ MARYLAND ═══════════════════
  // Baltimore City
  '21201': {'stateCode': 'MD', 'countyName': 'Baltimore City', 'cityName': 'Baltimore', 'jurisdictions': [{'jurisdictionId': 'MD_CTY_BALTIMORE_CITY', 'name': 'Baltimore City', 'type': 'county', 'rate': 0.032}]},
  '21202': {'stateCode': 'MD', 'countyName': 'Baltimore City', 'cityName': 'Baltimore', 'jurisdictions': [{'jurisdictionId': 'MD_CTY_BALTIMORE_CITY', 'name': 'Baltimore City', 'type': 'county', 'rate': 0.032}]},
  // Montgomery County
  '20814': {'stateCode': 'MD', 'countyName': 'Montgomery', 'cityName': 'Bethesda', 'jurisdictions': [{'jurisdictionId': 'MD_CTY_MONTGOMERY', 'name': 'Montgomery County', 'type': 'county', 'rate': 0.032}]},
  '20850': {'stateCode': 'MD', 'countyName': 'Montgomery', 'cityName': 'Rockville', 'jurisdictions': [{'jurisdictionId': 'MD_CTY_MONTGOMERY', 'name': 'Montgomery County', 'type': 'county', 'rate': 0.032}]},
  // Prince George's County
  '20770': {'stateCode': 'MD', 'countyName': "Prince George's", 'cityName': 'Greenbelt', 'jurisdictions': [{'jurisdictionId': 'MD_CTY_PG', 'name': "Prince George's County", 'type': 'county', 'rate': 0.032}]},
  // Howard County
  '21044': {'stateCode': 'MD', 'countyName': 'Howard', 'cityName': 'Columbia', 'jurisdictions': [{'jurisdictionId': 'MD_CTY_HOWARD', 'name': 'Howard County', 'type': 'county', 'rate': 0.032}]},

  // ═══════════════════ MICHIGAN ═══════════════════
  // Detroit
  '48201': {'stateCode': 'MI', 'countyName': 'Wayne', 'cityName': 'Detroit', 'jurisdictions': [{'jurisdictionId': 'MI_DETROIT', 'name': 'Detroit', 'type': 'city', 'rate': 0.024}]},
  '48202': {'stateCode': 'MI', 'countyName': 'Wayne', 'cityName': 'Detroit', 'jurisdictions': [{'jurisdictionId': 'MI_DETROIT', 'name': 'Detroit', 'type': 'city', 'rate': 0.024}]},
  '48226': {'stateCode': 'MI', 'countyName': 'Wayne', 'cityName': 'Detroit', 'jurisdictions': [{'jurisdictionId': 'MI_DETROIT', 'name': 'Detroit', 'type': 'city', 'rate': 0.024}]},
  // Grand Rapids
  '49503': {'stateCode': 'MI', 'countyName': 'Kent', 'cityName': 'Grand Rapids', 'jurisdictions': [{'jurisdictionId': 'MI_GRAND_RAPIDS', 'name': 'Grand Rapids', 'type': 'city', 'rate': 0.015}]},
  // Ann Arbor
  '48104': {'stateCode': 'MI', 'countyName': 'Washtenaw', 'cityName': 'Ann Arbor', 'jurisdictions': [{'jurisdictionId': 'MI_ANN_ARBOR', 'name': 'Ann Arbor', 'type': 'city', 'rate': 0.01}]},

  // ═══════════════════ NEW YORK ═══════════════════
  // NYC — all 5 boroughs
  '10001': {'stateCode': 'NY', 'countyName': 'New York', 'cityName': 'New York', 'jurisdictions': [{'jurisdictionId': 'NY_NYC', 'name': 'New York City', 'type': 'city', 'taxType': 'graduated'}]},
  '10002': {'stateCode': 'NY', 'countyName': 'New York', 'cityName': 'New York', 'jurisdictions': [{'jurisdictionId': 'NY_NYC', 'name': 'New York City', 'type': 'city', 'taxType': 'graduated'}]},
  '10003': {'stateCode': 'NY', 'countyName': 'New York', 'cityName': 'New York', 'jurisdictions': [{'jurisdictionId': 'NY_NYC', 'name': 'New York City', 'type': 'city', 'taxType': 'graduated'}]},
  '10004': {'stateCode': 'NY', 'countyName': 'New York', 'cityName': 'New York', 'jurisdictions': [{'jurisdictionId': 'NY_NYC', 'name': 'New York City', 'type': 'city', 'taxType': 'graduated'}]},
  '10005': {'stateCode': 'NY', 'countyName': 'New York', 'cityName': 'New York', 'jurisdictions': [{'jurisdictionId': 'NY_NYC', 'name': 'New York City', 'type': 'city', 'taxType': 'graduated'}]},
  '10006': {'stateCode': 'NY', 'countyName': 'New York', 'cityName': 'New York', 'jurisdictions': [{'jurisdictionId': 'NY_NYC', 'name': 'New York City', 'type': 'city', 'taxType': 'graduated'}]},
  '10007': {'stateCode': 'NY', 'countyName': 'New York', 'cityName': 'New York', 'jurisdictions': [{'jurisdictionId': 'NY_NYC', 'name': 'New York City', 'type': 'city', 'taxType': 'graduated'}]},
  '10010': {'stateCode': 'NY', 'countyName': 'New York', 'cityName': 'New York', 'jurisdictions': [{'jurisdictionId': 'NY_NYC', 'name': 'New York City', 'type': 'city', 'taxType': 'graduated'}]},
  '10011': {'stateCode': 'NY', 'countyName': 'New York', 'cityName': 'New York', 'jurisdictions': [{'jurisdictionId': 'NY_NYC', 'name': 'New York City', 'type': 'city', 'taxType': 'graduated'}]},
  '10012': {'stateCode': 'NY', 'countyName': 'New York', 'cityName': 'New York', 'jurisdictions': [{'jurisdictionId': 'NY_NYC', 'name': 'New York City', 'type': 'city', 'taxType': 'graduated'}]},
  '10016': {'stateCode': 'NY', 'countyName': 'New York', 'cityName': 'New York', 'jurisdictions': [{'jurisdictionId': 'NY_NYC', 'name': 'New York City', 'type': 'city', 'taxType': 'graduated'}]},
  '10017': {'stateCode': 'NY', 'countyName': 'New York', 'cityName': 'New York', 'jurisdictions': [{'jurisdictionId': 'NY_NYC', 'name': 'New York City', 'type': 'city', 'taxType': 'graduated'}]},
  '10019': {'stateCode': 'NY', 'countyName': 'New York', 'cityName': 'New York', 'jurisdictions': [{'jurisdictionId': 'NY_NYC', 'name': 'New York City', 'type': 'city', 'taxType': 'graduated'}]},
  '10022': {'stateCode': 'NY', 'countyName': 'New York', 'cityName': 'New York', 'jurisdictions': [{'jurisdictionId': 'NY_NYC', 'name': 'New York City', 'type': 'city', 'taxType': 'graduated'}]},
  '10036': {'stateCode': 'NY', 'countyName': 'New York', 'cityName': 'New York', 'jurisdictions': [{'jurisdictionId': 'NY_NYC', 'name': 'New York City', 'type': 'city', 'taxType': 'graduated'}]},
  // Brooklyn
  '11201': {'stateCode': 'NY', 'countyName': 'Kings', 'cityName': 'Brooklyn', 'jurisdictions': [{'jurisdictionId': 'NY_NYC', 'name': 'New York City', 'type': 'city', 'taxType': 'graduated'}]},
  '11211': {'stateCode': 'NY', 'countyName': 'Kings', 'cityName': 'Brooklyn', 'jurisdictions': [{'jurisdictionId': 'NY_NYC', 'name': 'New York City', 'type': 'city', 'taxType': 'graduated'}]},
  // Bronx
  '10451': {'stateCode': 'NY', 'countyName': 'Bronx', 'cityName': 'Bronx', 'jurisdictions': [{'jurisdictionId': 'NY_NYC', 'name': 'New York City', 'type': 'city', 'taxType': 'graduated'}]},
  // Queens
  '11101': {'stateCode': 'NY', 'countyName': 'Queens', 'cityName': 'Long Island City', 'jurisdictions': [{'jurisdictionId': 'NY_NYC', 'name': 'New York City', 'type': 'city', 'taxType': 'graduated'}]},
  // Yonkers
  '10701': {'stateCode': 'NY', 'countyName': 'Westchester', 'cityName': 'Yonkers', 'jurisdictions': [{'jurisdictionId': 'NY_YONKERS', 'name': 'Yonkers', 'type': 'city', 'rate': 0.01959375}]},
  '10702': {'stateCode': 'NY', 'countyName': 'Westchester', 'cityName': 'Yonkers', 'jurisdictions': [{'jurisdictionId': 'NY_YONKERS', 'name': 'Yonkers', 'type': 'city', 'rate': 0.01959375}]},

  // ═══════════════════ KENTUCKY ═══════════════════
  '40201': {'stateCode': 'KY', 'countyName': 'Jefferson', 'cityName': 'Louisville', 'jurisdictions': [{'jurisdictionId': 'KY_LOUISVILLE', 'name': 'Louisville', 'type': 'city', 'rate': 0.022}]},
  '40202': {'stateCode': 'KY', 'countyName': 'Jefferson', 'cityName': 'Louisville', 'jurisdictions': [{'jurisdictionId': 'KY_LOUISVILLE', 'name': 'Louisville', 'type': 'city', 'rate': 0.022}]},
  '40503': {'stateCode': 'KY', 'countyName': 'Fayette', 'cityName': 'Lexington', 'jurisdictions': [{'jurisdictionId': 'KY_LEXINGTON', 'name': 'Lexington', 'type': 'city', 'rate': 0.025}]},
  '40507': {'stateCode': 'KY', 'countyName': 'Fayette', 'cityName': 'Lexington', 'jurisdictions': [{'jurisdictionId': 'KY_LEXINGTON', 'name': 'Lexington', 'type': 'city', 'rate': 0.025}]},

  // ═══════════════════ MISSOURI ═══════════════════
  '63101': {'stateCode': 'MO', 'countyName': 'St. Louis City', 'cityName': 'St. Louis', 'jurisdictions': [{'jurisdictionId': 'MO_STL', 'name': 'St. Louis', 'type': 'city', 'rate': 0.01}]},
  '63102': {'stateCode': 'MO', 'countyName': 'St. Louis City', 'cityName': 'St. Louis', 'jurisdictions': [{'jurisdictionId': 'MO_STL', 'name': 'St. Louis', 'type': 'city', 'rate': 0.01}]},
  '64101': {'stateCode': 'MO', 'countyName': 'Jackson', 'cityName': 'Kansas City', 'jurisdictions': [{'jurisdictionId': 'MO_KC', 'name': 'Kansas City', 'type': 'city', 'rate': 0.01}]},
  '64102': {'stateCode': 'MO', 'countyName': 'Jackson', 'cityName': 'Kansas City', 'jurisdictions': [{'jurisdictionId': 'MO_KC', 'name': 'Kansas City', 'type': 'city', 'rate': 0.01}]},

  // ═══════════════════ COLORADO ═══════════════════
  '80201': {'stateCode': 'CO', 'countyName': 'Denver', 'cityName': 'Denver', 'jurisdictions': [{'jurisdictionId': 'CO_DENVER_OPT', 'name': 'Denver OPT', 'type': 'city', 'taxType': 'flat_monthly', 'monthlyAmount': 5.75}]},
  '80202': {'stateCode': 'CO', 'countyName': 'Denver', 'cityName': 'Denver', 'jurisdictions': [{'jurisdictionId': 'CO_DENVER_OPT', 'name': 'Denver OPT', 'type': 'city', 'taxType': 'flat_monthly', 'monthlyAmount': 5.75}]},
  '80203': {'stateCode': 'CO', 'countyName': 'Denver', 'cityName': 'Denver', 'jurisdictions': [{'jurisdictionId': 'CO_DENVER_OPT', 'name': 'Denver OPT', 'type': 'city', 'taxType': 'flat_monthly', 'monthlyAmount': 5.75}]},

  // ═══════════════════ DELAWARE ═══════════════════
  '19801': {'stateCode': 'DE', 'countyName': 'New Castle', 'cityName': 'Wilmington', 'jurisdictions': [{'jurisdictionId': 'DE_WILMINGTON', 'name': 'Wilmington', 'type': 'city', 'rate': 0.0125}]},
  '19802': {'stateCode': 'DE', 'countyName': 'New Castle', 'cityName': 'Wilmington', 'jurisdictions': [{'jurisdictionId': 'DE_WILMINGTON', 'name': 'Wilmington', 'type': 'city', 'rate': 0.0125}]},

  // ═══════════════════ ALABAMA ═══════════════════
  '35201': {'stateCode': 'AL', 'countyName': 'Jefferson', 'cityName': 'Birmingham', 'jurisdictions': [{'jurisdictionId': 'AL_BIRMINGHAM', 'name': 'Birmingham', 'type': 'city', 'rate': 0.01}]},
  '35203': {'stateCode': 'AL', 'countyName': 'Jefferson', 'cityName': 'Birmingham', 'jurisdictions': [{'jurisdictionId': 'AL_BIRMINGHAM', 'name': 'Birmingham', 'type': 'city', 'rate': 0.01}]},
  '35801': {'stateCode': 'AL', 'countyName': 'Madison', 'cityName': 'Huntsville', 'jurisdictions': [{'jurisdictionId': 'AL_HUNTSVILLE', 'name': 'Huntsville', 'type': 'city', 'rate': 0.01}]},
};
