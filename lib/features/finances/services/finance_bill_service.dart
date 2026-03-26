// lib/features/finances/services/finance_bill_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kleenops_admin/services/firestore_service.dart';

class FinanceBillService {
  FinanceBillService({FirestoreService? firestore})
      : _firestore = firestore ?? FirestoreService();

  final FirestoreService _firestore;

  /// Records a payment against a bill.
  ///
  /// Updates the bill's `amountPaid` and `status`, creates a payment document
  /// of type 'made', and posts a journal entry (debit Expense, credit Cash)
  /// under the `timeline` collection with timelineCategory
  /// 'jlXgbQiOKD3VjWd7AztM'.
  Future<void> recordBillPayment({
    required DocumentReference<Map<String, dynamic>> billRef,
    required double amount,
    required DocumentReference<Map<String, dynamic>> companyRef,
    required DocumentReference<Map<String, dynamic>> accountRef,
  }) async {
    // 1. Read current bill data.
    final billSnap = await billRef.get();
    final billData = billSnap.data();
    if (billData == null) {
      throw StateError('Bill does not exist.');
    }

    final total = (billData['total'] as num?)?.toDouble() ?? 0.0;
    final previouslyPaid =
        (billData['amountPaid'] as num?)?.toDouble() ?? 0.0;
    final newAmountPaid = previouslyPaid + amount;

    // Determine new status.
    String newStatus;
    if (newAmountPaid >= total) {
      newStatus = 'paid';
    } else if (newAmountPaid > 0) {
      newStatus = 'partial';
    } else {
      newStatus = 'unpaid';
    }

    // 2. Update bill.
    await billRef.update({
      'amountPaid': newAmountPaid,
      'status': newStatus,
    });

    // 3. Create payment document.
    final billNumber = billData['billNumber'] ?? '';
    final vendorName = billData['vendorName'] ?? '';

    await _firestore.saveDocument(
      collectionRef: FirebaseFirestore.instance.collection('payment'),
      data: {
        'amount': amount,
        'type': 'made',
        'method': 'transfer',
        'billId': billRef,
        'billNumber': billNumber,
        'vendorName': vendorName,
        'accountId': accountRef,
        'notes': 'Payment for bill #$billNumber',
      },
    );

    // 4. Create journal entry (timeline).
    final categoryRef = FirebaseFirestore.instance
        .collection('timelineCategory')
        .doc('jlXgbQiOKD3VjWd7AztM');

    final user = FirebaseAuth.instance.currentUser;
    final userRef = user != null
        ? FirebaseFirestore.instance.collection('user').doc(user.uid)
        : null;

    await _firestore.saveDocument(
      collectionRef: FirebaseFirestore.instance.collection('timeline'),
      data: {
        'name': 'Bill payment: #$billNumber - $vendorName',
        'amount': amount,
        'debitAccountId': accountRef, // Expense account
        'creditAccountId': accountRef, // Cash / payment account
        'timelineCategoryId': categoryRef,
        'timelineCategory': 'jlXgbQiOKD3VjWd7AztM',
        'billId': billRef,
        'type': 'bill_payment',
        if (userRef != null) 'createdBy': userRef,
      },
    );
  }
}
