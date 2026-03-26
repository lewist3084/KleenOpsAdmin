// lib/features/finances/services/tax_calculation_service.dart

/// Service for calculating federal and state income tax withholding.
class TaxCalculationService {
  // ─── 2025 Federal Tax Brackets (Single) ───
  static const _federalBracketsSingle = [
    (limit: 11925.0, rate: 0.10),
    (limit: 48475.0, rate: 0.12),
    (limit: 103350.0, rate: 0.22),
    (limit: 197300.0, rate: 0.24),
    (limit: 250525.0, rate: 0.32),
    (limit: 626350.0, rate: 0.35),
    (limit: double.infinity, rate: 0.37),
  ];

  // ─── 2025 Federal Tax Brackets (Married Filing Jointly) ───
  static const _federalBracketsMarried = [
    (limit: 23850.0, rate: 0.10),
    (limit: 96950.0, rate: 0.12),
    (limit: 206700.0, rate: 0.22),
    (limit: 394600.0, rate: 0.24),
    (limit: 501050.0, rate: 0.32),
    (limit: 752800.0, rate: 0.35),
    (limit: double.infinity, rate: 0.37),
  ];

  // ─── 2025 Federal Tax Brackets (Head of Household) ───
  static const _federalBracketsHoH = [
    (limit: 17000.0, rate: 0.10),
    (limit: 64850.0, rate: 0.12),
    (limit: 103350.0, rate: 0.22),
    (limit: 197300.0, rate: 0.24),
    (limit: 250500.0, rate: 0.32),
    (limit: 626350.0, rate: 0.35),
    (limit: double.infinity, rate: 0.37),
  ];

  // ─── Standard Deductions (2025) ───
  static const _standardDeductions = {
    'single': 15000.0,
    'married': 30000.0,
    'head_of_household': 22500.0,
  };

  /// Calculates annual federal income tax for a given annual gross income.
  ///
  /// [annualGross] — total annual gross pay
  /// [filingStatus] — 'single', 'married', or 'head_of_household'
  /// [allowances] — number of allowances/dependents (reduces taxable income)
  /// [additionalWithholding] — extra per-period withholding (annualized)
  double calculateAnnualFederalTax({
    required double annualGross,
    required String filingStatus,
    int allowances = 0,
    double additionalWithholding = 0,
  }) {
    // Apply standard deduction
    final standardDeduction =
        _standardDeductions[filingStatus] ?? _standardDeductions['single']!;
    // Each allowance reduces taxable income by ~$4,400 (2025 estimate)
    final allowanceDeduction = allowances * 4400.0;
    final taxableIncome =
        (annualGross - standardDeduction - allowanceDeduction)
            .clamp(0.0, double.infinity);

    final brackets = _bracketsForStatus(filingStatus);
    final tax = _applyBrackets(taxableIncome, brackets);

    return tax + additionalWithholding;
  }

  /// Calculates per-period federal tax withholding.
  double calculatePerPeriodFederalTax({
    required double periodGross,
    required String payFrequency,
    required String filingStatus,
    int allowances = 0,
    double additionalPerPeriod = 0,
  }) {
    final periods = _periodsPerYear(payFrequency);
    final annualGross = periodGross * periods;
    final annualTax = calculateAnnualFederalTax(
      annualGross: annualGross,
      filingStatus: filingStatus,
      allowances: allowances,
      additionalWithholding: additionalPerPeriod * periods,
    );
    return (annualTax / periods).clamp(0.0, double.infinity);
  }

  /// Calculates Social Security tax for a pay period.
  ///
  /// Returns 0 if YTD gross already exceeds the wage cap.
  double calculateSocialSecurity({
    required double periodGross,
    required double ytdGross,
    double rate = 0.062,
    double wageCap = 168600,
  }) {
    if (ytdGross >= wageCap) return 0;
    final taxableAmount =
        (wageCap - ytdGross).clamp(0.0, periodGross);
    return taxableAmount * rate;
  }

  /// Calculates Medicare tax for a pay period (including additional Medicare).
  ({double medicare, double additionalMedicare}) calculateMedicare({
    required double periodGross,
    required double ytdGross,
    double rate = 0.0145,
    double additionalRate = 0.009,
    double additionalThreshold = 200000,
  }) {
    final baseMedicare = periodGross * rate;

    double additional = 0;
    if (ytdGross + periodGross > additionalThreshold) {
      final excessStart =
          (additionalThreshold - ytdGross).clamp(0.0, periodGross);
      final excessAmount = periodGross - excessStart;
      additional = excessAmount * additionalRate;
    }

    return (medicare: baseMedicare, additionalMedicare: additional);
  }

  /// Calculates flat-rate state tax. Returns 0 if rate is null (no state tax).
  double calculateStateTax({
    required double periodGross,
    double? flatRate,
    double additionalPerPeriod = 0,
  }) {
    if (flatRate == null) return 0;
    return (periodGross * flatRate) + additionalPerPeriod;
  }

  /// Calculates state income tax using data from the top-level stateRule doc.
  /// Supports flat-rate AND graduated bracket states.
  double calculateStateIncomeTax({
    required double periodGross,
    required String payFrequency,
    required Map<String, dynamic> stateData,
    double additionalPerPeriod = 0,
  }) {
    if (stateData['hasStateIncomeTax'] != true) return 0;

    final taxType = (stateData['stateTaxType'] ?? '').toString();
    final periods = _periodsPerYear(payFrequency);
    final annualGross = periodGross * periods;

    double annualTax = 0;

    if (taxType == 'flat') {
      final rate = (stateData['stateTaxRate'] as num?)?.toDouble();
      if (rate == null) return additionalPerPeriod;
      annualTax = annualGross * rate;
    } else if (taxType == 'graduated') {
      final brackets = stateData['taxBrackets'];
      if (brackets is List && brackets.isNotEmpty) {
        annualTax = _applyDynamicBrackets(annualGross, brackets);
      }
    }
    // 'none' → 0

    return (annualTax / periods) + additionalPerPeriod;
  }

  /// Calculates local income tax (city/county) for a pay period.
  /// Supports both flat-rate and graduated local taxes.
  double calculateLocalIncomeTax({
    required double periodGross,
    required String payFrequency,
    required Map<String, dynamic> localTaxData,
  }) {
    final taxType = (localTaxData['taxType'] ?? '').toString();
    final periods = _periodsPerYear(payFrequency);
    final annualGross = periodGross * periods;

    double annualTax = 0;

    if (taxType == 'flat') {
      final rate = (localTaxData['rate'] as num?)?.toDouble();
      if (rate == null) return 0;
      annualTax = annualGross * rate;
    } else if (taxType == 'graduated') {
      final brackets = localTaxData['brackets'];
      if (brackets is List && brackets.isNotEmpty) {
        annualTax = _applyDynamicBrackets(annualGross, brackets);
      }
    }

    return annualTax / periods;
  }

  /// Calculates FUTA (Federal Unemployment Tax) — employer-only.
  /// 0.6% on first $7,000 of wages per employee per year.
  double calculateFuta({
    required double periodGross,
    required double ytdGross,
    double rate = 0.006,
    double wageCap = 7000,
  }) {
    if (ytdGross >= wageCap) return 0;
    final taxableAmount = (wageCap - ytdGross).clamp(0.0, periodGross);
    return taxableAmount * rate;
  }

  /// Calculates SUTA (State Unemployment Tax) — employer-only.
  /// Rate and wage cap vary by state and employer experience.
  double calculateSuta({
    required double periodGross,
    required double ytdGross,
    required double rate,
    double wageCap = 7000,
  }) {
    if (ytdGross >= wageCap) return 0;
    final taxableAmount = (wageCap - ytdGross).clamp(0.0, periodGross);
    return taxableAmount * rate;
  }

  // ─── Helpers ───

  /// Applies tax brackets from Firestore data (List<Map> with min/max/rate).
  double _applyDynamicBrackets(double taxableIncome, List<dynamic> brackets) {
    double tax = 0;
    for (final raw in brackets) {
      if (raw is! Map) continue;
      final min = (raw['min'] as num?)?.toDouble() ?? 0;
      final max = (raw['max'] as num?)?.toDouble() ?? double.infinity;
      final rate = (raw['rate'] as num?)?.toDouble() ?? 0;
      if (taxableIncome <= min) break;
      final taxableInBracket =
          taxableIncome.clamp(min, max) - min;
      tax += taxableInBracket * rate;
    }
    return tax;
  }

  List<({double limit, double rate})> _bracketsForStatus(String status) {
    switch (status) {
      case 'married':
        return _federalBracketsMarried;
      case 'head_of_household':
        return _federalBracketsHoH;
      default:
        return _federalBracketsSingle;
    }
  }

  double _applyBrackets(
      double taxableIncome, List<({double limit, double rate})> brackets) {
    double tax = 0;
    double previousLimit = 0;

    for (final bracket in brackets) {
      if (taxableIncome <= previousLimit) break;
      final taxableInBracket =
          (taxableIncome.clamp(previousLimit, bracket.limit)) - previousLimit;
      tax += taxableInBracket * bracket.rate;
      previousLimit = bracket.limit;
    }

    return tax;
  }

  int _periodsPerYear(String frequency) {
    switch (frequency) {
      case 'weekly':
        return 52;
      case 'biweekly':
        return 26;
      case 'semimonthly':
        return 24;
      case 'monthly':
        return 12;
      default:
        return 26; // default biweekly
    }
  }
}
