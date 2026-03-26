// lib/features/compliance/seed/insurance_seed_data.dart

/// Insurance requirements relevant to cleaning businesses.
const Map<String, Map<String, dynamic>> kInsuranceRequirements = {
  'generalLiability': {
    'type': 'generalLiability',
    'name': 'General Liability Insurance',
    'description':
        'Covers third-party bodily injury and property damage claims. '
        'Essential for cleaning businesses working at client sites.',
    'cleaningIndustryNotes':
        'Most commercial clients require \$1M per occurrence / \$2M aggregate minimum. '
        'Residential clients may accept lower limits. '
        'Covers slip-and-fall injuries, chemical damage to surfaces, broken fixtures, etc.',
    'requiredForAllStates': true,
    'minimumCoverage': 1000000,
    'typicalAnnualCost': {
      'min': 400,
      'max': 3000,
      'note': 'Varies by revenue, employee count, and claims history. '
          'Startup cleaning companies typically pay \$400-\$800/year.',
    },
    'resources': [
      {
        'name': 'ISSA Cleaning Industry Insurance Guide',
        'url': 'https://www.issa.com/resources',
      },
    ],
    'position': 0,
  },

  'workersComp': {
    'type': 'workersComp',
    'name': "Workers' Compensation Insurance",
    'description':
        "Covers medical costs and lost wages when employees are injured on the job. "
        "Required by law in nearly all states for employers with employees.",
    'cleaningIndustryNotes':
        'Cleaning/janitorial classification rates typically range from 2-5% of payroll. '
        'Common claims: slips/falls, chemical exposure, repetitive strain injuries. '
        'Maintaining a safety program can significantly lower premiums over time.',
    'requiredForAllStates': false,
    'minimumCoverage': null,
    'typicalAnnualCost': {
      'min': 500,
      'max': 5000,
      'note': 'Calculated as a percentage of total payroll. '
          'New employers pay the industry base rate until experience modifier is established.',
    },
    'resources': [
      {
        'name': 'NCCI Workers Comp Info',
        'url': 'https://www.ncci.com/',
      },
    ],
    'position': 1,
  },

  'bondingSurety': {
    'type': 'bondingSurety',
    'name': 'Surety Bond / Janitorial Bond',
    'description':
        'Protects clients against employee theft, dishonesty, or failure to perform. '
        'Not insurance for you — it guarantees your obligation to the client.',
    'cleaningIndustryNotes':
        'Many commercial contracts and some states (e.g., California) require janitorial bonds. '
        'Typical bond amounts: \$10,000-\$150,000. '
        'Annual premium is usually 1-5% of the bond amount based on credit.',
    'requiredForAllStates': false,
    'minimumCoverage': 10000,
    'typicalAnnualCost': {
      'min': 100,
      'max': 2000,
      'note': 'Premium is 1-5% of bond face value. '
          'A \$50,000 bond typically costs \$500-\$1,500/year.',
    },
    'position': 2,
  },

  'commercialAuto': {
    'type': 'commercialAuto',
    'name': 'Commercial Auto Insurance',
    'description':
        'Covers vehicles used for business purposes — transporting '
        'equipment, supplies, and employees to job sites.',
    'cleaningIndustryNotes':
        'Required if you have company vehicles. Even personal vehicles used for business '
        'may need a commercial endorsement. Covers accidents, theft, and vandalism.',
    'requiredForAllStates': false,
    'minimumCoverage': 100000,
    'typicalAnnualCost': {
      'min': 1200,
      'max': 3500,
      'note': 'Per vehicle. Varies by driver record, vehicle type, and coverage limits.',
    },
    'position': 3,
  },

  'umbrellaPolicy': {
    'type': 'umbrellaPolicy',
    'name': 'Commercial Umbrella / Excess Liability',
    'description':
        'Provides additional liability coverage above your general liability, '
        'auto, and workers comp limits.',
    'cleaningIndustryNotes':
        'Recommended once you exceed \$500K in annual revenue or have 10+ employees. '
        'Provides a safety net for catastrophic claims that exceed primary policy limits.',
    'requiredForAllStates': false,
    'minimumCoverage': 1000000,
    'typicalAnnualCost': {
      'min': 300,
      'max': 1500,
      'note': '\$1M umbrella typically costs \$300-\$500/year for small cleaning companies.',
    },
    'position': 4,
  },
};
