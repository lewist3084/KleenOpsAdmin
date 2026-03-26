// lib/features/finances/services/w2_pdf_service.dart

import 'dart:typed_data';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Generates W-2 wage and tax statement PDFs for year-end tax reporting.
///
/// Aggregates all payroll runs for a given tax year to produce:
///   Box 1: Wages, tips, other compensation
///   Box 2: Federal income tax withheld
///   Box 3: Social Security wages
///   Box 4: Social Security tax withheld
///   Box 5: Medicare wages and tips
///   Box 6: Medicare tax withheld
///   Box 16: State wages
///   Box 17: State income tax
///   Box 18: Local wages
///   Box 19: Local income tax
class W2PdfService {
  final _fmt = NumberFormat('#,##0.00');

  /// Aggregates YTD data for a single employee across all payroll runs
  /// in the given tax year.
  Future<Map<String, dynamic>> aggregateW2Data({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required String memberId,
    required int taxYear,
  }) async {
    final yearStart = DateTime(taxYear, 1, 1);
    final yearEnd = DateTime(taxYear, 12, 31, 23, 59, 59);

    final runsSnap = await FirebaseFirestore.instance
        .collection('payrollRun')
        .where('payDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(yearStart))
        .where('payDate',
            isLessThanOrEqualTo: Timestamp.fromDate(yearEnd))
        .where('status', whereIn: ['approved', 'processed'])
        .get();

    double totalGross = 0;
    double totalFederalTax = 0;
    double totalSSTax = 0;
    double totalSSWages = 0;
    double totalMedicareTax = 0;
    double totalMedicareWages = 0;
    double totalStateTax = 0;
    double totalStateWages = 0;
    double totalLocalTax = 0;
    double totalLocalWages = 0;
    double totalBenefitDeductions = 0;

    for (final runDoc in runsSnap.docs) {
      final stubSnap = await runDoc.reference
          .collection('payStub')
          .doc(memberId)
          .get();
      if (!stubSnap.exists) continue;
      final d = stubSnap.data()!;

      final gross = (d['grossPay'] as num?)?.toDouble() ?? 0;
      totalGross += gross;
      totalFederalTax +=
          (d['federalIncomeTax'] as num?)?.toDouble() ?? 0;
      totalSSTax += (d['socialSecurity'] as num?)?.toDouble() ?? 0;
      totalSSWages += gross; // SS wages = gross up to wage cap
      totalMedicareTax += (d['medicare'] as num?)?.toDouble() ?? 0;
      totalMedicareTax +=
          (d['additionalMedicare'] as num?)?.toDouble() ?? 0;
      totalMedicareWages += gross;
      totalStateTax +=
          (d['stateIncomeTax'] as num?)?.toDouble() ?? 0;
      totalStateWages += gross;
      totalLocalTax +=
          (d['localIncomeTax'] as num?)?.toDouble() ?? 0;
      totalLocalWages += totalLocalTax > 0 ? gross : 0;

      // Pre-tax benefit deductions reduce Box 1
      for (final ded in (d['deductions'] as List<dynamic>? ?? [])) {
        if (ded is Map && ded['type'] == 'benefit') {
          totalBenefitDeductions +=
              (ded['amount'] as num?)?.toDouble() ?? 0;
        }
      }
    }

    // Box 1 = Gross - pre-tax benefits (401k, HSA, etc.)
    final box1 = totalGross - totalBenefitDeductions;

    // Cap SS wages at wage cap
    const ssWageCap = 176100.0;
    final box3 = totalSSWages > ssWageCap ? ssWageCap : totalSSWages;

    return {
      'taxYear': taxYear,
      'memberId': memberId,
      'box1_wages': _round(box1),
      'box2_federalTaxWithheld': _round(totalFederalTax),
      'box3_ssWages': _round(box3),
      'box4_ssTaxWithheld': _round(totalSSTax),
      'box5_medicareWages': _round(totalMedicareWages),
      'box6_medicareTaxWithheld': _round(totalMedicareTax),
      'box12_preTaxDeductions': _round(totalBenefitDeductions),
      'box16_stateWages': _round(totalStateWages),
      'box17_stateTaxWithheld': _round(totalStateTax),
      'box18_localWages': _round(totalLocalWages),
      'box19_localTaxWithheld': _round(totalLocalTax),
      'totalGross': _round(totalGross),
    };
  }

  /// Generates a W-2 summary PDF for an employee.
  Uint8List generateW2Pdf({
    required Map<String, dynamic> w2Data,
    required Map<String, dynamic> memberData,
    required Map<String, dynamic> companyData,
  }) {
    final doc = PdfDocument();
    final page = doc.pages.add();
    final g = page.graphics;
    final bounds = page.getClientSize();

    final headerFont = PdfStandardFont(PdfFontFamily.helvetica, 14,
        style: PdfFontStyle.bold);
    final labelFont = PdfStandardFont(PdfFontFamily.helvetica, 9);
    final valueFont = PdfStandardFont(PdfFontFamily.helvetica, 11,
        style: PdfFontStyle.bold);
    final smallFont = PdfStandardFont(PdfFontFamily.helvetica, 8);

    double y = 0;
    final taxYear = w2Data['taxYear'] ?? DateTime.now().year;

    // Title
    g.drawString('W-2 Wage and Tax Statement — $taxYear', headerFont,
        bounds: Rect.fromLTWH(0, y, bounds.width, 20));
    y += 24;
    g.drawString(
        'FOR INFORMATIONAL PURPOSES — NOT AN OFFICIAL IRS FORM',
        smallFont,
        brush: PdfSolidBrush(PdfColor(180, 0, 0)),
        bounds: Rect.fromLTWH(0, y, bounds.width, 12));
    y += 20;

    // Employer info
    g.drawString('Employer:', labelFont,
        bounds: Rect.fromLTWH(0, y, 80, 14));
    g.drawString((companyData['name'] ?? 'KleenOps').toString(), valueFont,
        bounds: Rect.fromLTWH(80, y, 300, 14));
    y += 16;
    final ein = (companyData['ein'] ?? '').toString();
    if (ein.isNotEmpty) {
      g.drawString('EIN: $ein', labelFont,
          bounds: Rect.fromLTWH(80, y, 200, 14));
      y += 16;
    }
    y += 8;

    // Employee info
    g.drawString('Employee:', labelFont,
        bounds: Rect.fromLTWH(0, y, 80, 14));
    final firstName = (memberData['firstName'] ?? '').toString();
    final lastName = (memberData['lastName'] ?? '').toString();
    g.drawString('$firstName $lastName', valueFont,
        bounds: Rect.fromLTWH(80, y, 300, 14));
    y += 16;
    final ssnLast4 = (memberData['ssnLast4'] ?? '').toString();
    if (ssnLast4.isNotEmpty) {
      g.drawString('SSN: ***-**-$ssnLast4', labelFont,
          bounds: Rect.fromLTWH(80, y, 200, 14));
      y += 16;
    }
    y += 12;

    // Divider
    g.drawLine(PdfPen(PdfColor(200, 200, 200)),
        Offset(0, y), Offset(bounds.width, y));
    y += 12;

    // W-2 boxes
    final boxWidth = bounds.width / 2 - 10;

    y = _drawBox(g, 'Box 1 — Wages, tips, other compensation',
        '\$${_fmt.format(w2Data['box1_wages'] ?? 0)}',
        labelFont, valueFont, 0, y, boxWidth);
    _drawBox(g, 'Box 2 — Federal income tax withheld',
        '\$${_fmt.format(w2Data['box2_federalTaxWithheld'] ?? 0)}',
        labelFont, valueFont, boxWidth + 20, y - 40, boxWidth);

    y = _drawBox(g, 'Box 3 — Social Security wages',
        '\$${_fmt.format(w2Data['box3_ssWages'] ?? 0)}',
        labelFont, valueFont, 0, y, boxWidth);
    _drawBox(g, 'Box 4 — Social Security tax withheld',
        '\$${_fmt.format(w2Data['box4_ssTaxWithheld'] ?? 0)}',
        labelFont, valueFont, boxWidth + 20, y - 40, boxWidth);

    y = _drawBox(g, 'Box 5 — Medicare wages and tips',
        '\$${_fmt.format(w2Data['box5_medicareWages'] ?? 0)}',
        labelFont, valueFont, 0, y, boxWidth);
    _drawBox(g, 'Box 6 — Medicare tax withheld',
        '\$${_fmt.format(w2Data['box6_medicareTaxWithheld'] ?? 0)}',
        labelFont, valueFont, boxWidth + 20, y - 40, boxWidth);

    if ((w2Data['box12_preTaxDeductions'] ?? 0) > 0) {
      y = _drawBox(g, 'Box 12 — Pre-tax deductions (benefits)',
          '\$${_fmt.format(w2Data['box12_preTaxDeductions'] ?? 0)}',
          labelFont, valueFont, 0, y, boxWidth);
    }

    y += 8;
    g.drawLine(PdfPen(PdfColor(200, 200, 200)),
        Offset(0, y), Offset(bounds.width, y));
    y += 12;

    // State/local
    if ((w2Data['box17_stateTaxWithheld'] ?? 0) > 0) {
      g.drawString('STATE / LOCAL', labelFont,
          brush: PdfSolidBrush(PdfColor(100, 100, 100)),
          bounds: Rect.fromLTWH(0, y, 200, 14));
      y += 16;

      y = _drawBox(g, 'Box 16 — State wages',
          '\$${_fmt.format(w2Data['box16_stateWages'] ?? 0)}',
          labelFont, valueFont, 0, y, boxWidth);
      _drawBox(g, 'Box 17 — State income tax',
          '\$${_fmt.format(w2Data['box17_stateTaxWithheld'] ?? 0)}',
          labelFont, valueFont, boxWidth + 20, y - 40, boxWidth);
    }

    if ((w2Data['box19_localTaxWithheld'] ?? 0) > 0) {
      y = _drawBox(g, 'Box 18 — Local wages',
          '\$${_fmt.format(w2Data['box18_localWages'] ?? 0)}',
          labelFont, valueFont, 0, y, boxWidth);
      _drawBox(g, 'Box 19 — Local income tax',
          '\$${_fmt.format(w2Data['box19_localTaxWithheld'] ?? 0)}',
          labelFont, valueFont, boxWidth + 20, y - 40, boxWidth);
    }

    y += 20;
    g.drawString(
      'Generated by KleenOps on ${DateFormat('MMM d, yyyy').format(DateTime.now())}. '
      'This is an informational summary. Use official IRS Form W-2 for filing.',
      smallFont,
      brush: PdfSolidBrush(PdfColor(140, 140, 140)),
      bounds: Rect.fromLTWH(0, y, bounds.width, 30),
    );

    final bytes = doc.saveSync();
    doc.dispose();
    return Uint8List.fromList(bytes);
  }

  double _drawBox(PdfGraphics g, String label, String value,
      PdfFont labelF, PdfFont valueF,
      double x, double y, double width) {
    g.drawRectangle(
      pen: PdfPen(PdfColor(180, 180, 180)),
      bounds: Rect.fromLTWH(x, y, width, 36),
    );
    g.drawString(label, labelF,
        bounds: Rect.fromLTWH(x + 4, y + 2, width - 8, 12));
    g.drawString(value, valueF,
        bounds: Rect.fromLTWH(x + 4, y + 16, width - 8, 16));
    return y + 40;
  }

  double _round(double v) => (v * 100).roundToDouble() / 100;
}
