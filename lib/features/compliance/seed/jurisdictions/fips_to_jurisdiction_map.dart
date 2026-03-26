// lib/features/compliance/seed/jurisdictions/fips_to_jurisdiction_map.dart
//
// Maps county FIPS codes to local tax jurisdiction IDs.
// Used by the Cloud Function to resolve ZIP → county FIPS → jurisdiction.
//
// FIPS codes are 5-digit: 2-digit state + 3-digit county.
// Only counties/cities WITH local income taxes are mapped here.
// If a FIPS code is not in this map, no local income tax applies for that county.
//
// For states where EVERY county has a tax (Indiana, Maryland), all counties listed.
// For city-based states (Ohio, Michigan, KY), the county maps to a list of
// possible city jurisdictions — the Cloud Function further refines by city name.

const Map<String, List<String>> kFipsToJurisdiction = {
  // ═══ INDIANA — every county has tax (FIPS → single jurisdiction) ═══
  '18001': ['IN_CTY_ADAMS'],
  '18003': ['IN_CTY_ALLEN'],
  '18005': ['IN_CTY_BARTHOLOMEW'],
  '18007': ['IN_CTY_BENTON'],
  '18009': ['IN_CTY_BLACKFORD'],
  '18011': ['IN_CTY_BOONE'],
  '18013': ['IN_CTY_BROWN'],
  '18015': ['IN_CTY_CARROLL'],
  '18017': ['IN_CTY_CASS'],
  '18019': ['IN_CTY_CLARK'],
  '18021': ['IN_CTY_CLAY'],
  '18023': ['IN_CTY_CLINTON'],
  '18025': ['IN_CTY_CRAWFORD'],
  '18027': ['IN_CTY_DAVIESS'],
  '18029': ['IN_CTY_DEARBORN'],
  '18031': ['IN_CTY_DECATUR'],
  '18033': ['IN_CTY_DEKALB'],
  '18035': ['IN_CTY_DELAWARE'],
  '18037': ['IN_CTY_DUBOIS'],
  '18039': ['IN_CTY_ELKHART'],
  '18041': ['IN_CTY_FAYETTE'],
  '18043': ['IN_CTY_FLOYD'],
  '18045': ['IN_CTY_FOUNTAIN'],
  '18047': ['IN_CTY_FRANKLIN'],
  '18049': ['IN_CTY_FULTON'],
  '18051': ['IN_CTY_GIBSON'],
  '18053': ['IN_CTY_GRANT'],
  '18055': ['IN_CTY_GREENE'],
  '18057': ['IN_CTY_HAMILTON'],
  '18059': ['IN_CTY_HANCOCK'],
  '18061': ['IN_CTY_HARRISON'],
  '18063': ['IN_CTY_HENDRICKS'],
  '18065': ['IN_CTY_HENRY'],
  '18067': ['IN_CTY_HOWARD'],
  '18069': ['IN_CTY_HUNTINGTON'],
  '18071': ['IN_CTY_JACKSON'],
  '18073': ['IN_CTY_JASPER'],
  '18075': ['IN_CTY_JAY'],
  '18077': ['IN_CTY_JEFFERSON'],
  '18079': ['IN_CTY_JENNINGS'],
  '18081': ['IN_CTY_JOHNSON'],
  '18083': ['IN_CTY_KNOX'],
  '18085': ['IN_CTY_KOSCIUSKO'],
  '18087': ['IN_CTY_LAGRANGE'],
  '18089': ['IN_CTY_LAKE'],
  '18091': ['IN_CTY_LAPORTE'],
  '18093': ['IN_CTY_LAWRENCE'],
  '18095': ['IN_CTY_MADISON'],
  '18097': ['IN_CTY_MARION'],
  '18099': ['IN_CTY_MARSHALL'],
  '18101': ['IN_CTY_MARTIN'],
  '18103': ['IN_CTY_MIAMI'],
  '18105': ['IN_CTY_MONROE'],
  '18107': ['IN_CTY_MONTGOMERY'],
  '18109': ['IN_CTY_MORGAN'],
  '18111': ['IN_CTY_NEWTON'],
  '18113': ['IN_CTY_NOBLE'],
  '18115': ['IN_CTY_OHIO'],
  '18117': ['IN_CTY_ORANGE'],
  '18119': ['IN_CTY_OWEN'],
  '18121': ['IN_CTY_PARKE'],
  '18123': ['IN_CTY_PERRY'],
  '18125': ['IN_CTY_PIKE'],
  '18127': ['IN_CTY_PORTER'],
  '18129': ['IN_CTY_POSEY'],
  '18131': ['IN_CTY_PULASKI'],
  '18133': ['IN_CTY_PUTNAM'],
  '18135': ['IN_CTY_RANDOLPH'],
  '18137': ['IN_CTY_RIPLEY'],
  '18139': ['IN_CTY_RUSH'],
  '18141': ['IN_CTY_ST_JOSEPH'],
  '18143': ['IN_CTY_SCOTT'],
  '18145': ['IN_CTY_SHELBY'],
  '18147': ['IN_CTY_SPENCER'],
  '18149': ['IN_CTY_STARKE'],
  '18151': ['IN_CTY_STEUBEN'],
  '18153': ['IN_CTY_SULLIVAN'],
  '18155': ['IN_CTY_SWITZERLAND'],
  '18157': ['IN_CTY_TIPPECANOE'],
  '18159': ['IN_CTY_TIPTON'],
  '18161': ['IN_CTY_UNION'],
  '18163': ['IN_CTY_VANDERBURGH'],
  '18165': ['IN_CTY_VERMILLION'],
  '18167': ['IN_CTY_VIGO'],
  '18169': ['IN_CTY_WABASH'],
  '18171': ['IN_CTY_WARREN'],
  '18173': ['IN_CTY_WARRICK'],
  '18175': ['IN_CTY_WASHINGTON'],
  '18177': ['IN_CTY_WAYNE'],
  '18179': ['IN_CTY_WELLS'],
  '18181': ['IN_CTY_WHITE'],
  '18183': ['IN_CTY_WHITLEY'],

  // ═══ MARYLAND — every county has piggyback tax ═══
  '24001': ['MD_CTY_ALLEGANY'],
  '24003': ['MD_CTY_ANNE_ARUNDEL'],
  '24005': ['MD_CTY_BALTIMORE_CO'],
  '24510': ['MD_CTY_BALTIMORE_CITY'],
  '24009': ['MD_CTY_CALVERT'],
  '24011': ['MD_CTY_CAROLINE'],
  '24013': ['MD_CTY_CARROLL'],
  '24015': ['MD_CTY_CECIL'],
  '24017': ['MD_CTY_CHARLES'],
  '24019': ['MD_CTY_DORCHESTER'],
  '24021': ['MD_CTY_FREDERICK'],
  '24023': ['MD_CTY_GARRETT'],
  '24025': ['MD_CTY_HARFORD'],
  '24027': ['MD_CTY_HOWARD'],
  '24029': ['MD_CTY_KENT'],
  '24031': ['MD_CTY_MONTGOMERY'],
  '24033': ['MD_CTY_PG'],
  '24035': ['MD_CTY_QUEEN_ANNES'],
  '24037': ['MD_CTY_ST_MARYS'],
  '24039': ['MD_CTY_SOMERSET'],
  '24041': ['MD_CTY_TALBOT'],
  '24043': ['MD_CTY_WASHINGTON'],
  '24045': ['MD_CTY_WICOMICO'],
  '24047': ['MD_CTY_WORCESTER'],

  // ═══ MICHIGAN — city-level, county FIPS with city candidates ═══
  // Wayne County hosts multiple tax cities
  '26163': ['MI_DETROIT', 'MI_HAMTRAMCK', 'MI_HIGHLAND_PARK'],
  '26081': ['MI_GRAND_RAPIDS', 'MI_WALKER'],        // Kent County
  '26161': ['MI_ANN_ARBOR'],                         // Washtenaw
  '26049': ['MI_FLINT'],                              // Genesee
  '26065': ['MI_JACKSON'],                            // Jackson
  '26077': ['MI_KALAMAZOO'],                          // Kalamazoo
  '26037': ['MI_BATTLE_CREEK'],                       // Calhoun
  '26145': ['MI_SAGINAW'],                            // Saginaw
  '26073': ['MI_IONIA'],                              // Ionia
  '26093': ['MI_LANSING', 'MI_EAST_LANSING'],        // Ingham
  '26125': ['MI_PONTIAC'],                            // Oakland
  '26099': ['MI_MUSKEGON', 'MI_MUSKEGON_HTS'],      // Muskegon
  '26147': ['MI_PORT_HURON'],                         // St. Clair
  '26091': ['MI_LAPEER'],                             // Lapeer
  '26107': ['MI_BIG_RAPIDS'],                         // Mecosta
  '26039': ['MI_GRAYLING'],                           // Crawford
  '26059': ['MI_HUDSON'],                             // Hillsdale
  '26025': ['MI_ALBION'],                             // Calhoun (also)

  // ═══ OHIO — county FIPS with city candidates (top counties only) ═══
  // Franklin County (Columbus metro)
  '39049': ['OH_COLUMBUS', 'OH_DUBLIN', 'OH_GAHANNA', 'OH_GROVE_CITY', 'OH_HILLIARD', 'OH_REYNOLDSBURG', 'OH_UPPER_ARLINGTON', 'OH_WESTERVILLE', 'OH_WHITEHALL', 'OH_WORTHINGTON'],
  // Cuyahoga County (Cleveland metro)
  '39035': ['OH_CLEVELAND', 'OH_CLEVELAND_HTS', 'OH_LAKEWOOD', 'OH_PARMA', 'OH_PARMA_HEIGHTS', 'OH_EUCLID', 'OH_SHAKER_HEIGHTS', 'OH_SOUTH_EUCLID', 'OH_BEACHWOOD', 'OH_BEDFORD', 'OH_BROADVIEW_HTS', 'OH_BROOK_PARK', 'OH_FAIRVIEW_PARK', 'OH_GARFIELD_HTS', 'OH_LYNDHURST', 'OH_MAPLE_HEIGHTS', 'OH_MAYFIELD_HTS', 'OH_MIDDLEBURG_HTS', 'OH_NORTH_OLMSTED', 'OH_NORTH_ROYALTON', 'OH_OLMSTED_FALLS', 'OH_RICHMOND_HTS', 'OH_ROCKY_RIVER', 'OH_SOLON', 'OH_STRONGSVILLE', 'OH_UNIVERSITY_HTS', 'OH_WARRENSVILLE_HTS', 'OH_BAY_VILLAGE', 'OH_BEREA', 'OH_NORTH_RIDGEVILLE'],
  // Hamilton County (Cincinnati metro)
  '39061': ['OH_CINCINNATI', 'OH_NORWOOD', 'OH_SHARONVILLE', 'OH_FAIRFIELD'],
  // Summit County (Akron metro)
  '39153': ['OH_AKRON', 'OH_BARBERTON', 'OH_COPLEY', 'OH_CUYAHOGA_FALLS', 'OH_FAIRLAWN', 'OH_GREEN', 'OH_HUDSON', 'OH_STOW', 'OH_TALLMADGE', 'OH_TWINSBURG'],
  // Montgomery County (Dayton metro)
  '39113': ['OH_DAYTON', 'OH_CENTERVILLE', 'OH_HUBER_HEIGHTS', 'OH_KETTERING', 'OH_MIAMISBURG', 'OH_MORAINE', 'OH_TROTWOOD', 'OH_VANDALIA'],
  // Lucas County (Toledo)
  '39095': ['OH_TOLEDO', 'OH_MAUMEE', 'OH_OREGON', 'OH_SYLVANIA', 'OH_ROSSFORD'],
  // Stark County (Canton)
  '39151': ['OH_CANTON', 'OH_MASSILLON', 'OH_NORTH_CANTON', 'OH_CANAL_FULTON', 'OH_LOUISVILLE', 'OH_ALLIANCE'],
  // Mahoning County (Youngstown)
  '39099': ['OH_YOUNGSTOWN', 'OH_BOARDMAN', 'OH_NILES'],
  // Lorain County
  '39093': ['OH_LORAIN', 'OH_ELYRIA', 'OH_AMHERST', 'OH_AVON', 'OH_AVON_LAKE', 'OH_NORTH_RIDGEVILLE', 'OH_OBERLIN', 'OH_VERMILION'],
  // Lake County
  '39085': ['OH_MENTOR', 'OH_PAINESVILLE', 'OH_WILLOUGHBY'],
  // Butler County
  '39017': ['OH_HAMILTON', 'OH_MIDDLETOWN', 'OH_FAIRFIELD'],
  // Delaware County
  '39041': ['OH_DELAWARE', 'OH_POWELL'],
  // Warren County
  '39165': ['OH_MASON', 'OH_LEBANON', 'OH_SPRINGBORO'],
  // Clark County
  '39023': ['OH_SPRINGFIELD'],
  // Medina County
  '39103': ['OH_MEDINA', 'OH_BRUNSWICK', 'OH_WADSWORTH'],
  // Licking County
  '39089': ['OH_NEWARK', 'OH_PATASKALA'],

  // ═══ KENTUCKY — county FIPS with city/county tax candidates ═══
  '21111': ['KY_LOUISVILLE', 'KY_CTY_JEFFERSON'],   // Jefferson County
  '21067': ['KY_LEXINGTON', 'KY_CTY_FAYETTE'],       // Fayette County
  '21117': ['KY_COVINGTON', 'KY_CTY_KENTON'],        // Kenton County
  '21015': ['KY_FLORENCE', 'KY_CTY_BOONE'],           // Boone County
  '21037': ['KY_CTY_CAMPBELL'],                        // Campbell County
  '21059': ['KY_CTY_DAVIESS', 'KY_OWENSBORO'],       // Daviess County
  '21227': ['KY_BOWLING_GREEN', 'KY_CTY_WARREN'],    // Warren County
  '21093': ['KY_ELIZABETHTOWN', 'KY_CTY_HARDIN'],    // Hardin County

  // ═══ ALABAMA — county FIPS with city candidates ═══
  '01073': ['AL_BIRMINGHAM', 'AL_HOOVER', 'AL_HOMEWOOD', 'AL_VESTAVIA_HILLS', 'AL_CTY_JEFFERSON'],
  '01089': ['AL_HUNTSVILLE', 'AL_MADISON', 'AL_CTY_MADISON'],
  '01101': ['AL_MONTGOMERY', 'AL_PRATTVILLE'],
  '01097': ['AL_MOBILE', 'AL_CTY_MOBILE'],
  '01125': ['AL_TUSCALOOSA', 'AL_NORTHPORT'],

  // ═══ NEW YORK — NYC boroughs + Yonkers ═══
  '36061': ['NY_NYC'],  // New York County (Manhattan)
  '36047': ['NY_NYC'],  // Kings County (Brooklyn)
  '36005': ['NY_NYC'],  // Bronx County
  '36081': ['NY_NYC'],  // Queens County
  '36085': ['NY_NYC'],  // Richmond County (Staten Island)
  '36119': ['NY_YONKERS'], // Westchester County (Yonkers specifically)

  // ═══ COLORADO — Denver metro OPT ═══
  '08031': ['CO_DENVER_OPT'],         // Denver County
  '08005': ['CO_AURORA_OPT'],         // Arapahoe County (Aurora straddles)

  // ═══ DELAWARE — Wilmington ═══
  '10003': ['DE_WILMINGTON'],         // New Castle County

  // ═══ MISSOURI — St. Louis and KC ═══
  '29510': ['MO_STL'],               // St. Louis City (independent)
  '29095': ['MO_KC'],                 // Jackson County (KC)

  // ═══ OREGON — Portland Metro ═══
  '41051': ['OR_TRI_MET', 'OR_PORTLAND_METRO', 'OR_PORTLAND_PCFT', 'OR_MULTNOMAH_PFA', 'OR_STATEWIDE_TRANSIT'], // Multnomah
  '41067': ['OR_TRI_MET', 'OR_STATEWIDE_TRANSIT'],                                                               // Washington County
  '41005': ['OR_TRI_MET', 'OR_STATEWIDE_TRANSIT'],                                                               // Clackamas County
  '41039': ['OR_LANE_TRANSIT', 'OR_STATEWIDE_TRANSIT'],                                                           // Lane County
};
