import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_widgets/utils/process_localization_utils.dart';

import 'package:kleenops_admin/features/finances/services/finance_invoice_service.dart';

/// Generates a draft invoice (quote) from facility data.
///
/// The pipeline:
/// 1. Gather locations under a property/building (with room measurements).
/// 2. Gather company objects that have assigned processes.
/// 3. For each object-process, pull pre-calculated costs (labor, material, tool)
///    and apply a frequency multiplier.
/// 4. Roll up into invoice line items and create a draft invoice.
class QuoteGeneratorService {
  QuoteGeneratorService({
    FirebaseFirestore? firestore,
    FinanceInvoiceService? invoiceService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _invoiceService = invoiceService ?? FinanceInvoiceService();

  final FirebaseFirestore _firestore;
  final FinanceInvoiceService _invoiceService;

  /// Gathers all quotable data for a property (or building).
  ///
  /// Returns objects with their processes and locations, ready for the user
  /// to review, set frequencies, and generate a quote.
  Future<QuotePreviewData> gatherQuoteData({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required String propertyId,
    String? buildingId,
  }) async {
    // 1. Fetch locations under the property/building.
    var locationQuery = FirebaseFirestore.instance
        .collection('location')
        .where('propertyId',
            isEqualTo: FirebaseFirestore.instance.collection('property').doc(propertyId));

    if (buildingId != null) {
      locationQuery = locationQuery.where('buildingId',
          isEqualTo: FirebaseFirestore.instance.collection('building').doc(buildingId));
    }

    final locationSnap = await locationQuery.get();
    final locations = <QuoteLocation>[];
    for (final doc in locationSnap.docs) {
      final data = doc.data();
      locations.add(QuoteLocation(
        id: doc.id,
        name: (data['name'] as String?) ?? 'Unnamed',
        areaSquareFeet: _asDouble(data['standardFloorArea']),
        wallAreaSquareFeet: _asDouble(data['standardWallArea']),
        heightFeet: _asDouble(data['standardHeight']),
      ));
    }

    // 2. Fetch company objects linked to this property.
    //    Objects created via room detection have a propertyId field.
    //    We also include objects without a propertyId (manually created)
    //    so the user can optionally include them.
    final propertyRef = FirebaseFirestore.instance.collection('property').doc(propertyId);
    final propertyObjectSnap = await FirebaseFirestore.instance
        .collection('companyObject')
        .where('active', isEqualTo: true)
        .where('propertyId', isEqualTo: propertyRef)
        .get();

    // Also fetch objects without a propertyId (legacy / manually created).
    final unlinkedObjectSnap = await FirebaseFirestore.instance
        .collection('companyObject')
        .where('active', isEqualTo: true)
        .get();

    // Merge: property-linked first, then unlinked (deduped).
    final seenIds = <String>{};
    final allDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final doc in propertyObjectSnap.docs) {
      if (seenIds.add(doc.id)) allDocs.add(doc);
    }
    for (final doc in unlinkedObjectSnap.docs) {
      if (seenIds.add(doc.id)) allDocs.add(doc);
    }
    final objectSnap = allDocs;

    final objectIds = objectSnap.map((d) => d.id).toList();
    if (objectIds.isEmpty) {
      return QuotePreviewData(
        locations: locations,
        objectEntries: const [],
        propertyId: propertyId,
        buildingId: buildingId,
      );
    }

    // 3. Fetch all object processes.
    final processSnap = await FirebaseFirestore.instance.collection('objectProcess').get();

    // Group processes by object.
    final processesByObjectId = <String, List<QuoteObjectProcess>>{};
    for (final doc in processSnap.docs) {
      final data = doc.data();
      final objectRef = data['companyObjectId'];
      String? objectDocId;
      if (objectRef is DocumentReference) {
        objectDocId = objectRef.id;
      } else if (data['companyObjectDocId'] is String) {
        objectDocId = data['companyObjectDocId'] as String;
      }
      if (objectDocId == null) continue;

      final processName = _resolveProcessName(data);
      final laborCost =
          _asDouble(data['objectStandardLaborCost']) ??
          _asDouble(data['objectMetricLaborCost']) ??
          _asDouble(data['objectLaborCost']) ??
          0.0;
      final materialCost =
          _asDouble(data['objectStandardMaterialCost']) ??
          _asDouble(data['objectMetricMaterialCost']) ??
          _asDouble(data['objectMaterialCost']) ??
          0.0;
      final toolCost =
          _asDouble(data['objectStandardToolCost']) ??
          _asDouble(data['objectMetricToolCost']) ??
          _asDouble(data['objectToolCost']) ??
          0.0;
      final processTime =
          _asDouble(data['objectProcessTime']) ?? 0.0;
      final totalCost =
          _asDouble(data['objectStandardProcessCost']) ??
          _asDouble(data['objectMetricProcessCost']) ??
          _asDouble(data['objectProcessCost']) ??
          (laborCost + materialCost + toolCost);

      processesByObjectId.putIfAbsent(objectDocId, () => []).add(
        QuoteObjectProcess(
          processId: doc.id,
          processName: processName,
          processTimeMins: processTime,
          laborCost: laborCost,
          materialCost: materialCost,
          toolCost: toolCost,
          totalCostPerUnit: totalCost,
        ),
      );
    }

    // 4. Build object entries with their processes.
    final objectEntries = <QuoteObjectEntry>[];
    for (final doc in objectSnap) {
      final data = doc.data();
      final processes = processesByObjectId[doc.id];
      if (processes == null || processes.isEmpty) continue;

      // companyObject.localName + description may now be localized
      // maps. resolveLocalizedText is safe for String or Map and
      // prefers `en` → `source` → any value when no locale is in
      // scope (this service has no BuildContext).
      final resolvedName = ProcessLocalizationUtils.resolveLocalizedText(
        data['localName'],
        localeCode: ProcessLocalizationUtils.defaultLocaleCode,
      ).trim();
      final resolvedDescription = ProcessLocalizationUtils.resolveLocalizedText(
        data['description'],
        localeCode: ProcessLocalizationUtils.defaultLocaleCode,
      );
      objectEntries.add(QuoteObjectEntry(
        objectId: doc.id,
        objectName: resolvedName.isEmpty ? 'Unnamed' : resolvedName,
        description: resolvedDescription,
        processes: processes,
      ));
    }

    return QuotePreviewData(
      locations: locations,
      objectEntries: objectEntries,
      propertyId: propertyId,
      buildingId: buildingId,
    );
  }

  /// Generates a draft invoice from user-confirmed quote lines.
  ///
  /// Each [QuoteLineItem] becomes an invoice line item.
  Future<QuoteGenerationOutcome> generateQuote({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required DocumentReference<Map<String, dynamic>> customerRef,
    required String customerName,
    required String propertyId,
    String? buildingId,
    required List<QuoteLineItem> lineItems,
    double tax = 0.0,
    String notes = '',
  }) async {
    if (lineItems.isEmpty) {
      throw QuoteGeneratorException('No line items provided.');
    }

    // Calculate subtotal.
    double subtotal = 0;
    for (final item in lineItems) {
      subtotal += item.amount;
    }
    final total = subtotal + tax;

    // Create the draft invoice.
    final invoiceData = <String, dynamic>{
      'customerId': customerRef,
      'customerName': customerName,
      'status': 'draft',
      'issueDate': Timestamp.now(),
      'dueDate': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 30)),
      ),
      'tax': tax,
      'subtotal': subtotal,
      'total': total,
      'amountPaid': 0.0,
      'amountDue': total,
      'notes': notes,
      'source': 'quote_generator',
      'propertyId': FirebaseFirestore.instance.collection('property').doc(propertyId),
      if (buildingId != null)
        'buildingId': FirebaseFirestore.instance.collection('building').doc(buildingId),
      'createdAt': FieldValue.serverTimestamp(),
    };

    final invoiceRef =
        await _invoiceService.createInvoice(companyRef, invoiceData);

    // Create line items.
    final batch = _firestore.batch();
    final lineItemCollection = invoiceRef.collection('lineItem');
    for (var i = 0; i < lineItems.length; i++) {
      final item = lineItems[i];
      final docRef = lineItemCollection.doc();
      batch.set(docRef, {
        'description': item.description,
        'quantity': item.quantity,
        'unitPrice': item.unitPrice,
        'amount': item.amount,
        'position': i,
        'createdAt': FieldValue.serverTimestamp(),
        if (item.objectId != null) 'objectId': item.objectId,
        if (item.processId != null) 'processId': item.processId,
        if (item.frequency != null) 'frequency': item.frequency,
      });
    }
    await batch.commit();

    return QuoteGenerationOutcome(
      invoiceRef: invoiceRef,
      lineItemCount: lineItems.length,
      subtotal: subtotal,
      total: total,
    );
  }

  String _resolveProcessName(Map<String, dynamic> data) {
    final name = data['processName'] ?? data['name'];
    if (name is String) {
      final trimmed = name.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    if (name is Map) {
      final en = name['en'] ?? name['en-US'];
      if (en is String && en.trim().isNotEmpty) return en.trim();
      for (final value in name.values) {
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
    }
    return 'Unnamed Process';
  }

  static double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

// ─── Data Models ────────────────────────────────────────────────────────────

class QuotePreviewData {
  const QuotePreviewData({
    required this.locations,
    required this.objectEntries,
    required this.propertyId,
    this.buildingId,
  });

  final List<QuoteLocation> locations;
  final List<QuoteObjectEntry> objectEntries;
  final String propertyId;
  final String? buildingId;
}

class QuoteLocation {
  const QuoteLocation({
    required this.id,
    required this.name,
    this.areaSquareFeet,
    this.wallAreaSquareFeet,
    this.heightFeet,
  });

  final String id;
  final String name;
  final double? areaSquareFeet;
  final double? wallAreaSquareFeet;
  final double? heightFeet;
}

class QuoteObjectEntry {
  QuoteObjectEntry({
    required this.objectId,
    required this.objectName,
    required this.description,
    required this.processes,
  });

  final String objectId;
  final String objectName;
  final String description;
  final List<QuoteObjectProcess> processes;

  /// Whether user has included this object in the quote.
  bool included = true;
}

class QuoteObjectProcess {
  QuoteObjectProcess({
    required this.processId,
    required this.processName,
    required this.processTimeMins,
    required this.laborCost,
    required this.materialCost,
    required this.toolCost,
    required this.totalCostPerUnit,
  });

  final String processId;
  final String processName;
  final double processTimeMins;
  final double laborCost;
  final double materialCost;
  final double toolCost;
  final double totalCostPerUnit;

  /// How many times per month this process is performed.
  /// User sets this during quote review.
  int frequencyPerMonth = 1;
}

class QuoteLineItem {
  const QuoteLineItem({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.amount,
    this.objectId,
    this.processId,
    this.frequency,
  });

  final String description;
  final double quantity;
  final double unitPrice;
  final double amount;
  final String? objectId;
  final String? processId;
  final String? frequency;
}

class QuoteGenerationOutcome {
  const QuoteGenerationOutcome({
    required this.invoiceRef,
    required this.lineItemCount,
    required this.subtotal,
    required this.total,
  });

  final DocumentReference invoiceRef;
  final int lineItemCount;
  final double subtotal;
  final double total;
}

class QuoteGeneratorException implements Exception {
  QuoteGeneratorException(this.message);
  final String message;

  @override
  String toString() => 'QuoteGeneratorException: $message';
}
