import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_widgets/services/firestore_service.dart';

class FinanceAccountService {
  FinanceAccountService({FirestoreService? firestore})
      : _firestore = firestore ?? FirestoreService();

  final FirestoreService _firestore;

  Future<DocumentReference<Map<String, dynamic>>> createAccount({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required String name,
    DocumentReference<Map<String, dynamic>>? parentAccountRef,
    DocumentReference<Map<String, dynamic>>? profitLossRef,
    DocumentReference<Map<String, dynamic>>? balanceSheetRef,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Account name cannot be empty.');
    }

    final accountsCollection = FirebaseFirestore.instance.collection('account');
    final accountRef = accountsCollection.doc();
    final data = <String, dynamic>{
      'name': trimmedName,
      'parentAccountId': parentAccountRef,
    };

    if (parentAccountRef != null) {
      await _applyParentAttributes(
        parentAccountRef: parentAccountRef,
        target: data,
        overrideProfitLossRef: profitLossRef,
        overrideBalanceSheetRef: balanceSheetRef,
      );
      final position = await _nextPosition(
        accountsCollection.where(
          'parentAccountId',
          isEqualTo: parentAccountRef,
        ),
      );
      if (position != null) {
        data['position'] = position;
      }
    } else {
      data['parentAccountId'] = null;
      if (profitLossRef != null) {
        data['profitLossId'] = profitLossRef;
        data['profitLoss'] = true;
      }
      if (balanceSheetRef != null) {
        data['balanceSheetId'] = balanceSheetRef;
        data['balanceSheet'] = true;
      }
      final query = _topLevelPositionQuery(
        accountsCollection,
        profitLossRef: profitLossRef,
        balanceSheetRef: balanceSheetRef,
      );
      final position = await _nextPosition(query);
      if (position != null) {
        data['position'] = position;
      }
    }

    await _firestore.saveDocument(
      collectionRef: accountsCollection,
      docId: accountRef.id,
      data: data,
    );
    return accountRef;
  }

  Future<void> deleteAccount(
    DocumentReference<Map<String, dynamic>> accountRef,
  ) async {
    await accountRef.delete();
  }

  Future<void> _applyParentAttributes({
    required DocumentReference<Map<String, dynamic>> parentAccountRef,
    required Map<String, dynamic> target,
    DocumentReference<Map<String, dynamic>>? overrideProfitLossRef,
    DocumentReference<Map<String, dynamic>>? overrideBalanceSheetRef,
  }) async {
    final parentSnap = await parentAccountRef.get();
    final parentData = parentSnap.data();
    if (parentData == null) {
      return;
    }

    final parentProfitLossId = parentData['profitLossId'] as DocumentReference?;
    final parentBalanceSheetId =
        parentData['balanceSheetId'] as DocumentReference?;
    final parentProfitLoss = parentData['profitLoss'] == true;
    final parentBalanceSheet = parentData['balanceSheet'] == true;

    final profitLossId = overrideProfitLossRef ?? parentProfitLossId;
    final balanceSheetId = overrideBalanceSheetRef ?? parentBalanceSheetId;

    if (profitLossId != null) {
      target['profitLossId'] = profitLossId;
      target['profitLoss'] = true;
    } else if (parentProfitLoss) {
      target['profitLoss'] = true;
    }
    if (balanceSheetId != null) {
      target['balanceSheetId'] = balanceSheetId;
      target['balanceSheet'] = true;
    } else if (parentBalanceSheet) {
      target['balanceSheet'] = true;
    }
  }

  Query<Map<String, dynamic>> _topLevelPositionQuery(
    CollectionReference<Map<String, dynamic>> accountsCollection, {
    DocumentReference<Map<String, dynamic>>? profitLossRef,
    DocumentReference<Map<String, dynamic>>? balanceSheetRef,
  }) {
    Query<Map<String, dynamic>> query =
        accountsCollection.where('parentAccountId', isNull: true);

    if (profitLossRef != null) {
      query = query.where('profitLossId', isEqualTo: profitLossRef);
    } else if (balanceSheetRef != null) {
      query = query.where('balanceSheetId', isEqualTo: balanceSheetRef);
    }
    return query;
  }

  Future<int?> _nextPosition(Query<Map<String, dynamic>> query) async {
    try {
      final snap = await query.get();
      var maxPosition = 0;
      for (final doc in snap.docs) {
        final pos = doc.data()['position'];
        if (pos is num) {
          final intPos = pos.toInt();
          if (intPos > maxPosition) {
            maxPosition = intPos;
          }
        }
      }
      return maxPosition + 1;
    } catch (_) {
      return null;
    }
  }
}
