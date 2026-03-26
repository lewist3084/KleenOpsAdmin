// lib/features/finances/services/payment_link_service.dart
//
// Client-side service for generating Stripe payment links and
// sending them to billing contacts via SMS and email.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class PaymentLinkService {
  /// Creates a Stripe Checkout payment link for the given invoice
  /// and sends it to the customer's billing contact via email and/or SMS.
  ///
  /// Returns a map with:
  ///   - `paymentUrl` (String) — the Stripe Checkout URL
  ///   - `emailSent` (bool)
  ///   - `smsSent` (bool)
  Future<Map<String, dynamic>> createAndSendPaymentLink({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required DocumentReference<Map<String, dynamic>> invoiceRef,
    required Map<String, dynamic> invoiceData,
  }) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'financeSendPaymentLink',
    );

    final result = await callable.call<Map<String, dynamic>>({
      'companyId': companyRef.id,
      'invoiceId': invoiceRef.id,
    });

    return Map<String, dynamic>.from(result.data);
  }

  /// Sends a receipt notification for a completed payment.
  /// Called after Stripe webhook processes payment, or manually.
  Future<void> sendReceipt({
    required String companyId,
    required String invoiceId,
    required String paymentId,
  }) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'financeSendReceipt',
    );

    await callable.call({
      'companyId': companyId,
      'invoiceId': invoiceId,
      'paymentId': paymentId,
    });
  }
}
