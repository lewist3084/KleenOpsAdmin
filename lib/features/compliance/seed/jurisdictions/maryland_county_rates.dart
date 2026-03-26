// lib/features/compliance/seed/jurisdictions/maryland_county_rates.dart
//
// Maryland: ALL 23 counties + Baltimore City levy a local "piggyback" income tax.
// Rates are a percentage of Maryland taxable income.
// Source: Comptroller of Maryland, Local Tax Rates.
// Effective 2025/2026 tax year.

const Map<String, Map<String, dynamic>> kMarylandCountyRates = {
  'MD_CTY_ALLEGANY':        {'name': 'Allegany County',        'fips': '24001', 'rate': 0.0305, 'type': 'county'},
  'MD_CTY_ANNE_ARUNDEL':    {'name': 'Anne Arundel County',    'fips': '24003', 'rate': 0.0281, 'type': 'county'},
  'MD_CTY_BALTIMORE_CO':    {'name': 'Baltimore County',       'fips': '24005', 'rate': 0.032,  'type': 'county'},
  'MD_CTY_BALTIMORE_CITY':  {'name': 'Baltimore City',         'fips': '24510', 'rate': 0.032,  'type': 'city'},
  'MD_CTY_CALVERT':         {'name': 'Calvert County',         'fips': '24009', 'rate': 0.03,   'type': 'county'},
  'MD_CTY_CAROLINE':        {'name': 'Caroline County',        'fips': '24011', 'rate': 0.032,  'type': 'county'},
  'MD_CTY_CARROLL':         {'name': 'Carroll County',         'fips': '24013', 'rate': 0.0305, 'type': 'county'},
  'MD_CTY_CECIL':           {'name': 'Cecil County',           'fips': '24015', 'rate': 0.03,   'type': 'county'},
  'MD_CTY_CHARLES':         {'name': 'Charles County',         'fips': '24017', 'rate': 0.0303, 'type': 'county'},
  'MD_CTY_DORCHESTER':      {'name': 'Dorchester County',      'fips': '24019', 'rate': 0.0262, 'type': 'county'},
  'MD_CTY_FREDERICK':       {'name': 'Frederick County',       'fips': '24021', 'rate': 0.0296, 'type': 'county'},
  'MD_CTY_GARRETT':         {'name': 'Garrett County',         'fips': '24023', 'rate': 0.0265, 'type': 'county'},
  'MD_CTY_HARFORD':         {'name': 'Harford County',         'fips': '24025', 'rate': 0.0306, 'type': 'county'},
  'MD_CTY_HOWARD':          {'name': 'Howard County',          'fips': '24027', 'rate': 0.032,  'type': 'county'},
  'MD_CTY_KENT':            {'name': 'Kent County',            'fips': '24029', 'rate': 0.0285, 'type': 'county'},
  'MD_CTY_MONTGOMERY':      {'name': 'Montgomery County',      'fips': '24031', 'rate': 0.032,  'type': 'county'},
  'MD_CTY_PG':              {'name': "Prince George's County", 'fips': '24033', 'rate': 0.032,  'type': 'county'},
  'MD_CTY_QUEEN_ANNES':     {'name': "Queen Anne's County",   'fips': '24035', 'rate': 0.032,  'type': 'county'},
  'MD_CTY_SOMERSET':        {'name': 'Somerset County',        'fips': '24039', 'rate': 0.032,  'type': 'county'},
  'MD_CTY_ST_MARYS':        {'name': "St. Mary's County",     'fips': '24037', 'rate': 0.03,   'type': 'county'},
  'MD_CTY_TALBOT':          {'name': 'Talbot County',          'fips': '24041', 'rate': 0.025,  'type': 'county'},
  'MD_CTY_WASHINGTON':      {'name': 'Washington County',      'fips': '24043', 'rate': 0.028,  'type': 'county'},
  'MD_CTY_WICOMICO':        {'name': 'Wicomico County',        'fips': '24045', 'rate': 0.032,  'type': 'county'},
  'MD_CTY_WORCESTER':       {'name': 'Worcester County',       'fips': '24047', 'rate': 0.0225, 'type': 'county'},
};
