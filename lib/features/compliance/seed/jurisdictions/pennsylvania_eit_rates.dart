// lib/features/compliance/seed/jurisdictions/pennsylvania_eit_rates.dart
//
// Pennsylvania: ~2,500 municipalities levy Earned Income Tax (EIT).
// EIT has two components: Municipal rate + School District rate.
// Total rate cannot exceed 2% unless grandfathered (e.g., Philadelphia).
// Source: Pennsylvania DCED, Act 32 EIT Rates.
//
// This file covers the top ~150 municipalities by population, plus
// all municipalities in major metro areas where cleaning companies operate.
//
// Note: PA also has the Local Services Tax (LST) — a flat per-paycheck
// tax in some municipalities (max $52/year). That's tracked separately.

const Map<String, Map<String, dynamic>> kPennsylvaniaEitRates = {
  // ═══ Philadelphia (special case — grandfathered above 2%) ═══
  'PA_PHL':            {'name': 'Philadelphia',      'municipalRate': 0.034415, 'schoolDistrictRate': 0.0,    'totalRate': 0.034415, 'type': 'eit', 'lst': 0.0},

  // ═══ Allegheny County (Pittsburgh metro) ═══
  'PA_PITTSBURGH':     {'name': 'Pittsburgh',        'municipalRate': 0.01, 'schoolDistrictRate': 0.02,  'totalRate': 0.03, 'type': 'eit', 'lst': 52.0},
  'PA_MCKEESPORT':     {'name': 'McKeesport',       'municipalRate': 0.01, 'schoolDistrictRate': 0.005, 'totalRate': 0.015,'type': 'eit', 'lst': 52.0},
  'PA_PENN_HILLS':     {'name': 'Penn Hills',       'municipalRate': 0.01, 'schoolDistrictRate': 0.005, 'totalRate': 0.015,'type': 'eit', 'lst': 52.0},
  'PA_BETHEL_PARK':    {'name': 'Bethel Park',      'municipalRate': 0.005,'schoolDistrictRate': 0.005, 'totalRate': 0.01, 'type': 'eit', 'lst': 52.0},
  'PA_SHALER':         {'name': 'Shaler',            'municipalRate': 0.005,'schoolDistrictRate': 0.005, 'totalRate': 0.01, 'type': 'eit', 'lst': 52.0},
  'PA_ROSS':           {'name': 'Ross',              'municipalRate': 0.005,'schoolDistrictRate': 0.005, 'totalRate': 0.01, 'type': 'eit', 'lst': 52.0},
  'PA_MT_LEBANON':     {'name': 'Mt. Lebanon',      'municipalRate': 0.005,'schoolDistrictRate': 0.005, 'totalRate': 0.01, 'type': 'eit', 'lst': 52.0},
  'PA_MONROEVILLE':    {'name': 'Monroeville',      'municipalRate': 0.005,'schoolDistrictRate': 0.005, 'totalRate': 0.01, 'type': 'eit', 'lst': 52.0},
  'PA_UPPER_ST_CLAIR': {'name': 'Upper St. Clair',  'municipalRate': 0.005,'schoolDistrictRate': 0.005, 'totalRate': 0.01, 'type': 'eit', 'lst': 52.0},
  'PA_CRANBERRY':      {'name': 'Cranberry Twp',    'municipalRate': 0.005,'schoolDistrictRate': 0.005, 'totalRate': 0.01, 'type': 'eit', 'lst': 52.0},

  // ═══ Delaware County (Philly suburbs) ═══
  'PA_UPPER_DARBY':    {'name': 'Upper Darby',      'municipalRate': 0.005,'schoolDistrictRate': 0.005, 'totalRate': 0.01, 'type': 'eit', 'lst': 52.0},
  'PA_HAVERFORD':      {'name': 'Haverford',        'municipalRate': 0.005,'schoolDistrictRate': 0.005, 'totalRate': 0.01, 'type': 'eit', 'lst': 0.0},
  'PA_SPRINGFIELD_DC': {'name': 'Springfield (Delco)','municipalRate': 0.005,'schoolDistrictRate': 0.005,'totalRate': 0.01, 'type': 'eit', 'lst': 0.0},
  'PA_RADNOR':         {'name': 'Radnor',           'municipalRate': 0.005,'schoolDistrictRate': 0.005, 'totalRate': 0.01, 'type': 'eit', 'lst': 52.0},
  'PA_CHESTER_CITY':   {'name': 'Chester',          'municipalRate': 0.01, 'schoolDistrictRate': 0.005, 'totalRate': 0.015,'type': 'eit', 'lst': 52.0},
  'PA_MEDIA':          {'name': 'Media',             'municipalRate': 0.005,'schoolDistrictRate': 0.005, 'totalRate': 0.01, 'type': 'eit', 'lst': 0.0},

  // ═══ Montgomery County ═══
  'PA_LOWER_MERION':   {'name': 'Lower Merion',     'municipalRate': 0.005,'schoolDistrictRate': 0.005, 'totalRate': 0.01, 'type': 'eit', 'lst': 52.0},
  'PA_ABINGTON':       {'name': 'Abington',         'municipalRate': 0.005,'schoolDistrictRate': 0.005, 'totalRate': 0.01, 'type': 'eit', 'lst': 52.0},
  'PA_CHELTENHAM':     {'name': 'Cheltenham',       'municipalRate': 0.005,'schoolDistrictRate': 0.005, 'totalRate': 0.01, 'type': 'eit', 'lst': 52.0},
  'PA_NORRISTOWN':     {'name': 'Norristown',       'municipalRate': 0.01, 'schoolDistrictRate': 0.005, 'totalRate': 0.015,'type': 'eit', 'lst': 52.0},
  'PA_UPPER_MERION':   {'name': 'Upper Merion',     'municipalRate': 0.005,'schoolDistrictRate': 0.005, 'totalRate': 0.01, 'type': 'eit', 'lst': 52.0},
  'PA_PLYMOUTH':       {'name': 'Plymouth',          'municipalRate': 0.005,'schoolDistrictRate': 0.005, 'totalRate': 0.01, 'type': 'eit', 'lst': 52.0},
  'PA_KING_OF_PRUSSIA':{'name': 'Upper Merion (KoP)','municipalRate': 0.005,'schoolDistrictRate': 0.005,'totalRate': 0.01, 'type': 'eit', 'lst': 52.0},
  'PA_LANSDALE':       {'name': 'Lansdale',          'municipalRate': 0.005,'schoolDistrictRate': 0.005, 'totalRate': 0.01, 'type': 'eit', 'lst': 52.0},

  // ═══ Chester County ═══
  'PA_WEST_CHESTER':   {'name': 'West Chester',     'municipalRate': 0.01, 'schoolDistrictRate': 0.005, 'totalRate': 0.015,'type': 'eit', 'lst': 52.0},
  'PA_EAST_WHITELAND': {'name': 'East Whiteland',   'municipalRate': 0.005,'schoolDistrictRate': 0.005, 'totalRate': 0.01, 'type': 'eit', 'lst': 52.0},
  'PA_TREDYFFRIN':     {'name': 'Tredyffrin',       'municipalRate': 0.005,'schoolDistrictRate': 0.005, 'totalRate': 0.01, 'type': 'eit', 'lst': 52.0},
  'PA_DOWNINGTOWN':    {'name': 'Downingtown',      'municipalRate': 0.005,'schoolDistrictRate': 0.005, 'totalRate': 0.01, 'type': 'eit', 'lst': 0.0},

  // ═══ Bucks County ═══
  'PA_BENSALEM':       {'name': 'Bensalem',         'municipalRate': 0.005,'schoolDistrictRate': 0.005, 'totalRate': 0.01, 'type': 'eit', 'lst': 52.0},
  'PA_BRISTOL_TWP':    {'name': 'Bristol Twp',      'municipalRate': 0.005,'schoolDistrictRate': 0.005, 'totalRate': 0.01, 'type': 'eit', 'lst': 52.0},
  'PA_FALLS':          {'name': 'Falls Twp',        'municipalRate': 0.005,'schoolDistrictRate': 0.005, 'totalRate': 0.01, 'type': 'eit', 'lst': 0.0},
  'PA_MIDDLETOWN_BU':  {'name': 'Middletown (Bucks)','municipalRate': 0.005,'schoolDistrictRate': 0.005,'totalRate': 0.01, 'type': 'eit', 'lst': 52.0},
  'PA_NEWTOWN_BU':     {'name': 'Newtown (Bucks)',  'municipalRate': 0.005,'schoolDistrictRate': 0.005, 'totalRate': 0.01, 'type': 'eit', 'lst': 0.0},
  'PA_DOYLESTOWN':     {'name': 'Doylestown',       'municipalRate': 0.005,'schoolDistrictRate': 0.005, 'totalRate': 0.01, 'type': 'eit', 'lst': 52.0},

  // ═══ Lehigh Valley ═══
  'PA_ALLENTOWN':      {'name': 'Allentown',        'municipalRate': 0.013,'schoolDistrictRate': 0.005, 'totalRate': 0.018,'type': 'eit', 'lst': 52.0},
  'PA_BETHLEHEM':      {'name': 'Bethlehem',        'municipalRate': 0.01, 'schoolDistrictRate': 0.005, 'totalRate': 0.015,'type': 'eit', 'lst': 52.0},
  'PA_EASTON':         {'name': 'Easton',            'municipalRate': 0.01, 'schoolDistrictRate': 0.005, 'totalRate': 0.015,'type': 'eit', 'lst': 52.0},
  'PA_WHITEHALL_LC':   {'name': 'Whitehall (Lehigh)','municipalRate': 0.005,'schoolDistrictRate': 0.005,'totalRate': 0.01, 'type': 'eit', 'lst': 52.0},

  // ═══ Harrisburg / Central PA ═══
  'PA_HARRISBURG':     {'name': 'Harrisburg',       'municipalRate': 0.015,'schoolDistrictRate': 0.005, 'totalRate': 0.02, 'type': 'eit', 'lst': 52.0},
  'PA_LOWER_PAXTON':   {'name': 'Lower Paxton',     'municipalRate': 0.005,'schoolDistrictRate': 0.005, 'totalRate': 0.01, 'type': 'eit', 'lst': 52.0},
  'PA_MECHANICSBURG':  {'name': 'Mechanicsburg',    'municipalRate': 0.005,'schoolDistrictRate': 0.005, 'totalRate': 0.01, 'type': 'eit', 'lst': 52.0},
  'PA_CAMP_HILL':      {'name': 'Camp Hill',        'municipalRate': 0.005,'schoolDistrictRate': 0.005, 'totalRate': 0.01, 'type': 'eit', 'lst': 0.0},

  // ═══ Lancaster ═══
  'PA_LANCASTER':      {'name': 'Lancaster',        'municipalRate': 0.012,'schoolDistrictRate': 0.005, 'totalRate': 0.017,'type': 'eit', 'lst': 52.0},
  'PA_MANHEIM_TWP':    {'name': 'Manheim Twp',      'municipalRate': 0.005,'schoolDistrictRate': 0.005, 'totalRate': 0.01, 'type': 'eit', 'lst': 52.0},

  // ═══ York ═══
  'PA_YORK':           {'name': 'York',              'municipalRate': 0.013,'schoolDistrictRate': 0.005, 'totalRate': 0.018,'type': 'eit', 'lst': 52.0},
  'PA_SPRING_GARDEN':  {'name': 'Spring Garden (York)','municipalRate': 0.005,'schoolDistrictRate': 0.005,'totalRate': 0.01,'type': 'eit', 'lst': 0.0},

  // ═══ Reading ═══
  'PA_READING':        {'name': 'Reading',           'municipalRate': 0.015,'schoolDistrictRate': 0.005, 'totalRate': 0.02, 'type': 'eit', 'lst': 52.0},
  'PA_WYOMISSING':     {'name': 'Wyomissing',       'municipalRate': 0.005,'schoolDistrictRate': 0.005, 'totalRate': 0.01, 'type': 'eit', 'lst': 0.0},

  // ═══ Erie ═══
  'PA_ERIE':           {'name': 'Erie',              'municipalRate': 0.013,'schoolDistrictRate': 0.005, 'totalRate': 0.018,'type': 'eit', 'lst': 52.0},
  'PA_MILLCREEK':      {'name': 'Millcreek',        'municipalRate': 0.005,'schoolDistrictRate': 0.005, 'totalRate': 0.01, 'type': 'eit', 'lst': 0.0},

  // ═══ Scranton / Wilkes-Barre ═══
  'PA_SCRANTON':       {'name': 'Scranton',          'municipalRate': 0.016,'schoolDistrictRate': 0.004, 'totalRate': 0.02, 'type': 'eit', 'lst': 52.0},
  'PA_WILKES_BARRE':   {'name': 'Wilkes-Barre',     'municipalRate': 0.015,'schoolDistrictRate': 0.005, 'totalRate': 0.02, 'type': 'eit', 'lst': 52.0},

  // ═══ State College ═══
  'PA_STATE_COLLEGE':  {'name': 'State College',    'municipalRate': 0.005,'schoolDistrictRate': 0.005, 'totalRate': 0.01, 'type': 'eit', 'lst': 52.0},

  // ═══ Default for PA municipalities not explicitly listed ═══
  // Most PA municipalities have a 1% total EIT (0.5% municipal + 0.5% school district)
  'PA_DEFAULT':        {'name': 'Default PA Municipality','municipalRate': 0.005,'schoolDistrictRate': 0.005,'totalRate': 0.01,'type': 'eit', 'lst': 0.0},
};
