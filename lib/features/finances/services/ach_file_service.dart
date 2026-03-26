// lib/features/finances/services/ach_file_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Generates NACHA-formatted ACH files for payroll direct deposits.
///
/// NACHA file format (simplified):
///   File Header (1 record)
///   Batch Header (1 per batch)
///   Entry Detail (1 per employee)
///   Batch Control (1 per batch)
///   File Control (1 record)
///
/// Each record is exactly 94 characters + line ending.
class AchFileService {
  /// Generates an ACH file string for all direct-deposit employees in a payroll run.
  ///
  /// [companyName] — originator name (max 23 chars)
  /// [companyEin] — company EIN / tax ID (10 digits)
  /// [originatingBank] — bank routing number
  /// [bankAccountNumber] — company bank account
  Future<String> generateAchFile({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required String runId,
    required String companyName,
    required String companyEin,
    required String originatingBank,
    required String bankAccountNumber,
  }) async {
    // Load pay stubs
    final stubsSnap = await FirebaseFirestore.instance
        .collection('payrollRun')
        .doc(runId)
        .collection('payStub')
        .get();

    // Load run for pay date
    final runSnap =
        await FirebaseFirestore.instance.collection('payrollRun').doc(runId).get();
    final runData = runSnap.data() ?? {};
    final payDate = runData['payDate'] is Timestamp
        ? (runData['payDate'] as Timestamp).toDate()
        : DateTime.now();

    // Filter to direct deposit employees with bank info
    final ddStubs = <_AchEntry>[];
    for (final doc in stubsSnap.docs) {
      final d = doc.data();
      if ((d['paymentMethod'] ?? '') != 'direct_deposit') continue;
      final netPay = (d['netPay'] as num?)?.toDouble() ?? 0;
      if (netPay <= 0) continue;

      // Load member bank details
      final memberId = doc.id;
      final memberSnap =
          await FirebaseFirestore.instance.collection('member').doc(memberId).get();
      final memberData = memberSnap.data();
      if (memberData == null) continue;

      final banks = memberData['bankAccounts'] as List<dynamic>?;
      if (banks == null || banks.isEmpty) continue;
      final bank = banks.first as Map<String, dynamic>;

      final routing = (bank['routingNumber'] ?? '').toString().trim();
      final account = (bank['accountNumber'] ?? '').toString().trim();
      final acctType = (bank['accountType'] ?? 'checking').toString();
      final name = (d['memberName'] ?? '').toString();

      if (routing.length != 9 || account.isEmpty) continue;

      ddStubs.add(_AchEntry(
        routingNumber: routing,
        accountNumber: account,
        accountType: acctType,
        amount: netPay,
        name: name,
        memberId: memberId,
      ));
    }

    if (ddStubs.isEmpty) return '';

    // Build NACHA file
    final lines = <String>[];
    final now = DateTime.now();
    final fileDate = DateFormat('yyMMdd').format(now);
    final fileTime = DateFormat('HHmm').format(now);
    final effectiveDate = DateFormat('yyMMdd').format(payDate);
    final cleanName = _pad(companyName, 23);
    final cleanEin = _pad(companyEin.replaceAll('-', ''), 10);
    final originRoute = _pad(originatingBank, 9);

    // File Header Record (1)
    lines.add(
      '1'                                 // Record type
      '01'                                // Priority code
      ' $originRoute'                     // Immediate destination (space + 9)
      ' $cleanEin'                        // Immediate origin (space + 10)
      '$fileDate'                         // File creation date
      '$fileTime'                         // File creation time
      'A'                                 // File ID modifier
      '094'                               // Record size
      '10'                                // Blocking factor
      '1'                                 // Format code
      '${_pad('KleenOps Payroll', 23)}'   // Immediate destination name
      '$cleanName'                        // Immediate origin name
      '${_pad('', 8)}'                    // Reference code
    );

    // Batch Header Record (5)
    final batchNumber = '0000001';
    lines.add(
      '5'                                 // Record type
      '220'                               // Service class (220 = credits only)
      '$cleanName'                        // Company name (16 chars — use first 16)
      '${_pad('', 20)}'                   // Company discretionary data
      '$cleanEin'                         // Company identification
      'PPD'                               // SEC code (Prearranged Payment & Deposit)
      '${_pad('PAYROLL', 10)}'            // Company entry description
      '${_pad('', 6)}'                    // Company descriptive date
      '$effectiveDate'                    // Effective entry date
      '${_pad('', 3)}'                    // Settlement date (blank)
      '1'                                 // Originator status code
      '$originRoute'                      // Originating DFI
      '$batchNumber'                      // Batch number
    );

    // Entry Detail Records (6)
    int traceSeq = 1;
    double totalAmount = 0;
    int entryHash = 0;

    for (final entry in ddStubs) {
      final transCode = entry.accountType == 'savings' ? '32' : '22';
      final routingCheck = entry.routingNumber.substring(0, 8);
      final checkDigit = entry.routingNumber.substring(8, 9);
      final amountCents =
          (entry.amount * 100).round().toString().padLeft(10, '0');
      final acctNum = _pad(entry.accountNumber, 17);
      final recvName = _pad(entry.name, 22);
      final traceNum = '$originRoute${traceSeq.toString().padLeft(7, '0')}';

      lines.add(
        '6'                               // Record type
        '$transCode'                      // Transaction code
        '$routingCheck'                   // Receiving DFI routing (8 digits)
        '$checkDigit'                     // Check digit
        '$acctNum'                        // DFI account number
        '$amountCents'                    // Amount in cents
        '${_pad(entry.memberId, 15)}'     // Individual identification
        '$recvName'                       // Individual name
        '${_pad('', 2)}'                  // Discretionary data
        '0'                               // Addenda record indicator
        '$traceNum'                       // Trace number
      );

      totalAmount += entry.amount;
      entryHash += int.tryParse(routingCheck) ?? 0;
      traceSeq++;
    }

    // Batch Control Record (8)
    final entryCount = ddStubs.length;
    final totalCents =
        (totalAmount * 100).round().toString().padLeft(12, '0');
    final hashStr = (entryHash % 10000000000).toString().padLeft(10, '0');

    lines.add(
      '8'                                 // Record type
      '220'                               // Service class
      '${entryCount.toString().padLeft(6, '0')}' // Entry/addenda count
      '$hashStr'                          // Entry hash
      '${'0'.padLeft(12, '0')}'           // Total debit (0 for credits)
      '$totalCents'                       // Total credit
      '$cleanEin'                         // Company identification
      '${_pad('', 19)}'                   // Message authentication code
      '${_pad('', 6)}'                    // Reserved
      '$originRoute'                      // Originating DFI
      '$batchNumber'                      // Batch number
    );

    // File Control Record (9)
    lines.add(
      '9'                                 // Record type
      '000001'                            // Batch count
      '${_pad((((entryCount + 4) / 10).ceil()).toString(), 6)}' // Block count
      '${entryCount.toString().padLeft(8, '0')}' // Entry/addenda count
      '$hashStr'                          // Entry hash
      '${'0'.padLeft(12, '0')}'           // Total debit
      '$totalCents'                       // Total credit
      '${_pad('', 39)}'                   // Reserved
    );

    // Pad to blocking factor of 10
    while (lines.length % 10 != 0) {
      lines.add('9' * 94);
    }

    // Mark run as ACH-generated
    await FirebaseFirestore.instance.collection('payrollRun').doc(runId).update({
      'achFileGenerated': true,
      'achGeneratedAt': FieldValue.serverTimestamp(),
      'achEntryCount': entryCount,
      'achTotalAmount': _round(totalAmount),
    });

    return lines.join('\n');
  }

  String _pad(String s, int width) {
    if (s.length > width) return s.substring(0, width);
    return s.padRight(width);
  }

  double _round(double v) => (v * 100).roundToDouble() / 100;
}

class _AchEntry {
  final String routingNumber;
  final String accountNumber;
  final String accountType;
  final double amount;
  final String name;
  final String memberId;

  const _AchEntry({
    required this.routingNumber,
    required this.accountNumber,
    required this.accountType,
    required this.amount,
    required this.name,
    required this.memberId,
  });
}
