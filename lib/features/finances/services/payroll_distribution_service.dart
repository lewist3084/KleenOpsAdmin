// lib/features/finances/services/payroll_distribution_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:kleenops_admin/features/finances/services/pay_stub_pdf_service.dart';

/// Distributes pay stubs to employees via email after payroll processing.
///
/// Uses a Cloud Function to send emails with PDF attachments.
/// Falls back to storing the PDF in Firebase Storage for employee download.
class PayrollDistributionService {
  final _pdfService = PayStubPdfService();

  /// Sends pay stub emails to all employees in a payroll run.
  ///
  /// Returns the count of emails sent.
  Future<int> distributePayStubs({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required String runId,
  }) async {
    // Load run data
    final runSnap =
        await FirebaseFirestore.instance.collection('payrollRun').doc(runId).get();
    final runData = runSnap.data() ?? {};

    // Convert timestamps for PDF
    final runDataForPdf = <String, dynamic>{};
    for (final e in runData.entries) {
      if (e.value is Timestamp) {
        runDataForPdf[e.key] = (e.value as Timestamp).toDate();
      } else {
        runDataForPdf[e.key] = e.value;
      }
    }

    // Load all pay stubs
    final stubsSnap = await FirebaseFirestore.instance
        .collection('payrollRun')
        .doc(runId)
        .collection('payStub')
        .get();

    int sent = 0;
    final errors = <String>[];

    for (final stubDoc in stubsSnap.docs) {
      final stubData = stubDoc.data();
      final memberId = stubDoc.id;

      // Load member email
      final memberSnap =
          await FirebaseFirestore.instance.collection('member').doc(memberId).get();
      final memberData = memberSnap.data();
      if (memberData == null) continue;

      final email = (memberData['email'] ?? '').toString();
      if (email.isEmpty) continue;

      try {
        // Generate PDF
        final pdfBytes = _pdfService.generatePayStubPdf(
          stubData: stubData,
          runData: runDataForPdf,
        );

        // Call Cloud Function to send email with PDF attachment
        final callable = FirebaseFunctions.instance
            .httpsCallable('sendPayStubEmail');
        await callable.call({
          'companyId': companyRef.id,
          'memberId': memberId,
          'email': email,
          'memberName': stubData['memberName'] ?? '',
          'runId': runId,
          'netPay': stubData['netPay'],
          'payDate': runData['payDate']?.toString(),
          // PDF sent as base64 or stored in Cloud Storage by the function
          'pdfBase64': _bytesToBase64(pdfBytes),
        });

        sent++;
      } catch (e) {
        errors.add('${stubData['memberName']}: $e');
      }
    }

    // Update run with distribution info
    await FirebaseFirestore.instance.collection('payrollRun').doc(runId).update({
      'emailsSent': sent,
      'emailErrors': errors.isNotEmpty ? errors : FieldValue.delete(),
      'distributedAt': FieldValue.serverTimestamp(),
    });

    return sent;
  }

  /// Distributes pay stubs for a single employee.
  Future<bool> distributeToEmployee({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required String runId,
    required String memberId,
  }) async {
    final stubSnap = await FirebaseFirestore.instance
        .collection('payrollRun')
        .doc(runId)
        .collection('payStub')
        .doc(memberId)
        .get();
    if (!stubSnap.exists) return false;

    final memberSnap =
        await FirebaseFirestore.instance.collection('member').doc(memberId).get();
    final memberData = memberSnap.data();
    if (memberData == null) return false;

    final email = (memberData['email'] ?? '').toString();
    if (email.isEmpty) return false;

    final runSnap =
        await FirebaseFirestore.instance.collection('payrollRun').doc(runId).get();
    final runData = runSnap.data() ?? {};
    final runDataForPdf = <String, dynamic>{};
    for (final e in runData.entries) {
      if (e.value is Timestamp) {
        runDataForPdf[e.key] = (e.value as Timestamp).toDate();
      } else {
        runDataForPdf[e.key] = e.value;
      }
    }

    final pdfBytes = _pdfService.generatePayStubPdf(
      stubData: stubSnap.data()!,
      runData: runDataForPdf,
    );

    final callable =
        FirebaseFunctions.instance.httpsCallable('sendPayStubEmail');
    await callable.call({
      'companyId': companyRef.id,
      'memberId': memberId,
      'email': email,
      'memberName': stubSnap.data()!['memberName'] ?? '',
      'runId': runId,
      'netPay': stubSnap.data()!['netPay'],
      'pdfBase64': _bytesToBase64(pdfBytes),
    });

    return true;
  }

  String _bytesToBase64(List<int> bytes) {
    // Use Dart's base64 encoder
    final buffer = StringBuffer();
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    int i = 0;
    while (i < bytes.length) {
      final b0 = bytes[i++];
      final b1 = i < bytes.length ? bytes[i++] : 0;
      final b2 = i < bytes.length ? bytes[i++] : 0;
      buffer.write(chars[(b0 >> 2) & 0x3F]);
      buffer.write(chars[((b0 << 4) | (b1 >> 4)) & 0x3F]);
      buffer.write(
          i - 1 < bytes.length ? chars[((b1 << 2) | (b2 >> 6)) & 0x3F] : '=');
      buffer.write(i < bytes.length ? chars[b2 & 0x3F] : '=');
    }
    return buffer.toString();
  }
}
