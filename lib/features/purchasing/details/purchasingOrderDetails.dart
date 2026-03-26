//  purchasingOrderDetails.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kleenops_admin/services/tenant_firebase_service.dart';
import 'package:intl/intl.dart';

import 'package:kleenops_admin/services/firestore_service.dart';
import 'package:kleenops_admin/services/storage_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'dart:typed_data';
import 'package:shared_widgets/dialogs/dialog_select.dart';
import 'package:shared_widgets/search/search_field_action.dart';
import 'package:shared_widgets/tiles/image_text_checkbox.dart';
import 'package:kleenops_admin/widgets/viewers/live_barcode_scanner_page.dart';
import 'package:kleenops_admin/widgets/viewers/pdf_viewer.dart';
import 'package:kleenops_admin/widgets/viewers/image_viewer.dart';
import '../../objects/utils/company_object_file_images.dart';

import '../forms/purchasingOrdersForm.dart';
import 'package:shared_widgets/containers/container_header.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/labels/header_info_icon_value.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:kleenops_admin/widgets/tiles/purchase_order_item_tile.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';

class PurchasingOrderDetailsScreen extends StatefulWidget {
  final String companyId;
  final String docId;

  const PurchasingOrderDetailsScreen({
    super.key,
    required this.companyId,
    required this.docId,
  });

  @override
  State<PurchasingOrderDetailsScreen> createState() =>
      _PurchasingOrderDetailsScreenState();
}

class _PurchasingOrderDetailsScreenState
    extends State<PurchasingOrderDetailsScreen> {
  bool _taxable = false;
  final TextEditingController _shippingCtrl = TextEditingController();
  String? _paymentTerms;
  String? _shippingMethod;
  final TextEditingController _notesCtrl = TextEditingController();
  bool _initialized = false;
  bool _reviewed = false;
  bool _sent = false;
  final Map<String, Map<String, dynamic>> _objectCache = {};

  Future<void> _addPurchaseOrderItem(
      DocumentReference<Map<String, dynamic>> itemRef) async {
    final companyRef =
        TenantFirebaseService.instance.companyDoc(widget.companyId);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final indexSnap =
        await FirebaseFirestore.instance.collection('memberByUid').doc(user.uid).get();
    DocumentReference<Map<String, dynamic>>? memberRef;
    DocumentReference? teamRef;
    final indexData = indexSnap.data();
    if (indexData?['active'] == true) {
      final memberId = indexData?['memberId'] as String?;
      if (memberId != null && memberId.trim().isNotEmpty) {
        memberRef = FirebaseFirestore.instance.collection('member').doc(memberId.trim());
        final memberSnap = await memberRef.get();
        final memberData = memberSnap.data() ?? <String, dynamic>{};
        teamRef = memberData['primaryTeamId'] as DocumentReference?;
      }
    }

    final timelineCollection = FirebaseFirestore.instance.collection('timeline').withConverter(
          fromFirestore: (s, _) => s.data() ?? {},
          toFirestore: (m, _) => m,
        );

    final purchaseOrderRef =
        FirebaseFirestore.instance.collection('purchaseOrder').doc(widget.docId);

    final objSnap = await itemRef.get();
    final price = (objSnap.data()?['currentPrice'] ?? 0).toDouble();

    final data = {
      'companyObjectId': itemRef,
      'quantity': 1,
      'price': price,
      'timelineCategory': 'uq6TbuShHCcPSgLJz8xQ',
      'timelineCategoryId': FirebaseFirestore.instance
          .collection('timelineCategory')
          .doc('uq6TbuShHCcPSgLJz8xQ'),
      'createdBy': memberRef,
      'createdByTeamId': teamRef,
      'purchaseOrderId': purchaseOrderRef,
      'createdAt': FieldValue.serverTimestamp(),
    };

    await FirestoreService().saveDocument(
      collectionRef: timelineCollection,
      data: data,
    );
  }

  Future<Map<String, dynamic>> _getObjectData(
      DocumentReference<Map<String, dynamic>> ref) async {
    if (_objectCache.containsKey(ref.id)) {
      return _objectCache[ref.id]!;
    }
    final snap = await ref.get();
    final data = snap.data() ?? {};
    _objectCache[ref.id] = data;
    return data;
  }

  Future<void> _editItemPrice(
      BuildContext context,
      QueryDocumentSnapshot<Map<String, dynamic>> itemDoc,
      DocumentReference<Map<String, dynamic>> objRef,
      double price) async {
    final priceCtrl = TextEditingController(text: price.toStringAsFixed(2));
    bool updateCurrent = false;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setD) => DialogAction(
          title: 'Price',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: priceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Price'),
              ),
              Row(
                children: [
                  Checkbox(
                    value: updateCurrent,
                    onChanged: (v) => setD(() => updateCurrent = v ?? false),
                  ),
                  const Text('New Current Price'),
                ],
              ),
            ],
          ),
          cancelText: 'Cancel',
          onCancel: () => Navigator.of(ctx2).pop(),
          actionText: 'Save',
          onAction: () async {
            final val = double.tryParse(priceCtrl.text.trim());
            if (val != null) {
              await itemDoc.reference.update({'price': val});
              if (updateCurrent) {
                await objRef.update({'currentPrice': val});
                if (_objectCache.containsKey(objRef.id)) {
                  _objectCache[objRef.id]!['currentPrice'] = val;
                }
              }
            }
            if (ctx2.mounted) Navigator.of(ctx2).pop();
          },
        ),
      ),
    );
    priceCtrl.dispose();
  }

  Future<_PurchaseOrderData?> _loadData() async {
    final docRef = FirebaseFirestore.instance
        .collection('company')
        .doc(widget.companyId)
        .collection('purchaseOrder')
        .doc(widget.docId);
    final snap = await docRef.get();
    if (!snap.exists) return null;
    final data = snap.data() ?? {};

    String vendor = '';
    final vendorRef = data['vendorId'];
    if (vendorRef is DocumentReference) {
      final vsnap = await vendorRef.get();
      vendor =
          (vsnap.data() as Map<String, dynamic>? ?? {})['name'] as String? ??
              '';
    }

    String team = '';
    final teamRef = data['teamId'];
    if (teamRef is DocumentReference) {
      final tsnap = await teamRef.get();
      team = (tsnap.data() as Map<String, dynamic>? ?? {})['name'] as String? ??
          '';
    }

    String poContact = '';
    final poContactRef = data['poContactId'];
    if (poContactRef is DocumentReference) {
      final psnap = await poContactRef.get();
      poContact =
          (psnap.data() as Map<String, dynamic>? ?? {})['name'] as String? ??
              '';
    }

    String vendorContact = '';
    final vendorContactRef = data['vendorContactId'];
    if (vendorContactRef is DocumentReference) {
      final vcsnap = await vendorContactRef.get();
      vendorContact =
          (vcsnap.data() as Map<String, dynamic>? ?? {})['name'] as String? ??
              '';
    }

    final poNumber = data['poNumber']?.toString() ?? '';
    final createdAt = data['createdAt'] is Timestamp
        ? DateFormat('yMMMd').format((data['createdAt'] as Timestamp).toDate())
        : '';
    final pdfUrl = data['purchaseOrderPDF']?.toString();
    final sent =
        data['purchaseOrderSent'] == true || data['purchaseOrderScent'] == true;
    final taxable = data['taxable'] == true;
    final billingMap = data['billingAddress'] as Map<String, dynamic>? ?? {};
    final shipMap = data['shipToAddress'] as Map<String, dynamic>? ?? {};
    final billingAddress = [
      billingMap['address'],
      billingMap['city'],
      billingMap['state'],
      billingMap['zip']
    ].whereType<String>().where((e) => e.isNotEmpty).join(', ');
    final shipToAddress = [
      shipMap['address'],
      shipMap['city'],
      shipMap['state'],
      shipMap['zip']
    ].whereType<String>().where((e) => e.isNotEmpty).join(', ');
    final shippingHandling = (data['shippingHandling'] ?? 0).toDouble();
    final paymentTerms = data['paymentTerms']?.toString();
    final shippingMethod = data['shippingMethod']?.toString();
    final notes = data['notes']?.toString();

    return _PurchaseOrderData(
      vendor: vendor,
      vendorContact: vendorContact,
      team: team,
      poContact: poContact,
      poNumber: poNumber,
      createdAt: createdAt,
      pdfUrl: pdfUrl,
      taxable: taxable,
      billingAddress: billingAddress,
      shipToAddress: shipToAddress,
      shippingHandling: shippingHandling,
      sent: sent,
      paymentTerms: paymentTerms,
      shippingMethod: shippingMethod,
      notes: notes,
    );
  }

  Future<void> _showAddItemDialog(BuildContext context) async {
    final companyRef =
        TenantFirebaseService.instance.companyDoc(widget.companyId);

    // Fetch company objects for the dropdown
    final snap =
        await FirebaseFirestore.instance.collection('companyObject').orderBy('localName').get();
    final docs = snap.docs;
    if (docs.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No company objects found.')),
        );
      }
      return;
    }

    DocumentReference<Map<String, dynamic>>? selected;
    final searchCtrl = TextEditingController();
    String query = '';

    List<QueryDocumentSnapshot<Map<String, dynamic>>> filtered() => docs
        .where((d) => ((d.data()['localName'] ?? d.id).toString())
            .toLowerCase()
            .contains(query.toLowerCase()))
        .toList();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setD) {
          final list = filtered();
          return DialogAction(
            title: 'Item',
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SearchFieldAction(
                  controller: searchCtrl,
                  labelText: 'Search',
                  onChanged: (v) => setD(() => query = v),
                  actionIcon: const Icon(Icons.qr_code_scanner),
                  actionTooltip: 'Scan',
                  onAction: () async {
                    final code = await Navigator.of(ctx2).push<String>(
                      MaterialPageRoute(
                          builder: (_) => const LiveBarcodeScannerPage()),
                    );
                    if (code == null || code.isEmpty) return;
                    for (final d in docs) {
                      final bc = d.data()['objectBarcode']?.toString();
                      if (bc != null && bc.trim() == code.trim()) {
                        await _addPurchaseOrderItem(d.reference);
                        if (ctx2.mounted) Navigator.of(ctx2).pop();
                        return;
                      }
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Item not found')),
                      );
                    }
                  },
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final d = list[i];
                      final objData = d.data();
                      return FutureBuilder<String>(
                        future: CompanyObjectFileImages.primaryHeaderImageUrl(
                          companyRef: companyRef,
                          objectId: d.id,
                        ),
                        builder: (context, imageSnap) {
                          final imageUrl = imageSnap.data ?? '';
                          return ImageTextCheckbox(
                            value: selected == d.reference,
                            onChanged: (v) => setD(
                              () => selected = v == true ? d.reference : null,
                            ),
                            label: (objData['localName'] ?? d.id).toString(),
                            imageUrl: imageUrl,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
            cancelText: 'Cancel',
            onCancel: () => Navigator.of(ctx2).pop(),
            actionText: 'Done',
            onAction: () async {
              if (selected == null) {
                ScaffoldMessenger.of(ctx2).showSnackBar(
                  const SnackBar(content: Text('Select item')),
                );
                return;
              }

              await _addPurchaseOrderItem(selected!);

              if (context.mounted) Navigator.of(ctx2).pop();
            },
          );
        },
      ),
    );

    searchCtrl.dispose();
  }

  Future<String?> _addPaymentTerm(String name, String? description) async {
    if (name.trim().isEmpty) return null;

    final col = FirebaseFirestore.instance
        .collection('company')
        .doc(widget.companyId)
        .collection('companyPaymentTerm');
    final meta = await FirestoreService().buildCreateMeta(col);
    final data = <String, dynamic>{
      'name': name.trim(),
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      ...meta,
    };
    await col.add(data);
    return name.trim();
  }

  Future<String?> _addShippingMethod(String name, String? description) async {
    if (name.trim().isEmpty) return null;

    final col = FirebaseFirestore.instance
        .collection('company')
        .doc(widget.companyId)
        .collection('companyShippingMethod');
    final meta = await FirestoreService().buildCreateMeta(col);
    final data = <String, dynamic>{
      'name': name.trim(),
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      ...meta,
    };
    await col.add(data);
    return name.trim();
  }

  Widget _wrapCanvas(Widget child) {
    return StandardCanvas(
      child: SafeArea(
        top: true,
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(child: child),
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: CanvasTopBookend(),
            ),
          ],
        ),
      ),
    );
  }

  // Calculates the total cost of all timeline items
  Future<double> _calculateTotal(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    double total = 0;
    for (final doc in docs) {
      final data = doc.data();
      final qty = data['quantity'] ?? 0;
      final quantity = qty is int ? qty : int.tryParse(qty.toString()) ?? 0;
      final objRef =
          data['companyObjectId'] as DocumentReference<Map<String, dynamic>>?;
      double price = (data['price'] ?? 0).toDouble();
      if (price == 0 && objRef != null) {
        final objSnap = await _getObjectData(objRef);
        price = (objSnap['currentPrice'] ?? 0).toDouble();
      }
      total += price * quantity;
    }
    return total;
  }

  Future<void> _deleteItem(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final ref = doc.reference;
    final oldData = doc.data();
    await ref.delete();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Item removed.'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () => ref.set(oldData),
        ),
      ),
    );
  }

  Future<Map<String, String>> _fetchContactInfo(
      DocumentReference<Map<String, dynamic>> ref) async {
    final snap = await ref.get();
    final data = snap.data() ?? {};
    final name = data['name']?.toString() ?? '';

    String phone = '';
    final phoneList = (data['phoneNumber'] as List<dynamic>? ?? []);
    Map<String, dynamic>? phoneMap;
    for (final p in phoneList) {
      if (p is Map && p['primary'] == true) {
        phoneMap = Map<String, dynamic>.from(p);
        break;
      }
    }
    if (phoneMap == null && phoneList.isNotEmpty) {
      final first = phoneList.first;
      if (first is Map) phoneMap = Map<String, dynamic>.from(first);
    }
    if (phoneMap != null) {
      phone = phoneMap['number']?.toString() ?? '';
    }

    String email = '';
    final emailList = (data['email'] as List<dynamic>? ?? []);
    Map<String, dynamic>? emailMap;
    for (final e in emailList) {
      if (e is Map && e['primary'] == true) {
        emailMap = Map<String, dynamic>.from(e);
        break;
      }
    }
    if (emailMap == null && emailList.isNotEmpty) {
      final first = emailList.first;
      if (first is Map) {
        emailMap = Map<String, dynamic>.from(first);
      } else if (first is String) {
        emailMap = {'email': first};
      }
    }
    if (emailMap != null) {
      email = emailMap['email']?.toString() ?? '';
    }

    return {'name': name, 'phone': phone, 'email': email};
  }

  Future<String?> _createPdf(BuildContext context) async {
    try {
      final companyRef = FirebaseFirestore.instance
          .collection('company')
          .doc(widget.companyId);
      final purchaseOrderRef =
          FirebaseFirestore.instance.collection('purchaseOrder').doc(widget.docId);

      final poSnap = await purchaseOrderRef.get();
      if (!poSnap.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order not found.')),
        );
        return null;
      }

      final poData = poSnap.data() ?? {};

      String vendorName = '';
      final vendorRef = poData['vendorId'];
      if (vendorRef is DocumentReference) {
        final vsnap = await vendorRef.get();
        vendorName =
            (vsnap.data() as Map<String, dynamic>? ?? {})['name']?.toString() ??
                '';
      }

      String teamName = '';
      final teamRef = poData['teamId'];
      if (teamRef is DocumentReference) {
        final tsnap = await teamRef.get();
        teamName =
            (tsnap.data() as Map<String, dynamic>? ?? {})['name']?.toString() ??
                '';
      }

      Map<String, String> poContactInfo = {
        'name': '',
        'phone': '',
        'email': ''
      };
      final poContactRef = poData['poContactId'];
      if (poContactRef is DocumentReference<Map<String, dynamic>>) {
        poContactInfo = await _fetchContactInfo(poContactRef);
      }

      Map<String, String> vendorContactInfo = {
        'name': '',
        'phone': '',
        'email': ''
      };
      final vendorContactRef = poData['vendorContactId'];
      if (vendorContactRef is DocumentReference<Map<String, dynamic>>) {
        vendorContactInfo = await _fetchContactInfo(vendorContactRef);
      }

      final billingMap =
          poData['billingAddress'] as Map<String, dynamic>? ?? {};
      final shipMap = poData['shipToAddress'] as Map<String, dynamic>? ?? {};
      final billingAddress = [
        billingMap['address'],
        billingMap['city'],
        billingMap['state'],
        billingMap['zip']
      ].whereType<String>().where((e) => e.isNotEmpty).join(', ');
      final shipToAddress = [
        shipMap['address'],
        shipMap['city'],
        shipMap['state'],
        shipMap['zip']
      ].whereType<String>().where((e) => e.isNotEmpty).join(', ');
      final taxable = poData['taxable'] == true;
      final shippingHandling = (poData['shippingHandling'] ?? 0).toDouble();
      final paymentTerms = poData['paymentTerms']?.toString() ?? '';
      final shippingMethod = poData['shippingMethod']?.toString() ?? '';
      final notes = poData['notes']?.toString() ?? '';

      final poNumber = poData['poNumber']?.toString() ?? '';
      final createdAt = poData['createdAt'] is Timestamp
          ? (poData['createdAt'] as Timestamp).toDate()
          : null;

      final categoryRef = FirebaseFirestore.instance
          .collection('timelineCategory')
          .doc('uq6TbuShHCcPSgLJz8xQ');
      final itemsSnap = await FirebaseFirestore.instance
          .collection('timeline')
          .where('timelineCategoryId', isEqualTo: categoryRef)
          .where('purchaseOrderId', isEqualTo: purchaseOrderRef)
          .orderBy('createdAt')
          .get();

      final PdfDocument document = PdfDocument();
      final PdfPage page = document.pages.add();
      final PdfFont headerFont = PdfStandardFont(PdfFontFamily.helvetica, 18,
          style: PdfFontStyle.bold);
      final PdfFont textFont = PdfStandardFont(PdfFontFamily.helvetica, 12);

      page.graphics.drawString(
        'Purchase Order',
        headerFont,
        bounds: Rect.fromLTWH(0, 0, page.getClientSize().width, 30),
      );

      double y = 40;
      page.graphics.drawString(
        'PO Number: $poNumber',
        textFont,
        bounds: Rect.fromLTWH(0, y, page.getClientSize().width, 20),
      );
      y += 20;
      if (createdAt != null) {
        page.graphics.drawString(
          'Date: ${DateFormat('yMMMd').format(createdAt)}',
          textFont,
          bounds: Rect.fromLTWH(0, y, page.getClientSize().width, 20),
        );
        y += 20;
      }
      if (teamName.isNotEmpty) {
        page.graphics.drawString(
          'Team: $teamName',
          textFont,
          bounds: Rect.fromLTWH(0, y, page.getClientSize().width, 20),
        );
        y += 20;
      }
      if (poContactInfo['name']!.isNotEmpty) {
        page.graphics.drawString(
          'PO Contact: ${poContactInfo['name']}',
          textFont,
          bounds: Rect.fromLTWH(0, y, page.getClientSize().width, 20),
        );
        y += 20;
        if (poContactInfo['phone']!.isNotEmpty) {
          page.graphics.drawString(
            'Phone: ${poContactInfo['phone']}',
            textFont,
            bounds: Rect.fromLTWH(0, y, page.getClientSize().width, 20),
          );
          y += 20;
        }
        if (poContactInfo['email']!.isNotEmpty) {
          page.graphics.drawString(
            'Email: ${poContactInfo['email']}',
            textFont,
            bounds: Rect.fromLTWH(0, y, page.getClientSize().width, 20),
          );
          y += 20;
        }
      }
      if (shipToAddress.isNotEmpty) {
        page.graphics.drawString(
          'Ship To: $shipToAddress',
          textFont,
          bounds: Rect.fromLTWH(0, y, page.getClientSize().width, 20),
        );
        y += 20;
      }
      if (vendorName.isNotEmpty) {
        page.graphics.drawString(
          'Vendor: $vendorName',
          textFont,
          bounds: Rect.fromLTWH(0, y, page.getClientSize().width, 20),
        );
        y += 20;
      }
      if (vendorContactInfo['name']!.isNotEmpty) {
        page.graphics.drawString(
          'Vendor Contact: ${vendorContactInfo['name']}',
          textFont,
          bounds: Rect.fromLTWH(0, y, page.getClientSize().width, 20),
        );
        y += 20;
        if (vendorContactInfo['phone']!.isNotEmpty) {
          page.graphics.drawString(
            'Phone: ${vendorContactInfo['phone']}',
            textFont,
            bounds: Rect.fromLTWH(0, y, page.getClientSize().width, 20),
          );
          y += 20;
        }
        if (vendorContactInfo['email']!.isNotEmpty) {
          page.graphics.drawString(
            'Email: ${vendorContactInfo['email']}',
            textFont,
            bounds: Rect.fromLTWH(0, y, page.getClientSize().width, 20),
          );
          y += 20;
        }
      }
      if (billingAddress.isNotEmpty) {
        page.graphics.drawString(
          'Billing Address: $billingAddress',
          textFont,
          bounds: Rect.fromLTWH(0, y, page.getClientSize().width, 20),
        );
        y += 30;
      } else {
        y += 10;
      }

      final PdfGrid grid = PdfGrid();
      grid.columns.add(count: 4);
      grid.headers.add(1);
      grid.headers[0].cells[0].value = 'Item';
      grid.headers[0].cells[1].value = 'Qty';
      grid.headers[0].cells[2].value = 'Price';
      grid.headers[0].cells[3].value = 'Total';

      double subtotal = 0;

      for (final doc in itemsSnap.docs) {
        final data = doc.data();
        final qtyRaw = data['quantity'] ?? 0;
        final quantity =
            qtyRaw is int ? qtyRaw : int.tryParse(qtyRaw.toString()) ?? 0;
        final objRef =
            data['companyObjectId'] as DocumentReference<Map<String, dynamic>>?;
        String itemName = '';
        double price = (data['price'] ?? 0).toDouble();
        if (objRef != null) {
          final objData = await _getObjectData(objRef);
          itemName = objData['localName']?.toString() ?? objRef.id;
          if (price == 0) {
            price = (objData['currentPrice'] ?? 0).toDouble();
          }
        }
        final total = price * quantity;
        subtotal += total;
        final row = grid.rows.add();
        row.cells[0].value = itemName;
        row.cells[1].value = quantity.toString();
        row.cells[2].value = '\$${price.toStringAsFixed(2)}';
        row.cells[3].value = '\$${total.toStringAsFixed(2)}';
      }

      grid.style = PdfGridStyle(
        cellPadding: PdfPaddings(left: 2, right: 2, top: 4, bottom: 4),
        font: textFont,
      );
      final gridResult =
          grid.draw(page: page, bounds: Rect.fromLTWH(0, y, 0, 0))!;

      double summaryY = gridResult.bounds.bottom + 20;
      final grandTotal = subtotal + shippingHandling;
      page.graphics.drawString(
        'Subtotal: \$${subtotal.toStringAsFixed(2)}',
        textFont,
        bounds: Rect.fromLTWH(0, summaryY, page.getClientSize().width, 20),
      );
      summaryY += 20;
      page.graphics.drawString(
        'Tax Status: ${taxable ? 'Taxable' : 'Tax Exempt'}',
        textFont,
        bounds: Rect.fromLTWH(0, summaryY, page.getClientSize().width, 20),
      );
      summaryY += 20;
      page.graphics.drawString(
        'Shipping & Handling: \$${shippingHandling.toStringAsFixed(2)}',
        textFont,
        bounds: Rect.fromLTWH(0, summaryY, page.getClientSize().width, 20),
      );
      summaryY += 20;
      page.graphics.drawString(
        'Grand Total: \$${grandTotal.toStringAsFixed(2)}',
        textFont,
        bounds: Rect.fromLTWH(0, summaryY, page.getClientSize().width, 20),
      );
      summaryY += 20;
      if (paymentTerms.isNotEmpty) {
        page.graphics.drawString(
          'Payment Terms: $paymentTerms',
          textFont,
          bounds: Rect.fromLTWH(0, summaryY, page.getClientSize().width, 20),
        );
        summaryY += 20;
      }
      if (shippingMethod.isNotEmpty) {
        page.graphics.drawString(
          'Shipping Method: $shippingMethod',
          textFont,
          bounds: Rect.fromLTWH(0, summaryY, page.getClientSize().width, 20),
        );
        summaryY += 20;
      }
      if (notes.isNotEmpty) {
        final noteElement =
            PdfTextElement(text: 'Notes: $notes', font: textFont);
        noteElement.draw(
          page: page,
          bounds: Rect.fromLTWH(0, summaryY, page.getClientSize().width,
              page.getClientSize().height - summaryY),
        );
      }

      final List<int> bytes = await document.save();
      document.dispose();

      final storageService = StorageService();
      final storagePath =
          'purchase_order_pdfs/${purchaseOrderRef.id}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final url = await storageService.uploadData(
          Uint8List.fromList(bytes), storagePath);

      await purchaseOrderRef
          .set({'purchaseOrderPDF': url}, SetOptions(merge: true));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF created successfully.')),
        );
      }
      return url;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating PDF: $e')),
        );
      }
      return null;
    }
  }

  String _resolveStatus(Map<String, dynamic> raw) {
    if (raw['status'] is String) return raw['status'] as String;
    if (raw['purchaseOrderSent'] == true || raw['purchaseOrderScent'] == true) {
      return 'sent';
    }
    return 'draft';
  }

  Widget _buildStatusActions(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> poRef,
    _PurchaseOrderData data,
  ) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: poRef.snapshots(),
      builder: (context, snap) {
        final raw = snap.data?.data() ?? {};
        final status = _resolveStatus(raw);

        Color statusColor;
        String statusLabel;
        switch (status) {
          case 'sent':
            statusColor = Colors.blue;
            statusLabel = 'Sent';
          case 'received':
            statusColor = Colors.orange;
            statusLabel = 'Received';
          case 'billed':
            statusColor = Colors.green;
            statusLabel = 'Billed';
          case 'closed':
            statusColor = Colors.grey;
            statusLabel = 'Closed';
          default:
            statusColor = Colors.amber;
            statusLabel = 'Draft';
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: statusColor.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.circle, size: 12, color: statusColor),
                  const SizedBox(width: 8),
                  Text(
                    'Status: $statusLabel',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (status == 'draft') ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.send),
                label: Text(_reviewed ? 'Send Purchase Order' : 'Review Purchase Order'),
                onPressed: () async {
                  if (!_reviewed) {
                    final url = await _createPdf(context);
                    if (url != null && context.mounted) {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PdfViewer(pdfUrl: url),
                        ),
                      );
                      setState(() => _reviewed = true);
                    }
                  } else {
                    await poRef.set({
                      'purchaseOrderSent': true,
                      'status': 'sent',
                      'sentAt': FieldValue.serverTimestamp(),
                    }, SetOptions(merge: true));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Purchase order marked as sent.')),
                      );
                    }
                    setState(() => _sent = true);
                  }
                },
              ),
            ],
            if (status == 'sent')
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Mark as Received'),
                onPressed: () async {
                  await poRef.set({
                    'status': 'received',
                    'receivedAt': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('PO marked as received.')),
                    );
                  }
                },
              ),
            if (status == 'received')
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Create Bill from PO'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) {
                        final companyRef = TenantFirebaseService.instance
                            .companyDoc(widget.companyId);
                        return _CreateBillFromPO(
                          companyRef: companyRef,
                          poRef: poRef,
                          vendorName: data.vendor,
                        );
                      },
                    ),
                  );
                },
              ),
            if (status == 'billed' || status == 'received')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.close),
                  label: const Text('Close PO'),
                  onPressed: () async {
                    await poRef.set({
                      'status': 'closed',
                    }, SetOptions(merge: true));
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hideChrome = false;
    final companyRef =
        TenantFirebaseService.instance.companyDoc(widget.companyId);
    final purchaseOrderRef =
        FirebaseFirestore.instance.collection('purchaseOrder').doc(widget.docId);

    Widget buildBottomBar({VoidCallback? onAiPressed}) {
      if (hideChrome) return const SizedBox.shrink();
      final menuSections = MenuDrawerSections(
      );
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: 'Order Details',
            onAiPressed: onAiPressed,
            menuSections: menuSections,
          ),
          const HomeNavBarAdapter(highlightSelected: false),
        ],
      );
    }

    return Scaffold(
      appBar: null,
      bottomNavigationBar: hideChrome
          ? null
          : buildBottomBar(),
      floatingActionButton: _sent
          ? null
          : FloatingActionButton(
              heroTag: null,
              child: const Icon(Icons.edit),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PurchasingOrdersForm(
                      companyId: companyRef,
                      docId: widget.docId,
                    ),
                  ),
                );
              },
            ),
      body: _wrapCanvas(
          FutureBuilder<_PurchaseOrderData?>(
            future: _loadData(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError || !snap.hasData || snap.data == null) {
                return const Center(child: Text('Order not found.'));
              }

              final data = snap.data!;
              if (!_initialized) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  setState(() {
                    _taxable = data.taxable;
                    _shippingCtrl.text =
                        data.shippingHandling.toStringAsFixed(2);
                    _paymentTerms = data.paymentTerms;
                    _shippingMethod = data.shippingMethod;
                    _notesCtrl.text = data.notes ?? '';
                    _sent = data.sent;
                    _initialized = true;
                  });
                });
              }
              final categoryRef = FirebaseFirestore.instance
                  .collection('timelineCategory')
                  .doc('uq6TbuShHCcPSgLJz8xQ');

              final itemsQuery = FirebaseFirestore.instance
                  .collection('timeline')
                  .where('timelineCategoryId', isEqualTo: categoryRef)
                  .where('purchaseOrderId', isEqualTo: purchaseOrderRef)
                  .orderBy('createdAt');

              final bottomPadding =
                  hideChrome ? 16.0 : kBottomNavigationBarHeight + 16.0;

              return SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: bottomPadding + MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AbsorbPointer(
                      absorbing: _sent,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ContainerHeader(
                            pdfUrl: data.pdfUrl,
                            titleHeader: 'PO Number',
                            textIcon: Icons.numbers,
                            title: data.poNumber,
                            descriptionHeader: 'Date',
                            descriptionIcon: Icons.calendar_today,
                            description: data.createdAt,
                          ),
                          ContainerActionWidget(
                            title: '',
                            actionText: '',
                            content: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                HeaderInfoIconValue(
                                  header: 'Team',
                                  value: data.team,
                                  icon: Icons.groups_outlined,
                                ),
                                const SizedBox(height: 12),
                                HeaderInfoIconValue(
                                  header: 'PO Contact',
                                  value: data.poContact,
                                  icon: Icons.person_outline,
                                ),
                                const SizedBox(height: 12),
                                HeaderInfoIconValue(
                                  header: 'Ship To Address',
                                  value: data.shipToAddress,
                                  icon: Icons.local_shipping_outlined,
                                ),
                              ],
                            ),
                          ),
                          ContainerActionWidget(
                            title: '',
                            actionText: '',
                            content: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                HeaderInfoIconValue(
                                  header: 'Vendor',
                                  value: data.vendor,
                                  icon: Icons.store_mall_directory_outlined,
                                ),
                                const SizedBox(height: 12),
                                HeaderInfoIconValue(
                                  header: 'Vendor Contact',
                                  value: data.vendorContact,
                                  icon: Icons.person_outline,
                                ),
                                const SizedBox(height: 12),
                                HeaderInfoIconValue(
                                  header: 'Billing Address',
                                  value: data.billingAddress,
                                  icon: Icons.location_on_outlined,
                                ),
                              ],
                            ),
                          ),
                          ContainerActionStandardViewGroup(
                            title: 'Items',
                            actionText: 'Add',
                            onAction: () => _showAddItemDialog(context),
                            queryStream: itemsQuery.snapshots(),
                            groupBy: (_) => 'items',
                            itemBuilder: (doc) {
                              final data = doc.data();
                              final qty = data['quantity'] ?? 0;
                              final objRef = data['companyObjectId']
                                  as DocumentReference<Map<String, dynamic>>?;
                              return FutureBuilder<Map<String, dynamic>>(
                                future: objRef != null
                                    ? _getObjectData(objRef)
                                    : Future.value(<String, dynamic>{}),
                                builder: (context, snap) {
                                  final objData = snap.data ?? {};
                                  final objName =
                                      objData['localName']?.toString() ??
                                          objRef?.id ??
                                          '';
                                  final companyRef = FirebaseFirestore.instance
                                      .collection('company')
                                      .doc(widget.companyId);
                                  final price = (data['price'] ??
                                          objData['currentPrice'] ??
                                          0)
                                      .toDouble();
                                  return FutureBuilder<String>(
                                    future: objRef != null
                                        ? CompanyObjectFileImages
                                            .primaryHeaderImageUrl(
                                            companyRef: companyRef,
                                            objectId: objRef.id,
                                          )
                                        : Future.value(''),
                                    builder: (context, imageSnap) {
                                      final imgUrl = imageSnap.data ?? '';
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 4.0,
                                        ),
                                        child: PurchaseOrderItemTile(
                                          key: ValueKey(doc.id),
                                          imageUrl: imgUrl,
                                          title: objName,
                                          currentPrice: price,
                                          subTitle: 'Quantity',
                                          subTitleIcon: Icons.numbers,
                                          initialPercentage: qty is int
                                              ? qty
                                              : int.tryParse(qty.toString()) ??
                                                  1,
                                          step: 1,
                                          minValue: 1,
                                          maxValue: null,
                                          suffixText: '',
                                          onPercentageChanged: (val) async {
                                            await FirestoreService()
                                                .saveDocument(
                                              collectionRef: FirebaseFirestore.instance
                                                  .collection('timeline'),
                                              data: {'quantity': val},
                                              docId: doc.id,
                                            );
                                          },
                                          onTap: objRef != null
                                              ? () => _editItemPrice(
                                                    context,
                                                    doc,
                                                    objRef,
                                                    price,
                                                  )
                                              : null,
                                          onImageTap: imgUrl.isNotEmpty
                                              ? () =>
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          ImageViewer(
                                                        imageUrl: imgUrl,
                                                      ),
                                                    ),
                                                  )
                                              : null,
                                        ),
                                      );
                                    },
                                  );
                                },
                              );
                            },
                            emptyMessage: 'No items.',
                            shrinkWrap: true,
                            physics: const ClampingScrollPhysics(),
                            onSwipeRight: (doc) => _deleteItem(context, doc),
                          ),
                          // Display subtotal and additional order fields
                          ContainerActionWidget(
                            // If ContainerActionWidget.title is non-nullable, use '' (empty string). If it's nullable, you can set null.
                            title: '', // ← change from null if needed
                            actionText: '',
                            content: StreamBuilder<
                                QuerySnapshot<Map<String, dynamic>>>(
                              stream: itemsQuery.snapshots(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const SizedBox.shrink();
                                }
                                return FutureBuilder<double>(
                                  future: _calculateTotal(snapshot.data!.docs),
                                  builder: (context, totalSnap) {
                                    final subtotal = totalSnap.data ?? 0.0;
                                    final shipping =
                                        double.tryParse(_shippingCtrl.text) ??
                                            0.0;
                                    final grandTotal = subtotal + shipping;
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        HeaderInfoIconValue(
                                          header: 'Subtotal',
                                          value:
                                              '\$${subtotal.toStringAsFixed(2)}',
                                          icon: Icons.attach_money_outlined,
                                        ),
                                        const SizedBox(height: 12),
                                        DropdownButtonFormField<bool>(
                                          decoration: const InputDecoration(
                                            labelText: 'Taxable',
                                            border: OutlineInputBorder(),
                                          ),
                                          initialValue: _taxable,
                                          items: const [
                                            DropdownMenuItem(
                                                value: true,
                                                child: Text('Taxable')),
                                            DropdownMenuItem(
                                                value: false,
                                                child: Text('Tax Exempt')),
                                          ],
                                          onChanged: (val) async {
                                            if (val == null) return;
                                            setState(() => _taxable = val);
                                            final companyRef = FirebaseFirestore
                                                .instance
                                                .collection('company')
                                                .doc(widget.companyId);
                                            await FirestoreService()
                                                .saveDocument(
                                              collectionRef: FirebaseFirestore.instance
                                                  .collection('purchaseOrder'),
                                              data: {'taxable': val},
                                              docId: widget.docId,
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 12),
                                        TextField(
                                          controller: _shippingCtrl,
                                          keyboardType: const TextInputType
                                              .numberWithOptions(decimal: true),
                                          textInputAction: TextInputAction.done,
                                          decoration: const InputDecoration(
                                            labelText: 'Shipping & Handling',
                                            border: OutlineInputBorder(),
                                          ),
                                          onEditingComplete: () async {
                                            final amount = double.tryParse(
                                                    _shippingCtrl.text) ??
                                                0.0;
                                            final companyRef = FirebaseFirestore
                                                .instance
                                                .collection('company')
                                                .doc(widget.companyId);
                                            await FirestoreService()
                                                .saveDocument(
                                              collectionRef: FirebaseFirestore.instance
                                                  .collection('purchaseOrder'),
                                              data: {
                                                'shippingHandling': amount
                                              },
                                              docId: widget.docId,
                                            );
                                            setState(() {});
                                            FocusScope.of(context).unfocus();
                                          },
                                        ),
                                        const SizedBox(height: 12),
                                        HeaderInfoIconValue(
                                          header: 'Grand Total',
                                          value:
                                              '\$${grandTotal.toStringAsFixed(2)}',
                                          icon: Icons.attach_money,
                                        ),
                                        const SizedBox(height: 12),
                                        StreamBuilder<
                                            QuerySnapshot<
                                                Map<String, dynamic>>>(
                                          stream: FirebaseFirestore.instance
                                              .collection('company')
                                              .doc(widget.companyId)
                                              .collection('companyPaymentTerm')
                                              .orderBy('name')
                                              .snapshots(),
                                          builder: (context, snapshot) {
                                            if (snapshot.hasError) {
                                              return const SizedBox(
                                                height: 60,
                                                child: Center(
                                                    child: Text(
                                                        'Error loading payment terms')),
                                              );
                                            }
                                            if (!snapshot.hasData) {
                                              return const SizedBox(
                                                height: 60,
                                                child: Center(
                                                    child:
                                                        CircularProgressIndicator()),
                                              );
                                            }
                                            final items = snapshot.data!.docs
                                                .map((d) =>
                                                    d
                                                        .data()['name']
                                                        ?.toString() ??
                                                    '')
                                                .where((e) => e.isNotEmpty)
                                                .toList();
                                            return SearchAddSelectDropdown<
                                                String>(
                                              label: 'Payment Terms',
                                              items: items,
                                              initialValue: _paymentTerms,
                                              itemLabel: (v) => v,
                                              searchLabelText:
                                                  'Search Payment Terms',
                                              addDialogTitle:
                                                  'Add Payment Term',
                                              nameFieldLabel: 'Name',
                                              descriptionFieldLabel:
                                                  'Description',
                                              onAdd: _addPaymentTerm,
                                              onChanged: (val) async {
                                                setState(
                                                    () => _paymentTerms = val);
                                                final companyRef =
                                                    FirebaseFirestore.instance
                                                        .collection('company')
                                                        .doc(widget.companyId);
                                                await FirestoreService()
                                                    .saveDocument(
                                                  collectionRef:
                                                      FirebaseFirestore.instance.collection(
                                                          'purchaseOrder'),
                                                  data: {'paymentTerms': val},
                                                  docId: widget.docId,
                                                );
                                              },
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 12),
                                        StreamBuilder<
                                            QuerySnapshot<
                                                Map<String, dynamic>>>(
                                          stream: FirebaseFirestore.instance
                                              .collection('company')
                                              .doc(widget.companyId)
                                              .collection(
                                                  'companyShippingMethod')
                                              .orderBy('name')
                                              .snapshots(),
                                          builder: (context, snapshot) {
                                            if (snapshot.hasError) {
                                              return const SizedBox(
                                                height: 60,
                                                child: Center(
                                                    child: Text(
                                                        'Error loading shipping methods')),
                                              );
                                            }
                                            if (!snapshot.hasData) {
                                              return const SizedBox(
                                                height: 60,
                                                child: Center(
                                                    child:
                                                        CircularProgressIndicator()),
                                              );
                                            }
                                            final items = snapshot.data!.docs
                                                .map((d) =>
                                                    d
                                                        .data()['name']
                                                        ?.toString() ??
                                                    '')
                                                .where((e) => e.isNotEmpty)
                                                .toList();
                                            return SearchAddSelectDropdown<
                                                String>(
                                              label: 'Shipping Method',
                                              items: items,
                                              initialValue: _shippingMethod,
                                              itemLabel: (v) => v,
                                              searchLabelText:
                                                  'Search Shipping Methods',
                                              addDialogTitle:
                                                  'Add Shipping Method',
                                              nameFieldLabel: 'Name',
                                              descriptionFieldLabel:
                                                  'Description',
                                              onAdd: _addShippingMethod,
                                              onChanged: (val) async {
                                                setState(() =>
                                                    _shippingMethod = val);
                                                final companyRef =
                                                    FirebaseFirestore.instance
                                                        .collection('company')
                                                        .doc(widget.companyId);
                                                await FirestoreService()
                                                    .saveDocument(
                                                  collectionRef:
                                                      FirebaseFirestore.instance.collection(
                                                          'purchaseOrder'),
                                                  data: {'shippingMethod': val},
                                                  docId: widget.docId,
                                                );
                                              },
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 12),
                                        TextField(
                                          controller: _notesCtrl,
                                          maxLines: null,
                                          decoration: const InputDecoration(
                                            labelText: 'Notes',
                                            border: OutlineInputBorder(),
                                          ),
                                          onChanged: (val) async {
                                            final companyRef = FirebaseFirestore
                                                .instance
                                                .collection('company')
                                                .doc(widget.companyId);
                                            await FirestoreService()
                                                .saveDocument(
                                              collectionRef: FirebaseFirestore.instance
                                                  .collection('purchaseOrder'),
                                              data: {'notes': val},
                                              docId: widget.docId,
                                            );
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    SafeArea(
                      minimum: const EdgeInsets.all(16),
                      child: _buildStatusActions(context, purchaseOrderRef, data),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
    );
  }
}

class _PurchaseOrderData {
  final String vendor;
  final String vendorContact;
  final String team;
  final String poContact;
  final String poNumber;
  final String createdAt;
  final String? pdfUrl;
  final bool taxable;
  final String billingAddress;
  final String shipToAddress;
  final double shippingHandling;
  final String? paymentTerms;
  final String? shippingMethod;
  final String? notes;
  final bool sent;

  _PurchaseOrderData({
    required this.vendor,
    required this.vendorContact,
    required this.team,
    required this.poContact,
    required this.poNumber,
    required this.createdAt,
    required this.taxable,
    required this.billingAddress,
    required this.shipToAddress,
    required this.shippingHandling,
    required this.sent,
    this.paymentTerms,
    this.shippingMethod,
    this.notes,
    this.pdfUrl,
  });
}

/// Helper screen that creates a finance bill pre-populated from a PO.
class _CreateBillFromPO extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final DocumentReference<Map<String, dynamic>> poRef;
  final String vendorName;

  const _CreateBillFromPO({
    required this.companyRef,
    required this.poRef,
    required this.vendorName,
  });

  @override
  State<_CreateBillFromPO> createState() => _CreateBillFromPOState();
}

class _CreateBillFromPOState extends State<_CreateBillFromPO> {
  bool _saving = false;

  Future<void> _createBill() async {
    setState(() => _saving = true);

    try {
      // Read PO data
      final poSnap = await widget.poRef.get();
      final poData = poSnap.data() ?? {};

      final total =
          (poData['purchaseOrderTotal'] as num?)?.toDouble() ?? 0.0;
      final poNumber = poData['poNumber']?.toString() ?? '';

      // Create the bill
      final billData = <String, dynamic>{
        'billNumber': 'PO-$poNumber',
        'vendorId': poData['vendorId'],
        'vendorName': widget.vendorName,
        'purchaseOrderId': widget.poRef,
        'status': 'unpaid',
        'issueDate': FieldValue.serverTimestamp(),
        'dueDate': FieldValue.serverTimestamp(),
        'subtotal': total,
        'tax': 0,
        'total': total,
        'amountPaid': 0,
        'notes': 'Created from PO #$poNumber',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final billRef = await FirebaseFirestore.instance.collection('bill').add(billData);

      // Mark PO as billed
      await widget.poRef.set({
        'status': 'billed',
        'billId': billRef,
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bill created from purchase order.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create bill: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Bill from PO')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create a bill from this purchase order?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Text('Vendor: ${widget.vendorName}'),
            const SizedBox(height: 8),
            const Text(
              'This will create a new bill in Finance linked to this PO '
              'and mark the PO as billed.',
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.receipt_long_outlined),
                label: Text(_saving ? 'Creating...' : 'Create Bill'),
                onPressed: _saving ? null : _createBill,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
