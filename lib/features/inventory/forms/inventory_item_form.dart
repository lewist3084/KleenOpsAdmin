// lib/features/inventory/forms/inventory_item_form.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:kleenops_admin/app/shared_widgets/forms/cancel_save_adapter.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';
import 'package:kleenops_admin/widgets/layout/bookended_canvas.dart';
import 'package:shared_widgets/services/firestore_service.dart';
import 'package:shared_widgets/utils/process_localization_utils.dart';

/// A model representing a company object from the subcollection.
class CompanyObjectItem {
  final DocumentReference ref;
  final String name;
  CompanyObjectItem({required this.ref, required this.name});
}

class InventoryItemForm extends StatefulWidget {
  /// Company DocumentReference — admin loads companyObject from the
  /// per-company subcollection.
  final DocumentReference companyId;
  final String inventoryRequestId;

  const InventoryItemForm({
    super.key,
    required this.companyId,
    required this.inventoryRequestId,
  });

  @override
  State<InventoryItemForm> createState() => _InventoryItemFormState();
}

class _InventoryItemFormState extends State<InventoryItemForm> {
  final TextEditingController _quantityController = TextEditingController();

  List<CompanyObjectItem> _companyObjects = [];
  bool _loadingCompanyObjects = true;
  bool _saving = false;
  CompanyObjectItem? _selectedCompanyObject;

  @override
  void initState() {
    super.initState();
    _loadCompanyObjects();
  }

  Future<void> _loadCompanyObjects() async {
    try {
      final querySnapshot =
          await widget.companyId.collection('companyObject').get();
      if (!mounted) return;
      final localeCode = Localizations.localeOf(context).toString();
      _companyObjects = querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        return CompanyObjectItem(
          ref: doc.reference,
          name: ProcessLocalizationUtils.resolveLocalizedText(
            data['localName'],
            localeCode: localeCode,
          ),
        );
      }).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } catch (_) {
      // ignore — leave list empty
    } finally {
      if (mounted) setState(() => _loadingCompanyObjects = false);
    }
  }

  Future<void> _saveForm() async {
    if (_selectedCompanyObject == null) {
      SnackbarService.instance.showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 5),
          content: Text('Please select a company object'),
        ),
      );
      return;
    }
    final quantityText = _quantityController.text.trim();
    if (quantityText.isEmpty || int.tryParse(quantityText) == null) {
      SnackbarService.instance.showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 5),
          content: Text('Please enter a valid quantity'),
        ),
      );
      return;
    }
    final quantity = int.parse(quantityText);

    setState(() => _saving = true);

    // Admin uses top-level inventoryRequest + timeline collections.
    final inventoryRequestRef = FirebaseFirestore.instance
        .collection('inventoryRequest')
        .doc(widget.inventoryRequestId);

    final data = {
      'companyObjectId': _selectedCompanyObject!.ref,
      'quantity': quantity,
      'createdAt': FieldValue.serverTimestamp(),
      'timelineCategory': '4XkpkXSLeGUZirMEiQ6E',
      'inventoryRequestId': inventoryRequestRef,
    };

    final timelineCollection = FirebaseFirestore.instance
        .collection('timeline')
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snap, _) => snap.data() ?? {},
          toFirestore: (model, _) => model,
        );

    try {
      await FirestoreService().saveDocument(
        collectionRef: timelineCollection,
        data: data,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      SnackbarService.instance.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          content: Text('Error saving document: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BookendedCanvas(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          child: Column(
            children: [
              _loadingCompanyObjects
                  ? const CircularProgressIndicator()
                  : Autocomplete<CompanyObjectItem>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return _companyObjects;
                        }
                        final query = textEditingValue.text.toLowerCase();
                        return _companyObjects.where(
                          (option) =>
                              option.name.toLowerCase().contains(query),
                        );
                      },
                      displayStringForOption: (option) => option.name,
                      onSelected: (selection) {
                        setState(() {
                          _selectedCompanyObject = selection;
                        });
                      },
                      fieldViewBuilder: (
                        context,
                        textEditingController,
                        focusNode,
                        onFieldSubmitted,
                      ) {
                        if (_selectedCompanyObject != null) {
                          textEditingController.text =
                              _selectedCompanyObject!.name;
                        }
                        return TextField(
                          controller: textEditingController,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: 'Company Object',
                            border: OutlineInputBorder(),
                          ),
                          textInputAction: TextInputAction.next,
                          onTapOutside: (_) =>
                              FocusManager.instance.primaryFocus?.unfocus(),
                        );
                      },
                    ),
              const SizedBox(height: 16),
              TextField(
                controller: _quantityController,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onTapOutside: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CancelSaveBar(
            onCancel: () => context.pop(),
            onSave: _saveForm,
            isSaving: _saving,
            reserveNavBarSpace: false,
          ),
        ],
      ),
    );
  }
}
