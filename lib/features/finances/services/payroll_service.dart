// lib/features/finances/services/payroll_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kleenops_admin/features/finances/services/tax_calculation_service.dart';
import 'package:kleenops_admin/features/finances/services/local_tax_lookup_service.dart';
import 'package:kleenops_admin/features/finances/services/payroll_gl_service.dart';

/// Core payroll calculation and run management service.
class PayrollService {
  final _tax = TaxCalculationService();

  // ─── Gross Pay ───

  /// Calculates gross pay for an hourly employee.
  ({double regular, double overtime, double gross}) calculateHourlyGross({
    required double regularHours,
    required double hourlyRate,
    double overtimeHours = 0,
    double overtimeMultiplier = 1.5,
  }) {
    final regular = regularHours * hourlyRate;
    final overtime = overtimeHours * hourlyRate * overtimeMultiplier;
    return (regular: regular, overtime: overtime, gross: regular + overtime);
  }

  /// Calculates gross pay for a salaried employee per pay period.
  double calculateSalaryGross({
    required double annualSalary,
    required String payFrequency,
  }) {
    final periods = _periodsPerYear(payFrequency);
    return annualSalary / periods;
  }

  // ─── Full Pay Stub Calculation ───

  /// Calculates a complete pay stub for one employee.
  Future<Map<String, dynamic>> calculatePayStub({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required Map<String, dynamic> memberData,
    required String memberId,
    required double regularHours,
    double overtimeHours = 0,
    double ytdGross = 0,
    double ytdTaxes = 0,
    double ytdDeductions = 0,
    double ytdNet = 0,
  }) async {
    final payType = (memberData['payType'] ?? 'hourly').toString();
    final payRate = (memberData['payRate'] as num?)?.toDouble() ?? 0;
    final payFrequency =
        (memberData['payFrequency'] ?? 'biweekly').toString();
    final overtimeMultiplier =
        (memberData['overtimeRate'] as num?)?.toDouble() ?? 1.5;
    final overtimeEligible = memberData['overtimeEligible'] ?? true;
    final filingStatus =
        (memberData['federalFilingStatus'] ?? 'single').toString();
    final allowances =
        (memberData['federalAllowances'] as num?)?.toInt() ?? 0;
    final additionalFederal =
        (memberData['additionalFederalWithholding'] as num?)?.toDouble() ??
            0;
    final additionalState =
        (memberData['additionalStateWithholding'] as num?)?.toDouble() ?? 0;
    final workState = (memberData['workState'] ?? '').toString();
    final paymentMethod =
        (memberData['paymentMethod'] ?? 'direct_deposit').toString();
    final memberName = (memberData['name'] ?? '').toString();

    // ── Gross ──
    double grossPay;
    double regularPay = 0;
    double overtimePay = 0;
    double effectiveRegularHours = regularHours;
    double effectiveOvertimeHours = overtimeHours;

    if (payType == 'salary') {
      grossPay = calculateSalaryGross(
        annualSalary: payRate,
        payFrequency: payFrequency,
      );
      effectiveRegularHours = 0;
      effectiveOvertimeHours = 0;
    } else {
      final result = calculateHourlyGross(
        regularHours: regularHours,
        hourlyRate: payRate,
        overtimeHours: overtimeEligible ? overtimeHours : 0,
        overtimeMultiplier: overtimeMultiplier,
      );
      regularPay = result.regular;
      overtimePay = result.overtime;
      grossPay = result.gross;
    }

    // ── Federal Income Tax ──
    final federalIncomeTax = _tax.calculatePerPeriodFederalTax(
      periodGross: grossPay,
      payFrequency: payFrequency,
      filingStatus: filingStatus,
      allowances: allowances,
      additionalPerPeriod: additionalFederal,
    );

    // ── Social Security ──
    final socialSecurity = _tax.calculateSocialSecurity(
      periodGross: grossPay,
      ytdGross: ytdGross,
    );

    // ── Medicare ──
    final medicareResult = _tax.calculateMedicare(
      periodGross: grossPay,
      ytdGross: ytdGross,
    );
    final medicare = medicareResult.medicare;
    final additionalMedicare = medicareResult.additionalMedicare;

    // ── Load state data once (used for state tax, SUTA, local tax) ──
    Map<String, dynamic>? stateData;
    if (workState.isNotEmpty) {
      final stateSnap = await FirebaseFirestore.instance
          .collection('stateRule')
          .doc(workState)
          .get();
      if (stateSnap.exists) stateData = stateSnap.data();
    }

    // ── State Income Tax ──
    double stateIncomeTax = 0;
    if (stateData != null) {
      stateIncomeTax = _tax.calculateStateIncomeTax(
        periodGross: grossPay,
        payFrequency: payFrequency,
        stateData: stateData,
        additionalPerPeriod: additionalState,
      );
    }

    // ── Local Income Tax (jurisdiction-based from employee record) ──
    double localIncomeTax = 0;
    final localTaxDetails = <Map<String, dynamic>>[];
    final resolvedJurisdictions =
        memberData['localTaxJurisdictions'] as List<dynamic>? ?? [];

    if (resolvedJurisdictions.isNotEmpty) {
      final localService = LocalTaxLookupService();
      final items = await localService.calculateAllLocalTaxes(
        periodGross: grossPay,
        payFrequency: payFrequency,
        resolvedJurisdictions: resolvedJurisdictions
            .whereType<Map>()
            .map((j) => Map<String, dynamic>.from(j))
            .toList(),
      );
      for (final item in items) {
        localIncomeTax += (item['amount'] as num?)?.toDouble() ?? 0;
        localTaxDetails.add(item);
      }
    }

    // ── FUTA (employer-only, not deducted from employee pay) ──
    final futa = _tax.calculateFuta(
      periodGross: grossPay,
      ytdGross: ytdGross,
    );

    // ── SUTA (employer-only, rate from state) ──
    double suta = 0;
    if (stateData != null) {
      final sutaRate =
          (stateData['sutaRateNew'] as num?)?.toDouble() ?? 0;
      final sutaWageCap =
          (stateData['sutaWageCap'] as num?)?.toDouble() ?? 7000;
      suta = _tax.calculateSuta(
        periodGross: grossPay,
        ytdGross: ytdGross,
        rate: sutaRate,
        wageCap: sutaWageCap,
      );
    }

    final totalTaxes = federalIncomeTax +
        stateIncomeTax +
        localIncomeTax +
        socialSecurity +
        medicare +
        additionalMedicare;

    // ── Benefit Deductions ──
    final deductions = <Map<String, dynamic>>[];
    double totalDeductions = 0;

    final enrollmentSnap = await FirebaseFirestore.instance
        .collection('benefitEnrollment')
        .where('memberId', isEqualTo: memberId)
        .where('status', isEqualTo: 'active')
        .get();

    for (final doc in enrollmentSnap.docs) {
      final d = doc.data();
      final eeCost =
          (d['employeeContribution'] as num?)?.toDouble() ?? 0;
      if (eeCost > 0) {
        deductions.add({
          'name': (d['benefitPlanName'] ?? 'Benefit').toString(),
          'type': 'benefit',
          'amount': eeCost,
        });
        totalDeductions += eeCost;
      }
    }

    // ── Wage Garnishments ──
    final garnishments =
        memberData['garnishments'] as List<dynamic>? ?? [];
    double totalGarnishments = 0;
    final disposableIncome = grossPay - totalTaxes;

    for (final raw in garnishments) {
      if (raw is! Map) continue;
      final g = Map<String, dynamic>.from(raw);
      if (g['active'] != true) continue;

      double garnishmentAmount = 0;
      final amountType = (g['amountType'] ?? 'fixed').toString();
      final amount = (g['amount'] as num?)?.toDouble() ?? 0;

      if (amountType == 'percentage') {
        garnishmentAmount = disposableIncome * (amount / 100);
      } else {
        garnishmentAmount = amount;
      }

      // Enforce federal garnishment limits
      final garnishType = (g['type'] ?? '').toString();
      double maxPercent = 0.25; // default creditor limit
      if (garnishType == 'child_support') {
        maxPercent = 0.60; // up to 60% for child support
      } else if (garnishType == 'tax_levy') {
        maxPercent = 0.15; // IRS levy typically limited
      }
      final maxAllowed = disposableIncome * maxPercent;
      garnishmentAmount = garnishmentAmount.clamp(0, maxAllowed);

      if (garnishmentAmount > 0) {
        deductions.add({
          'name': '${_formatGarnishmentType(garnishType)}: ${g['payee'] ?? 'Garnishment'}',
          'type': 'garnishment',
          'amount': _round(garnishmentAmount),
          'caseNumber': g['caseNumber'],
        });
        totalDeductions += garnishmentAmount;
        totalGarnishments += garnishmentAmount;
      }
    }

    // ── Net Pay ──
    final netPay = grossPay - totalTaxes - totalDeductions;

    return {
      'memberId': memberId,
      'memberName': memberName,
      'payType': payType,
      'regularHours': effectiveRegularHours,
      'regularRate': payType == 'hourly' ? payRate : 0,
      'regularPay': regularPay,
      'overtimeHours': effectiveOvertimeHours,
      'overtimeRate': overtimeMultiplier,
      'overtimePay': overtimePay,
      'grossPay': _round(grossPay),
      // Employee taxes (withheld from paycheck)
      'federalIncomeTax': _round(federalIncomeTax),
      'stateIncomeTax': _round(stateIncomeTax),
      'localIncomeTax': _round(localIncomeTax),
      'localTaxDetails': localTaxDetails,
      'socialSecurity': _round(socialSecurity),
      'medicare': _round(medicare),
      'additionalMedicare': _round(additionalMedicare),
      'totalTaxes': _round(totalTaxes),
      // Employer-only taxes (NOT deducted from employee pay)
      'employerSocialSecurity': _round(socialSecurity), // employer match
      'employerMedicare': _round(medicare), // employer match
      'futa': _round(futa),
      'suta': _round(suta),
      'totalEmployerTaxes': _round(socialSecurity + medicare + futa + suta),
      // Deductions (benefits + garnishments)
      'deductions': deductions,
      'totalDeductions': _round(totalDeductions),
      'totalGarnishments': _round(totalGarnishments),
      'netPay': _round(netPay),
      'paymentMethod': paymentMethod,
      'paymentStatus': 'pending',
      // YTD tracking
      'ytdGross': _round(ytdGross + grossPay),
      'ytdTaxes': _round(ytdTaxes + totalTaxes),
      'ytdDeductions': _round(ytdDeductions + totalDeductions),
      'ytdNet': _round(ytdNet + netPay),
    };
  }

  // ─── Payroll Run Management ───

  /// Creates a new payroll run document.
  Future<String> createPayrollRun({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required DateTime periodStart,
    required DateTime periodEnd,
    required DateTime payDate,
  }) async {
    final docRef = FirebaseFirestore.instance.collection('payrollRun').doc();
    await docRef.set({
      'payPeriodStart': Timestamp.fromDate(periodStart),
      'payPeriodEnd': Timestamp.fromDate(periodEnd),
      'payDate': Timestamp.fromDate(payDate),
      'status': 'draft',
      'totalGross': 0,
      'totalNet': 0,
      'totalTaxes': 0,
      'totalDeductions': 0,
      'employeeCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  /// Generates pay stubs for all active employees in a payroll run.
  ///
  /// [hoursMap] maps memberId → { regularHours, overtimeHours }
  Future<void> generatePayStubs({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required String runId,
    required Map<String, Map<String, double>> hoursMap,
  }) async {
    final memberSnap = await FirebaseFirestore.instance
        .collection('member')
        .where('active', isEqualTo: true)
        .get();

    double totalGross = 0;
    double totalNet = 0;
    double totalTaxes = 0;
    double totalDeductions = 0;
    int count = 0;

    final batch = FirebaseFirestore.instance.batch();
    final stubCollection =
        FirebaseFirestore.instance.collection('payrollRun').doc(runId).collection('payStub');

    // Query the most recent completed payroll run to get YTD values per member
    final priorYtd = await _getYtdForAllMembers(companyRef, runId);

    for (final memberDoc in memberSnap.docs) {
      final memberId = memberDoc.id;
      final memberData = memberDoc.data();
      final hours = hoursMap[memberId] ?? {};
      final regularHours = hours['regularHours'] ?? 0;
      final overtimeHours = hours['overtimeHours'] ?? 0;

      // Skip members with no hours and hourly pay type
      final payType = (memberData['payType'] ?? 'hourly').toString();
      if (payType == 'hourly' && regularHours == 0) continue;

      // Get YTD from most recent prior run for this member
      final ytd = priorYtd[memberId] ?? {};
      final stub = await calculatePayStub(
        companyRef: companyRef,
        memberData: memberData,
        memberId: memberId,
        regularHours: regularHours,
        overtimeHours: overtimeHours,
        ytdGross: (ytd['ytdGross'] as num?)?.toDouble() ?? 0,
        ytdTaxes: (ytd['ytdTaxes'] as num?)?.toDouble() ?? 0,
        ytdDeductions: (ytd['ytdDeductions'] as num?)?.toDouble() ?? 0,
        ytdNet: (ytd['ytdNet'] as num?)?.toDouble() ?? 0,
      );

      final stubRef = stubCollection.doc(memberId);
      batch.set(stubRef, stub);

      totalGross += (stub['grossPay'] as num).toDouble();
      totalNet += (stub['netPay'] as num).toDouble();
      totalTaxes += (stub['totalTaxes'] as num).toDouble();
      totalDeductions += (stub['totalDeductions'] as num).toDouble();
      count++;
    }

    // Update the run totals
    final runRef = FirebaseFirestore.instance.collection('payrollRun').doc(runId);
    batch.update(runRef, {
      'totalGross': _round(totalGross),
      'totalNet': _round(totalNet),
      'totalTaxes': _round(totalTaxes),
      'totalDeductions': _round(totalDeductions),
      'employeeCount': count,
      'status': 'draft',
    });

    await batch.commit();
  }

  /// Approves a payroll run (changes status from draft → approved).
  /// Also records the designated payroll bank account on the run.
  Future<void> approvePayrollRun({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required String runId,
  }) async {
    // Look up designated payroll bank account
    final payrollAcct = await FirebaseFirestore.instance
        .collection('bankAccount')
        .where('isPayrollAccount', isEqualTo: true)
        .where('active', isEqualTo: true)
        .limit(1)
        .get();

    final updateData = <String, dynamic>{
      'status': 'approved',
      'approvedAt': FieldValue.serverTimestamp(),
    };

    if (payrollAcct.docs.isNotEmpty) {
      final acct = payrollAcct.docs.first;
      updateData['payrollBankAccountId'] = acct.id;
      updateData['payrollBankName'] =
          '${acct.data()['name'] ?? ''} ••${acct.data()['mask'] ?? ''}';
    }

    await FirebaseFirestore.instance.collection('payrollRun').doc(runId).update(updateData);
  }

  /// Processes a payroll run (approved → processed).
  /// Creates general ledger entries in the timeline collection.
  /// Processes an approved payroll run:
  /// 1. Marks status as 'processed'
  /// 2. Generates full GL journal entries (employee wages + employer taxes)
  /// 3. Locks the run (no further edits)
  Future<void> processPayrollRun({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required String runId,
  }) async {
    final runSnap =
        await FirebaseFirestore.instance.collection('payrollRun').doc(runId).get();
    final runData = runSnap.data();
    if (runData == null) return;

    // Prevent re-processing
    if (runData['status'] == 'processed') return;

    await FirebaseFirestore.instance.collection('payrollRun').doc(runId).update({
      'status': 'processed',
      'processedAt': FieldValue.serverTimestamp(),
      'locked': true,
    });

    // Generate proper GL journal entries (DR wage expense, CR liabilities/cash)
    final glService = PayrollGlService();
    await glService.generateJournalEntries(
      companyRef: companyRef,
      runId: runId,
    );
  }

  // ─── YTD Persistence ───

  /// Queries prior payroll runs in the current calendar year to get
  /// accumulated YTD values for each employee.
  ///
  /// Returns Map<memberId, {ytdGross, ytdTaxes, ytdDeductions, ytdNet}>.
  Future<Map<String, Map<String, dynamic>>> _getYtdForAllMembers(
    DocumentReference<Map<String, dynamic>> companyRef,
    String currentRunId,
  ) async {
    final now = DateTime.now();
    final yearStart = DateTime(now.year, 1, 1);

    // Get all processed/approved runs this year (excluding current draft)
    final runsSnap = await FirebaseFirestore.instance
        .collection('payrollRun')
        .where('payDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(yearStart))
        .where('status', whereIn: ['approved', 'processed'])
        .orderBy('payDate')
        .get();

    final ytdMap = <String, Map<String, dynamic>>{};

    for (final runDoc in runsSnap.docs) {
      if (runDoc.id == currentRunId) continue;

      // Get all pay stubs from this run
      final stubsSnap = await runDoc.reference
          .collection('payStub')
          .get();

      for (final stubDoc in stubsSnap.docs) {
        final memberId = stubDoc.id;
        final data = stubDoc.data();
        final gross = (data['grossPay'] as num?)?.toDouble() ?? 0;
        final taxes = (data['totalTaxes'] as num?)?.toDouble() ?? 0;
        final deductions =
            (data['totalDeductions'] as num?)?.toDouble() ?? 0;
        final net = (data['netPay'] as num?)?.toDouble() ?? 0;

        final existing = ytdMap[memberId];
        if (existing != null) {
          ytdMap[memberId] = {
            'ytdGross':
                (existing['ytdGross'] as double) + gross,
            'ytdTaxes':
                (existing['ytdTaxes'] as double) + taxes,
            'ytdDeductions':
                (existing['ytdDeductions'] as double) + deductions,
            'ytdNet': (existing['ytdNet'] as double) + net,
          };
        } else {
          ytdMap[memberId] = {
            'ytdGross': gross,
            'ytdTaxes': taxes,
            'ytdDeductions': deductions,
            'ytdNet': net,
          };
        }
      }
    }

    return ytdMap;
  }

  // ─── Helpers ───

  String _formatGarnishmentType(String type) {
    switch (type) {
      case 'child_support': return 'Child Support';
      case 'tax_levy': return 'Tax Levy';
      case 'creditor': return 'Creditor';
      case 'student_loan': return 'Student Loan';
      case 'bankruptcy': return 'Bankruptcy';
      default: return 'Garnishment';
    }
  }

  double _round(double value) {
    return (value * 100).roundToDouble() / 100;
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
        return 26;
    }
  }
}
