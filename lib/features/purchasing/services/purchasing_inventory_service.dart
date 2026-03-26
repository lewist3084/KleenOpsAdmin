import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kleenops_admin/services/firestore_service.dart';

class PurchasingInventoryService {
  PurchasingInventoryService({FirestoreService? firestore})
      : _firestore = firestore ?? FirestoreService();

  final FirestoreService _firestore;

  Future<DocumentReference<Map<String, dynamic>>> createPOFromFulfillment({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required String fulfillmentId,
  }) async {
    final fulfillmentRef = FirebaseFirestore.instance.collection('fulfillment').doc(fulfillmentId);
    final fulfillmentSnap = await fulfillmentRef.get();
    final fulfillmentData = fulfillmentSnap.data();
    if (fulfillmentData == null) {
      throw StateError('Fulfillment $fulfillmentId not found');
    }

    final poCollection = FirebaseFirestore.instance.collection('purchaseOrder');
    final poRef = poCollection.doc();
    final nextPoNumber = await _getNextPoNumber(companyRef);

    await _firestore.saveDocument(
      collectionRef: poCollection,
      docId: poRef.id,
      data: {
        'poNumber': nextPoNumber,
        'status': 'draft',
        'fulfillmentId': fulfillmentRef,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    final itemSnap = await fulfillmentRef.collection('fulfillmentItem').get();
    var subtotal = 0.0;

    for (var i = 0; i < itemSnap.docs.length; i++) {
      final item = itemSnap.docs[i].data();
      final objectRef = item['companyObjectId'];
      if (objectRef is! DocumentReference) continue;

      final objectTyped = FirebaseFirestore.instance.collection('companyObject').doc(objectRef.id);
      final objectDoc = await objectTyped.get();
      final objectData = objectDoc.data() ?? <String, dynamic>{};
      final objectName =
          (objectData['localName'] ?? objectData['name'] ?? objectTyped.id).toString();
      final quantity = _asDouble(item['requestedQuantity'], fallback: 1);
      final unitPrice = _asDouble(
        objectData['currentPrice'],
        fallback: _asDouble(item['price'], fallback: 0),
      );
      final amount = quantity * unitPrice;
      subtotal += amount;

      await _firestore.saveDocument(
        collectionRef: poRef.collection('lineItem'),
        data: {
          'description': objectName,
          'objectName': objectName,
          'companyObjectId': objectTyped,
          'quantity': quantity,
          'unitPrice': unitPrice,
          'amount': amount,
          'position': i,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );
    }

    await poRef.set(
      {
        'purchaseOrderSubtotal': subtotal,
        'purchaseOrderTotal': subtotal,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    return poRef;
  }

  Future<void> importInventoryRequestItems({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required DocumentReference<Map<String, dynamic>> poRef,
    required String inventoryRequestId,
  }) async {
    final requestRef = FirebaseFirestore.instance.collection('inventoryRequest').doc(inventoryRequestId);
    final existingLineItems = await poRef.collection('lineItem').get();
    var position = existingLineItems.docs.length;

    final timelineSnap = await FirebaseFirestore.instance
        .collection('timeline')
        .where('inventoryRequestId', isEqualTo: requestRef)
        .get();

    for (final timelineDoc in timelineSnap.docs) {
      final item = timelineDoc.data();
      final objectRef = item['companyObjectId'];
      if (objectRef is! DocumentReference) continue;

      final objectTyped = FirebaseFirestore.instance.collection('companyObject').doc(objectRef.id);
      final objectDoc = await objectTyped.get();
      final objectData = objectDoc.data() ?? <String, dynamic>{};
      final objectName =
          (objectData['localName'] ?? objectData['name'] ?? objectTyped.id).toString();
      final quantity = _asDouble(item['quantity'], fallback: 1);
      final unitPrice = _asDouble(objectData['currentPrice'], fallback: 0);
      final amount = quantity * unitPrice;

      await _firestore.saveDocument(
        collectionRef: poRef.collection('lineItem'),
        data: {
          'description': objectName,
          'objectName': objectName,
          'companyObjectId': objectTyped,
          'inventoryRequestId': requestRef,
          'sourceTimelineItemId': timelineDoc.reference,
          'quantity': quantity,
          'unitPrice': unitPrice,
          'amount': amount,
          'position': position++,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );
    }

    await _recalculatePoTotal(poRef);
  }

  Future<int> _getNextPoNumber(DocumentReference<Map<String, dynamic>> companyRef) async {
    final snap = await FirebaseFirestore.instance
        .collection('purchaseOrder')
        .orderBy('poNumber', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return 1001;
    final raw = snap.docs.first.data()['poNumber'];
    if (raw is int) return raw + 1;
    if (raw is num) return raw.toInt() + 1;
    return 1001;
  }

  Future<void> _recalculatePoTotal(DocumentReference<Map<String, dynamic>> poRef) async {
    final lines = await poRef.collection('lineItem').get();
    var subtotal = 0.0;
    for (final line in lines.docs) {
      subtotal += _asDouble(line.data()['amount']);
    }
    await poRef.set(
      {
        'purchaseOrderSubtotal': subtotal,
        'purchaseOrderTotal': subtotal,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  double _asDouble(dynamic value, {double fallback = 0.0}) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }
}
