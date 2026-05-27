// DEGRADED: QRField (admin-absent) replaced by plain TextFormField. Users can
// type/paste a barcode; scan integration is TBD.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/widgets/layout/bookended_canvas.dart';
import 'package:kleenops_admin/app/shared_widgets/forms/cancel_save_adapter.dart';
import 'package:shared_widgets/fields/markup_image_field.dart';
import 'package:shared_widgets/services/storage_service.dart' as shared_storage;
import 'package:shared_widgets/fields/quantity_field.dart';
import 'package:shared_widgets/services/firestore_service.dart';
import 'package:shared_widgets/services/catalog_firebase_service.dart';
import 'package:kleenops_admin/features/objects/utils/catalog_object_file_images.dart';

class CatalogForm extends StatefulWidget {
  final String docId;
  const CatalogForm({super.key, required this.docId});

  @override
  State<CatalogForm> createState() => _CatalogFormState();
}

class _CatalogFormState extends State<CatalogForm> {
  final _formKey = GlobalKey<FormState>();
  String? _imageUrl;
  String? _barcode;
  DocumentReference<Map<String, dynamic>>? _scalarRef;
  DocumentReference<Map<String, dynamic>>? _scalarUnitRef;
  int _scalarQuantity = 0;
  bool _loading = true;
  late final shared_storage.StorageService _catalogStorage =
      shared_storage.StorageService(
        storage: CatalogFirebaseService.instance.storage,
      );
  FirebaseFirestore get _catalogDb =>
      CatalogFirebaseService.instance.firestore;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final doc =
        await _catalogDb.collection('object').doc(widget.docId).get();
    if (doc.exists) {
      final data = doc.data()!;
      _imageUrl = await CatalogObjectFileImages.primaryHeaderImageUrl(
        firestore: _catalogDb,
        objectId: widget.docId,
      );
      _barcode = data['objectBarcode']?.toString();
      _scalarRef = data['scalarId'];
      _scalarUnitRef = data['scalarUnitId'];
      _scalarQuantity = (data['scalarUnitQuantity'] as num?)?.toInt() ?? 0;
    }
    setState(() => _loading = false);
  }

  Future<void> _saveForm() async {
    _formKey.currentState?.save();
    final data = <String, dynamic>{
      'objectBarcode': _barcode ?? '',
      'scalarId': _scalarRef,
      'scalarUnitId': _scalarUnitRef,
      'scalarUnitQuantity': _scalarQuantity,
    };
    await FirestoreService().saveDocument(
      collectionRef: _catalogDb.collection('object'),
      docId: widget.docId,
      data: data,
    );
    await CatalogObjectFileImages.syncPrimaryHeaderImage(
      firestore: _catalogDb,
      objectId: widget.docId,
      imageUrl: _imageUrl,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final Widget formBody = Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MarkupImageField(
                imageUrl: _imageUrl,
                storageFolder: 'object/images',
                storageService: _catalogStorage,
                onImageChanged: (url) => setState(() => _imageUrl = url),
                onMarkupTap: () {},
              ),
              TextFormField(
                initialValue: _barcode,
                decoration: const InputDecoration(labelText: 'Barcode'),
                onSaved: (val) => _barcode = val,
              ),
              const SizedBox(height: 16),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _catalogDb.collection('scalar').orderBy('name').snapshots(),
                builder: (_, snap) {
                  if (!snap.hasData) {
                    return const CircularProgressIndicator();
                  }
                  return DropdownButtonFormField<
                      DocumentReference<Map<String, dynamic>>>(
                    decoration:
                        const InputDecoration(labelText: 'Scalar'),
                    initialValue: snap.data!.docs
                            .any((d) => d.reference == _scalarRef)
                        ? _scalarRef
                        : null,
                    items: snap.data!.docs
                        .map((d) => DropdownMenuItem(
                              value: d.reference,
                              child: Text(d['name'] ?? ''),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() {
                      _scalarRef = v;
                      _scalarUnitRef = null;
                    }),
                  );
                },
              ),
              if (_scalarRef != null) ...[
                const SizedBox(height: 16),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _catalogDb
                      .collection('scalar')
                      .doc(_scalarRef!.id)
                      .collection('scalarUnit')
                      .orderBy('name')
                      .snapshots(),
                  builder: (_, snap) {
                    if (!snap.hasData) {
                      return const CircularProgressIndicator();
                    }
                    return DropdownButtonFormField<
                        DocumentReference<Map<String, dynamic>>>(
                      decoration:
                          const InputDecoration(labelText: 'Scalar Unit'),
                      initialValue: snap.data!.docs
                              .any((d) => d.reference == _scalarUnitRef)
                          ? _scalarUnitRef
                          : null,
                      items: snap.data!.docs
                          .map((d) => DropdownMenuItem(
                                value: d.reference,
                                child: Text(d['name'] ?? ''),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _scalarUnitRef = v),
                    );
                  },
                ),
                const SizedBox(height: 16),
                QuantityField(
                  initialValue: _scalarQuantity,
                  labelText: 'Quantity',
                  onChanged: (v) => _scalarQuantity = v,
                ),
              ],
            ],
          ),
        ),
      );

    return Scaffold(
      body: BookendedCanvas(child: formBody),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CancelSaveBar(
            onCancel: () => Navigator.of(context).pop(),
            onSave: _saveForm,
            reserveNavBarSpace: false,
          ),
          const DetailsAppBar(title: 'Edit Product'),
          const HomeNavBarAdapter(),
        ],
      ),
    );
  }
}
