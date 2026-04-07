// lib/features/finances/services/finance_invoice_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_widgets/services/firestore_service.dart';

class FinanceInvoiceService {
  FinanceInvoiceService({FirestoreService? firestore})
      : _firestore = firestore ?? FirestoreService();

  final FirestoreService _firestore;

  /// Queries the invoice collection ordered by invoiceNumber descending,
  /// limit 1, and returns the next sequential number.
  Future<int> getNextInvoiceNumber(
    DocumentReference<Map<String, dynamic>> companyRef,
  ) async {
    final snap = await FirebaseFirestore.instance
        .collection('invoice')
        .orderBy('invoiceNumber', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return 1001;

    final lastNumber = snap.docs.first.data()['invoiceNumber'];
    if (lastNumber is int) return lastNumber + 1;
    if (lastNumber is num) return lastNumber.toInt() + 1;
    return 1001;
  }

  /// Creates an invoice with an auto-incremented invoiceNumber.
  /// Returns the new document reference.
  Future<DocumentReference<Map<String, dynamic>>> createInvoice(
    DocumentReference<Map<String, dynamic>> companyRef,
    Map<String, dynamic> data,
  ) async {
    final nextNumber = await getNextInvoiceNumber(companyRef);
    final invoiceCollection = FirebaseFirestore.instance.collection('invoice');
    final docRef = invoiceCollection.doc();

    final payload = Map<String, dynamic>.from(data);
    payload['invoiceNumber'] = nextNumber;

    await _firestore.saveDocument(
      collectionRef: invoiceCollection,
      data: payload,
      docId: docRef.id,
    );

    return docRef;
  }

  /// Updates the status field on an invoice document.
  Future<void> updateInvoiceStatus(
    DocumentReference<Map<String, dynamic>> invoiceRef,
    String newStatus,
  ) async {
    await invoiceRef.update({'status': newStatus});
  }

  /// Records a payment against an invoice.
  ///
  /// Updates amountPaid, amountDue, and status (partial or paid) on the
  /// invoice. Also creates a timeline journal entry (debit Cash, credit
  /// Revenue using the hardcoded timelineCategory 'jlXgbQiOKD3VjWd7AztM'),
  /// and creates a payment doc in company/payment collection.
  Future<void> recordPayment({
    required DocumentReference<Map<String, dynamic>> invoiceRef,
    required double amount,
    required DocumentReference<Map<String, dynamic>> companyRef,
  }) async {
    // Read the current invoice state.
    final invoiceSnap = await invoiceRef.get();
    final invoiceData = invoiceSnap.data();
    if (invoiceData == null) {
      throw StateError('Invoice document does not exist.');
    }

    final total = (invoiceData['total'] as num?)?.toDouble() ?? 0.0;
    final previouslyPaid =
        (invoiceData['amountPaid'] as num?)?.toDouble() ?? 0.0;
    final newAmountPaid = previouslyPaid + amount;
    final newAmountDue = total - newAmountPaid;

    String newStatus;
    if (newAmountDue <= 0) {
      newStatus = 'paid';
    } else if (newAmountPaid > 0) {
      newStatus = 'partial';
    } else {
      newStatus = invoiceData['status'] as String? ?? 'draft';
    }

    // Update the invoice.
    await invoiceRef.update({
      'amountPaid': newAmountPaid,
      'amountDue': newAmountDue < 0 ? 0 : newAmountDue,
      'status': newStatus,
    });

    // Create a timeline journal entry.
    final categoryRef = FirebaseFirestore.instance
        .collection('timelineCategory')
        .doc('jlXgbQiOKD3VjWd7AztM');

    final user = FirebaseAuth.instance.currentUser;
    final userRef = user != null
        ? FirebaseFirestore.instance.collection('user').doc(user.uid)
        : null;

    final invoiceNumber = invoiceData['invoiceNumber'] ?? '';
    final timelineData = <String, dynamic>{
      'createdAt': FieldValue.serverTimestamp(),
      'name': 'Payment for Invoice #$invoiceNumber',
      'amount': amount,
      'debitAccountId': null, // Cash — account mapping handled by bookkeeper
      'creditAccountId': null, // Revenue — account mapping handled by bookkeeper
      'timelineCategoryId': categoryRef,
      'timelineCategory': 'jlXgbQiOKD3VjWd7AztM',
      'invoiceId': invoiceRef,
      if (userRef != null) 'createdBy': userRef,
    };

    await _firestore.saveDocument(
      collectionRef: FirebaseFirestore.instance.collection('timeline'),
      data: timelineData,
    );

    // Create a payment document.
    final paymentData = <String, dynamic>{
      'createdAt': FieldValue.serverTimestamp(),
      'amount': amount,
      'invoiceId': invoiceRef,
      'invoiceNumber': invoiceNumber,
      'customerId': invoiceData['customerId'],
      'customerName': invoiceData['customerName'] ?? '',
      'method': 'manual',
      if (userRef != null) 'createdBy': userRef,
    };

    await _firestore.saveDocument(
      collectionRef: FirebaseFirestore.instance.collection('payment'),
      data: paymentData,
    );
  }

  /// Recalculates invoice subtotal and total from line items.
  Future<void> recalculateInvoiceTotals(
    DocumentReference<Map<String, dynamic>> invoiceRef,
  ) async {
    final lineItemsSnap = await invoiceRef.collection('lineItem').get();

    double subtotal = 0;
    for (final doc in lineItemsSnap.docs) {
      final data = doc.data();
      final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
      subtotal += amount;
    }

    final invoiceSnap = await invoiceRef.get();
    final invoiceData = invoiceSnap.data() ?? {};
    final tax = (invoiceData['tax'] as num?)?.toDouble() ?? 0.0;
    final total = subtotal + tax;
    final amountPaid =
        (invoiceData['amountPaid'] as num?)?.toDouble() ?? 0.0;
    final amountDue = total - amountPaid;

    await invoiceRef.update({
      'subtotal': subtotal,
      'total': total,
      'amountDue': amountDue < 0 ? 0 : amountDue,
    });
  }
}
