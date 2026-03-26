// lib/features/finances/services/pay_stub_pdf_service.dart

import 'dart:typed_data';
import 'dart:ui';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Generates a professional pay stub PDF from pay stub data.
class PayStubPdfService {
  /// Generates a single pay stub PDF and returns the bytes.
  Uint8List generatePayStubPdf({
    required Map<String, dynamic> stubData,
    required Map<String, dynamic> runData,
    String companyName = 'KleenOps',
  }) {
    final doc = PdfDocument();
    final page = doc.pages.add();
    final graphics = page.graphics;
    final bounds = page.getClientSize();
    final fmt = NumberFormat('#,##0.00');

    final memberName = (stubData['memberName'] ?? '').toString();
    final payType = (stubData['payType'] ?? 'hourly').toString();
    final paymentMethod =
        (stubData['paymentMethod'] ?? 'direct_deposit').toString();

    final headerFont = PdfStandardFont(PdfFontFamily.helvetica, 16,
        style: PdfFontStyle.bold);
    final subHeaderFont = PdfStandardFont(PdfFontFamily.helvetica, 12,
        style: PdfFontStyle.bold);
    final labelFont = PdfStandardFont(PdfFontFamily.helvetica, 10);
    final valueFont = PdfStandardFont(PdfFontFamily.helvetica, 10,
        style: PdfFontStyle.bold);
    final smallFont = PdfStandardFont(PdfFontFamily.helvetica, 8);

    double y = 0;
    const leftMargin = 0.0;
    final rightCol = bounds.width / 2 + 20;

    // ── Company header ──
    graphics.drawString(companyName, headerFont,
        bounds: Rect.fromLTWH(leftMargin, y, bounds.width, 24));
    y += 24;
    graphics.drawString('PAY STUB', subHeaderFont,
        bounds: Rect.fromLTWH(leftMargin, y, bounds.width, 18));
    y += 28;

    // ── Pay period info ──
    final periodStart = runData['payPeriodStart'];
    final periodEnd = runData['payPeriodEnd'];
    final payDate = runData['payDate'];

    String formatTimestamp(dynamic ts) {
      if (ts == null) return '—';
      if (ts is DateTime) return DateFormat('MMM d, yyyy').format(ts);
      return ts.toString();
    }

    graphics.drawString('Employee: $memberName', labelFont,
        bounds: Rect.fromLTWH(leftMargin, y, 300, 14));
    graphics.drawString('Pay Date: ${formatTimestamp(payDate)}', labelFont,
        bounds: Rect.fromLTWH(rightCol, y, 250, 14));
    y += 16;

    graphics.drawString(
        'Period: ${formatTimestamp(periodStart)} – ${formatTimestamp(periodEnd)}',
        labelFont,
        bounds: Rect.fromLTWH(leftMargin, y, 300, 14));
    graphics.drawString(
        'Method: ${paymentMethod == 'direct_deposit' ? 'Direct Deposit' : 'Paper Check'}',
        labelFont,
        bounds: Rect.fromLTWH(rightCol, y, 250, 14));
    y += 24;

    // ── Divider ──
    graphics.drawLine(PdfPen(PdfColor(200, 200, 200)),
        Offset(0, y), Offset(bounds.width, y));
    y += 12;

    // ── Earnings ──
    graphics.drawString('EARNINGS', subHeaderFont,
        bounds: Rect.fromLTWH(leftMargin, y, 200, 16));
    y += 20;

    if (payType == 'hourly') {
      y = _drawRow(graphics, 'Regular Hours', '${stubData['regularHours'] ?? 0}',
          labelFont, valueFont, y, bounds.width);
      y = _drawRow(graphics, 'Rate',
          '\$${fmt.format(stubData['regularRate'] ?? 0)}',
          labelFont, valueFont, y, bounds.width);
      y = _drawRow(graphics, 'Regular Pay',
          '\$${fmt.format(stubData['regularPay'] ?? 0)}',
          labelFont, valueFont, y, bounds.width);
      if ((stubData['overtimeHours'] ?? 0) > 0) {
        y = _drawRow(graphics, 'Overtime Hours',
            '${stubData['overtimeHours']}',
            labelFont, valueFont, y, bounds.width);
        y = _drawRow(graphics, 'OT Rate',
            '${stubData['overtimeRate'] ?? 1.5}x',
            labelFont, valueFont, y, bounds.width);
        y = _drawRow(graphics, 'Overtime Pay',
            '\$${fmt.format(stubData['overtimePay'] ?? 0)}',
            labelFont, valueFont, y, bounds.width);
      }
    }
    y = _drawRow(graphics, 'GROSS PAY',
        '\$${fmt.format(stubData['grossPay'] ?? 0)}',
        subHeaderFont, valueFont, y, bounds.width);
    y += 12;

    // ── Taxes ──
    graphics.drawString('TAXES (EMPLOYEE)', subHeaderFont,
        bounds: Rect.fromLTWH(leftMargin, y, 200, 16));
    y += 20;

    y = _drawRow(graphics, 'Federal Income Tax',
        '\$${fmt.format(stubData['federalIncomeTax'] ?? 0)}',
        labelFont, valueFont, y, bounds.width);
    y = _drawRow(graphics, 'State Income Tax',
        '\$${fmt.format(stubData['stateIncomeTax'] ?? 0)}',
        labelFont, valueFont, y, bounds.width);
    y = _drawRow(graphics, 'Social Security (6.2%)',
        '\$${fmt.format(stubData['socialSecurity'] ?? 0)}',
        labelFont, valueFont, y, bounds.width);
    y = _drawRow(graphics, 'Medicare (1.45%)',
        '\$${fmt.format(stubData['medicare'] ?? 0)}',
        labelFont, valueFont, y, bounds.width);
    if ((stubData['additionalMedicare'] ?? 0) > 0) {
      y = _drawRow(graphics, 'Additional Medicare',
          '\$${fmt.format(stubData['additionalMedicare'])}',
          labelFont, valueFont, y, bounds.width);
    }
    y = _drawRow(graphics, 'TOTAL TAXES',
        '\$${fmt.format(stubData['totalTaxes'] ?? 0)}',
        subHeaderFont, valueFont, y, bounds.width);
    y += 12;

    // ── Deductions ──
    final deductions = stubData['deductions'] as List<dynamic>? ?? [];
    if (deductions.isNotEmpty) {
      graphics.drawString('DEDUCTIONS', subHeaderFont,
          bounds: Rect.fromLTWH(leftMargin, y, 200, 16));
      y += 20;
      for (final d in deductions) {
        if (d is! Map) continue;
        y = _drawRow(graphics, (d['name'] ?? 'Deduction').toString(),
            '\$${fmt.format(d['amount'] ?? 0)}',
            labelFont, valueFont, y, bounds.width);
      }
      y = _drawRow(graphics, 'TOTAL DEDUCTIONS',
          '\$${fmt.format(stubData['totalDeductions'] ?? 0)}',
          subHeaderFont, valueFont, y, bounds.width);
      y += 12;
    }

    // ── Employer taxes (informational) ──
    if ((stubData['totalEmployerTaxes'] ?? 0) > 0) {
      graphics.drawString('EMPLOYER TAXES (not deducted from pay)', smallFont,
          brush: PdfSolidBrush(PdfColor(120, 120, 120)),
          bounds: Rect.fromLTWH(leftMargin, y, 300, 12));
      y += 14;
      y = _drawRow(graphics, 'Employer SS Match',
          '\$${fmt.format(stubData['employerSocialSecurity'] ?? 0)}',
          smallFont, smallFont, y, bounds.width);
      y = _drawRow(graphics, 'Employer Medicare Match',
          '\$${fmt.format(stubData['employerMedicare'] ?? 0)}',
          smallFont, smallFont, y, bounds.width);
      y = _drawRow(graphics, 'FUTA',
          '\$${fmt.format(stubData['futa'] ?? 0)}',
          smallFont, smallFont, y, bounds.width);
      y = _drawRow(graphics, 'SUTA',
          '\$${fmt.format(stubData['suta'] ?? 0)}',
          smallFont, smallFont, y, bounds.width);
      y += 12;
    }

    // ── Net Pay ──
    graphics.drawLine(PdfPen(PdfColor(0, 128, 0), width: 2),
        Offset(0, y), Offset(bounds.width, y));
    y += 8;
    final netFont = PdfStandardFont(PdfFontFamily.helvetica, 14,
        style: PdfFontStyle.bold);
    graphics.drawString('NET PAY', netFont,
        bounds: Rect.fromLTWH(leftMargin, y, 200, 20));
    graphics.drawString('\$${fmt.format(stubData['netPay'] ?? 0)}', netFont,
        bounds: Rect.fromLTWH(rightCol, y, 200, 20),
        format: PdfStringFormat(alignment: PdfTextAlignment.right));
    y += 28;

    // ── YTD ──
    graphics.drawLine(PdfPen(PdfColor(200, 200, 200)),
        Offset(0, y), Offset(bounds.width, y));
    y += 8;
    graphics.drawString('YEAR-TO-DATE SUMMARY', subHeaderFont,
        bounds: Rect.fromLTWH(leftMargin, y, 300, 16));
    y += 20;
    y = _drawRow(graphics, 'YTD Gross',
        '\$${fmt.format(stubData['ytdGross'] ?? 0)}',
        labelFont, valueFont, y, bounds.width);
    y = _drawRow(graphics, 'YTD Taxes',
        '\$${fmt.format(stubData['ytdTaxes'] ?? 0)}',
        labelFont, valueFont, y, bounds.width);
    y = _drawRow(graphics, 'YTD Deductions',
        '\$${fmt.format(stubData['ytdDeductions'] ?? 0)}',
        labelFont, valueFont, y, bounds.width);
    y = _drawRow(graphics, 'YTD Net',
        '\$${fmt.format(stubData['ytdNet'] ?? 0)}',
        labelFont, valueFont, y, bounds.width);
    y += 20;

    // ── Footer ──
    graphics.drawString(
      'This is a computer-generated document. '
      'Generated by $companyName on ${DateFormat('MMM d, yyyy HH:mm').format(DateTime.now())}.',
      smallFont,
      brush: PdfSolidBrush(PdfColor(140, 140, 140)),
      bounds: Rect.fromLTWH(leftMargin, y, bounds.width, 20),
    );

    final bytes = doc.saveSync();
    doc.dispose();
    return Uint8List.fromList(bytes);
  }

  double _drawRow(
    PdfGraphics g,
    String label,
    String value,
    PdfFont labelF,
    PdfFont valueF,
    double y,
    double width,
  ) {
    g.drawString(label, labelF,
        bounds: Rect.fromLTWH(0, y, width * 0.6, 14));
    g.drawString(value, valueF,
        bounds: Rect.fromLTWH(width * 0.6, y, width * 0.4, 14),
        format: PdfStringFormat(alignment: PdfTextAlignment.right));
    return y + 16;
  }
}
