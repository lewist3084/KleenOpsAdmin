// lib/features/finances/services/payroll_gl_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// Creates general ledger journal entries from a processed payroll run.
///
/// Standard payroll journal entries:
///   DR  Wage Expense (gross pay)
///   CR  Federal Tax Payable (withheld federal income tax)
///   CR  State Tax Payable (withheld state income tax)
///   CR  FICA Payable - SS Employee (withheld Social Security)
///   CR  FICA Payable - Medicare Employee (withheld Medicare)
///   CR  Benefits Payable (employee benefit deductions)
///   CR  Cash / Payroll Bank Account (net pay to employees)
///
/// Employer taxes (separate entry):
///   DR  Payroll Tax Expense
///   CR  FICA Payable - SS Employer (employer SS match)
///   CR  FICA Payable - Medicare Employer (employer Medicare match)
///   CR  FUTA Payable
///   CR  SUTA Payable
class PayrollGlService {
  /// Generates GL journal entries for a payroll run and writes them
  /// to the company's `timeline` collection (general ledger).
  ///
  /// Returns the number of journal entries created.
  Future<int> generateJournalEntries({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required String runId,
  }) async {
    // Load the run
    final runSnap =
        await FirebaseFirestore.instance.collection('payrollRun').doc(runId).get();
    final runData = runSnap.data();
    if (runData == null) return 0;

    // Load all pay stubs
    final stubsSnap = await FirebaseFirestore.instance
        .collection('payrollRun')
        .doc(runId)
        .collection('payStub')
        .get();

    if (stubsSnap.docs.isEmpty) return 0;

    // Aggregate totals across all stubs
    double totalGross = 0;
    double totalFederalTax = 0;
    double totalStateTax = 0;
    double totalEmployeeSS = 0;
    double totalEmployeeMedicare = 0;
    double totalAdditionalMedicare = 0;
    double totalDeductions = 0;
    double totalNet = 0;
    double totalEmployerSS = 0;
    double totalEmployerMedicare = 0;
    double totalFuta = 0;
    double totalSuta = 0;

    for (final doc in stubsSnap.docs) {
      final d = doc.data();
      totalGross += (d['grossPay'] as num?)?.toDouble() ?? 0;
      totalFederalTax += (d['federalIncomeTax'] as num?)?.toDouble() ?? 0;
      totalStateTax += (d['stateIncomeTax'] as num?)?.toDouble() ?? 0;
      totalEmployeeSS += (d['socialSecurity'] as num?)?.toDouble() ?? 0;
      totalEmployeeMedicare += (d['medicare'] as num?)?.toDouble() ?? 0;
      totalAdditionalMedicare +=
          (d['additionalMedicare'] as num?)?.toDouble() ?? 0;
      totalDeductions += (d['totalDeductions'] as num?)?.toDouble() ?? 0;
      totalNet += (d['netPay'] as num?)?.toDouble() ?? 0;
      totalEmployerSS +=
          (d['employerSocialSecurity'] as num?)?.toDouble() ?? 0;
      totalEmployerMedicare +=
          (d['employerMedicare'] as num?)?.toDouble() ?? 0;
      totalFuta += (d['futa'] as num?)?.toDouble() ?? 0;
      totalSuta += (d['suta'] as num?)?.toDouble() ?? 0;
    }

    final payDate = runData['payDate'] as Timestamp? ?? Timestamp.now();
    final batch = FirebaseFirestore.instance.batch();
    int count = 0;

    // ── Entry 1: Employee wage expense ──
    batch.set(FirebaseFirestore.instance.collection('timeline').doc(), {
      'name': 'Payroll - Employee Wages',
      'type': 'payroll',
      'payrollRunId': runId,
      'date': payDate,
      'lines': [
        {
          'account': 'Wage Expense',
          'debit': _round(totalGross),
          'credit': 0,
        },
        {
          'account': 'Federal Tax Payable',
          'debit': 0,
          'credit': _round(totalFederalTax),
        },
        {
          'account': 'State Tax Payable',
          'debit': 0,
          'credit': _round(totalStateTax),
        },
        {
          'account': 'FICA Payable - SS Employee',
          'debit': 0,
          'credit': _round(totalEmployeeSS),
        },
        {
          'account': 'FICA Payable - Medicare Employee',
          'debit': 0,
          'credit': _round(totalEmployeeMedicare + totalAdditionalMedicare),
        },
        if (totalDeductions > 0)
          {
            'account': 'Benefits Payable',
            'debit': 0,
            'credit': _round(totalDeductions),
          },
        {
          'account': 'Payroll Cash',
          'debit': 0,
          'credit': _round(totalNet),
        },
      ],
      'amount': _round(totalGross),
      'createdAt': FieldValue.serverTimestamp(),
    });
    count++;

    // ── Entry 2: Employer payroll tax expense ──
    final totalEmployerTax =
        totalEmployerSS + totalEmployerMedicare + totalFuta + totalSuta;
    if (totalEmployerTax > 0) {
      batch.set(FirebaseFirestore.instance.collection('timeline').doc(), {
        'name': 'Payroll - Employer Taxes',
        'type': 'payroll_employer_tax',
        'payrollRunId': runId,
        'date': payDate,
        'lines': [
          {
            'account': 'Payroll Tax Expense',
            'debit': _round(totalEmployerTax),
            'credit': 0,
          },
          {
            'account': 'FICA Payable - SS Employer',
            'debit': 0,
            'credit': _round(totalEmployerSS),
          },
          {
            'account': 'FICA Payable - Medicare Employer',
            'debit': 0,
            'credit': _round(totalEmployerMedicare),
          },
          if (totalFuta > 0)
            {
              'account': 'FUTA Payable',
              'debit': 0,
              'credit': _round(totalFuta),
            },
          if (totalSuta > 0)
            {
              'account': 'SUTA Payable',
              'debit': 0,
              'credit': _round(totalSuta),
            },
        ],
        'amount': _round(totalEmployerTax),
        'createdAt': FieldValue.serverTimestamp(),
      });
      count++;
    }

    await batch.commit();

    // Mark the run as having GL entries
    await FirebaseFirestore.instance.collection('payrollRun').doc(runId).update({
      'glEntriesCreated': true,
      'glEntryCount': count,
    });

    return count;
  }

  double _round(double v) => (v * 100).roundToDouble() / 100;
}
