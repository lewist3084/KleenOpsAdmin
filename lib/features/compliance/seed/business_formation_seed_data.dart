// lib/features/compliance/seed/business_formation_seed_data.dart

/// Guidance for each business entity type, tailored for cleaning businesses.
const Map<String, Map<String, dynamic>> kBusinessFormations = {
  'llc': {
    'entityType': 'llc',
    'name': 'Limited Liability Company (LLC)',
    'description':
        'The most popular structure for cleaning businesses. Combines the liability '
        'protection of a corporation with the tax simplicity of a sole proprietorship.',
    'pros': [
      'Personal assets protected from business lawsuits',
      'Pass-through taxation (no double tax)',
      'Flexible management — no board required',
      'Easy to form in all states',
      'Can elect S-Corp taxation to save on self-employment tax',
    ],
    'cons': [
      'Self-employment tax on all income (unless S-Corp election)',
      'State filing fees vary (\$50-\$500)',
      'Some states charge annual franchise taxes',
      'Less established than corporations for large investors',
    ],
    'cleaningIndustryNotes':
        'Recommended for most cleaning companies. The liability protection is critical '
        'since your employees work at client sites where accidents can happen. '
        'If you grow beyond \$50K net income, consider S-Corp election to save on SE tax.',
    'typicalFormationSteps': [
      {'step': 1, 'title': 'Choose a business name', 'description': 'Check availability with your state\'s Secretary of State.'},
      {'step': 2, 'title': 'File Articles of Organization', 'description': 'Submit to the Secretary of State with the required fee.'},
      {'step': 3, 'title': 'Create an Operating Agreement', 'description': 'Defines ownership, profit sharing, and management structure.'},
      {'step': 4, 'title': 'Get an EIN from the IRS', 'description': 'Free and instant online. Required for hiring, banking, and taxes.'},
      {'step': 5, 'title': 'Register for state taxes', 'description': 'Withholding, unemployment, and any applicable state taxes.'},
      {'step': 6, 'title': 'Open a business bank account', 'description': 'Keep personal and business finances separate.'},
    ],
    'taxClassification': 'Disregarded entity (single member) or partnership (multi-member). Can elect S-Corp or C-Corp.',
    'position': 0,
  },

  'corporation': {
    'entityType': 'corporation',
    'name': 'Corporation (S-Corp or C-Corp)',
    'description':
        'A separate legal entity owned by shareholders. Offers the strongest liability '
        'protection and more credibility with larger clients.',
    'pros': [
      'Strongest liability protection',
      'S-Corp avoids double taxation',
      'More credible with enterprise clients and investors',
      'Can offer stock options to attract talent',
      'Perpetual existence — survives ownership changes',
    ],
    'cons': [
      'More complex setup and ongoing compliance',
      'Required board meetings and corporate minutes',
      'Higher formation and maintenance costs',
      'S-Corp limited to 100 shareholders, US only',
      'C-Corp faces double taxation',
    ],
    'cleaningIndustryNotes':
        'Best for cleaning companies targeting large commercial contracts or planning '
        'rapid growth. The S-Corp election is popular for owners paying themselves a '
        '"reasonable salary" — profits above salary avoid self-employment tax.',
    'typicalFormationSteps': [
      {'step': 1, 'title': 'Choose a business name', 'description': 'Must include "Corp", "Inc", or equivalent.'},
      {'step': 2, 'title': 'File Articles of Incorporation', 'description': 'Submit to Secretary of State.'},
      {'step': 3, 'title': 'Create Bylaws', 'description': 'Internal rules for corporate governance.'},
      {'step': 4, 'title': 'Issue stock certificates', 'description': 'Document ownership shares.'},
      {'step': 5, 'title': 'Hold initial board meeting', 'description': 'Adopt bylaws, appoint officers, set fiscal year.'},
      {'step': 6, 'title': 'Get EIN and register for taxes', 'description': 'File IRS Form 2553 for S-Corp election if desired.'},
    ],
    'taxClassification': 'C-Corp by default. File IRS Form 2553 within 75 days for S-Corp election.',
    'position': 1,
  },

  'soleProprietorship': {
    'entityType': 'soleProprietorship',
    'name': 'Sole Proprietorship',
    'description':
        'The simplest business structure — you and the business are legally the same. '
        'No state filing required to start.',
    'pros': [
      'Easiest and cheapest to start — no filing required',
      'Complete control over decisions',
      'All profits go directly to you',
      'File business income on personal tax return (Schedule C)',
      'No annual reports or corporate formalities',
    ],
    'cons': [
      'No personal liability protection — assets at risk',
      'Self-employment tax on all net income',
      'Harder to raise capital or get business loans',
      'Business ends if owner dies or is incapacitated',
      'Less credible with commercial clients',
    ],
    'cleaningIndustryNotes':
        'Only recommended for solo owner-operators doing residential cleaning with '
        'no employees. The lack of liability protection is a significant risk when '
        'working in clients\' homes and businesses. Strongly consider upgrading to '
        'an LLC as soon as you hire your first employee or take on commercial clients.',
    'typicalFormationSteps': [
      {'step': 1, 'title': 'Choose a business name', 'description': 'Register a DBA (Doing Business As) with your county or state.'},
      {'step': 2, 'title': 'Get an EIN (optional for solo)', 'description': 'Recommended even if not required. You can use your SSN but an EIN is safer.'},
      {'step': 3, 'title': 'Open a business bank account', 'description': 'Highly recommended for tracking income and expenses.'},
      {'step': 4, 'title': 'Get required licenses', 'description': 'Check city and county business license requirements.'},
    ],
    'taxClassification': 'Not a separate entity. Income reported on Schedule C of Form 1040.',
    'position': 2,
  },

  'partnership': {
    'entityType': 'partnership',
    'name': 'Partnership',
    'description':
        'Two or more people sharing ownership. Can be General Partnership (GP), '
        'Limited Partnership (LP), or Limited Liability Partnership (LLP).',
    'pros': [
      'Easy to form — can be verbal agreement (but don\'t)',
      'Pass-through taxation',
      'Partners share the workload and skills',
      'LLP offers liability protection',
      'Flexible profit-sharing arrangements',
    ],
    'cons': [
      'GP partners are personally liable for each other\'s actions',
      'Disagreements can paralyze the business',
      'Harder to sell or transfer ownership',
      'Must file partnership tax return (Form 1065)',
      'Each partner\'s share is subject to SE tax',
    ],
    'cleaningIndustryNotes':
        'If two or more people are starting a cleaning business together, consider '
        'a multi-member LLC instead of a general partnership — you get the same tax '
        'treatment but with liability protection. If you do form a partnership, always '
        'have a written partnership agreement covering profit splits, duties, and exit terms.',
    'typicalFormationSteps': [
      {'step': 1, 'title': 'Choose partners and structure', 'description': 'Decide between GP, LP, or LLP.'},
      {'step': 2, 'title': 'Draft Partnership Agreement', 'description': 'Define roles, profit sharing, capital contributions, and dissolution terms.'},
      {'step': 3, 'title': 'Register with the state', 'description': 'Required for LP and LLP. GP may just need a DBA.'},
      {'step': 4, 'title': 'Get EIN from IRS', 'description': 'Required for all partnerships.'},
      {'step': 5, 'title': 'Register for state taxes', 'description': 'Withholding, unemployment, and partnership returns.'},
    ],
    'taxClassification': 'Pass-through. Files Form 1065 and issues K-1 to each partner.',
    'position': 3,
  },
};
