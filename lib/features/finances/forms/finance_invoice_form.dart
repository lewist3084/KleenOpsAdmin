// lib/features/finances/forms/finance_invoice_form.dart
//
// QuickBooks-style invoice builder (overlord app). Stacked
// ContainerActionWidget cards:
//   1. Bill To      — customer + issue/due dates.
//   2. Products & Services — a live line-item list. "Add" opens a picker that
//      pulls the platform-product catalog (select one to prefill its label +
//      price), then captures a rate, quantity and per-line description.
//      Free-form items (no product link) are allowed.
//   3. Summary      — subtotal, an editable tax rate, and the running total.
//
// Line items live in local draft state while editing and are written to the
// invoice's `lineItem` subcollection on save (the same shape the details screen
// and FinanceInvoiceService.recalculateInvoiceTotals already read).

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kleenops_admin/features/finances/details/finance_invoice_details.dart';
import 'package:kleenops_admin/features/finances/services/finance_invoice_service.dart';
import 'package:shared_widgets/services/firestore_service.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/widgets/layout/bookended_canvas.dart';
import 'package:kleenops_admin/app/shared_widgets/forms/cancel_save_adapter.dart';
import 'package:shared_widgets/search/search_field_action.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:shared_widgets/labels/text_value_inline.dart';
import 'package:shared_widgets/tiles/standard_tile_small.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';

class FinanceInvoiceForm extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final String? docId;
  final String? customerId;
  final DocumentReference<Map<String, dynamic>>? initialCustomerRef;

  const FinanceInvoiceForm({
    super.key,
    required this.companyRef,
    this.docId,
    this.customerId,
    this.initialCustomerRef,
  });

  @override
  State<FinanceInvoiceForm> createState() => _FinanceInvoiceFormState();
}

class _FinanceInvoiceFormState extends State<FinanceInvoiceForm> {
  final _taxRateController = TextEditingController(text: '0');
  final _notesController = TextEditingController();
  final _invoiceService = FinanceInvoiceService();

  DocumentReference<Map<String, dynamic>>? _customerRef;
  String _customerName = '';
  DateTime _issueDate = DateTime.now();
  DateTime? _dueDate;
  final List<_LineItemDraft> _lineItems = [];

  bool _saving = false;
  bool _loading = true;

  // ── firestore paths (overlord uses top-level collections) ──────────
  CollectionReference<Map<String, dynamic>> get _invoiceCollection =>
      FirebaseFirestore.instance.collection('invoice');
  CollectionReference<Map<String, dynamic>> get _customerCollection =>
      FirebaseFirestore.instance.collection('customer');

  // ── product source: the platform-product catalog ───────────────────
  CollectionReference<Map<String, dynamic>> get _productsCollection =>
      FirebaseFirestore.instance.collection('platformProduct');

  _ProductOption _mapProduct(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final priceCents = (d['priceCents'] as num?)?.toDouble();
    return _ProductOption(
      id: doc.id,
      name: (d['label'] ?? doc.id) as String,
      description: d['description'] as String?,
      unitPrice: priceCents != null ? priceCents / 100 : null,
    );
  }

  // ── totals ────────────────────────────────────────────────────────
  double get _subtotal =>
      _lineItems.fold(0.0, (acc, item) => acc + item.amount);
  double get _taxRate => double.tryParse(_taxRateController.text.trim()) ?? 0.0;
  double get _taxAmount => _subtotal * _taxRate / 100;
  double get _total => _subtotal + _taxAmount;

  @override
  void initState() {
    super.initState();
    if (widget.docId != null) {
      _loadData();
    } else {
      _loading = false;
      if (widget.initialCustomerRef != null) {
        _customerRef = widget.initialCustomerRef;
        _loadCustomerName(_customerRef!);
      } else if (widget.customerId != null) {
        _customerRef = _customerCollection.doc(widget.customerId);
        _loadCustomerName(_customerRef!);
      }
      _dueDate = DateTime.now().add(const Duration(days: 30));
    }
  }

  Future<void> _loadCustomerName(
      DocumentReference<Map<String, dynamic>> ref) async {
    final snap = await ref.get();
    if (snap.exists && mounted) {
      setState(() {
        _customerName = (snap.data()?['name'] ?? '') as String;
      });
    }
  }

  Future<void> _loadData() async {
    final invoiceRef = _invoiceCollection.doc(widget.docId);
    final doc = await invoiceRef.get();
    if (doc.exists) {
      final data = doc.data()!;
      _notesController.text = data['notes'] ?? '';

      final rawCustomer = data['customerId'];
      if (rawCustomer is DocumentReference) {
        _customerRef = rawCustomer as DocumentReference<Map<String, dynamic>>;
        await _loadCustomerName(_customerRef!);
      }
      _customerName = (data['customerName'] ?? '') as String;

      final issueDateTs = data['issueDate'] as Timestamp?;
      if (issueDateTs != null) _issueDate = issueDateTs.toDate();
      final dueDateTs = data['dueDate'] as Timestamp?;
      if (dueDateTs != null) _dueDate = dueDateTs.toDate();

      // Prefer an explicit taxRate; otherwise derive it from the stored tax
      // amount so legacy invoices round-trip cleanly.
      final subtotal = (data['subtotal'] as num?)?.toDouble() ?? 0.0;
      final taxAmount = (data['tax'] as num?)?.toDouble() ?? 0.0;
      final storedRate = (data['taxRate'] as num?)?.toDouble();
      final rate =
          storedRate ?? (subtotal > 0 ? (taxAmount / subtotal * 100) : 0.0);
      _taxRateController.text = rate == rate.roundToDouble()
          ? rate.toStringAsFixed(0)
          : rate.toStringAsFixed(3);

      // Load existing line items.
      final itemsSnap =
          await invoiceRef.collection('lineItem').orderBy('position').get();
      for (final itemDoc in itemsSnap.docs) {
        final d = itemDoc.data();
        _lineItems.add(_LineItemDraft(
          description: (d['description'] ?? '') as String,
          quantity: (d['quantity'] as num?)?.toDouble() ?? 1,
          unitPrice: (d['unitPrice'] as num?)?.toDouble() ?? 0,
          productId: d['productId'] as String?,
        ));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickDate({required bool isIssueDate}) async {
    final initial = isIssueDate
        ? _issueDate
        : (_dueDate ?? DateTime.now().add(const Duration(days: 30)));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isIssueDate) {
          _issueDate = picked;
        } else {
          _dueDate = picked;
        }
      });
    }
  }

  Future<void> _addOrEditLineItem({int? index}) async {
    final result = await showDialog<_LineItemDraft>(
      context: context,
      builder: (_) => _LineItemEditorDialog(
        initial: index != null ? _lineItems[index] : null,
        productsCollection: _productsCollection,
        productOrderField: 'label',
        mapProduct: _mapProduct,
        onCreateProduct: null,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        if (index == null) {
          _lineItems.add(result);
        } else {
          _lineItems[index] = result;
        }
      });
    }
  }

  Future<void> _writeLineItems(
    DocumentReference<Map<String, dynamic>> invoiceRef, {
    required bool deleteExisting,
  }) async {
    final col = invoiceRef.collection('lineItem');
    final batch = invoiceRef.firestore.batch();
    if (deleteExisting) {
      final existing = await col.get();
      for (final doc in existing.docs) {
        batch.delete(doc.reference);
      }
    }
    for (var i = 0; i < _lineItems.length; i++) {
      final item = _lineItems[i];
      batch.set(col.doc(), {
        'description': item.description,
        'quantity': item.quantity,
        'unitPrice': item.unitPrice,
        'amount': item.amount,
        'position': i,
        if (item.productId != null) 'productId': item.productId,
      });
    }
    await batch.commit();
  }

  Future<void> _save() async {
    if (_customerRef == null) {
      SnackbarService.instance.showSnackBar(
        const SnackBar(
            duration: Duration(seconds: 5),
            content: Text('Please select a customer')),
      );
      return;
    }
    setState(() => _saving = true);

    final taxRate = _taxRate;
    final taxAmount = _taxAmount;
    final subtotal = _subtotal;
    final total = _total;

    final data = <String, dynamic>{
      'customerId': _customerRef,
      'customerName': _customerName,
      'issueDate': Timestamp.fromDate(_issueDate),
      'dueDate': _dueDate != null ? Timestamp.fromDate(_dueDate!) : null,
      'taxRate': taxRate,
      'tax': taxAmount,
      'notes': _notesController.text.trim(),
    };

    try {
      if (widget.docId == null) {
        data['status'] = 'draft';
        data['subtotal'] = subtotal;
        data['total'] = total;
        data['amountPaid'] = 0.0;
        data['amountDue'] = total;

        final docRef =
            await _invoiceService.createInvoice(widget.companyRef, data);
        await _writeLineItems(docRef, deleteExisting: false);
        await _invoiceService.recalculateInvoiceTotals(docRef);

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => FinanceInvoiceDetailsScreen(
                companyRef: widget.companyRef,
                docId: docRef.id,
              ),
            ),
          );
        }
      } else {
        final invoiceRef = _invoiceCollection.doc(widget.docId);
        await FirestoreService().saveDocument(
          collectionRef: _invoiceCollection,
          data: data,
          docId: widget.docId,
        );
        await _writeLineItems(invoiceRef, deleteExisting: true);
        await _invoiceService.recalculateInvoiceTotals(invoiceRef);

        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        SnackbarService.instance.showSnackBar(
          SnackBar(
              duration: const Duration(seconds: 5),
              content: Text('Could not save invoice: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _taxRateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isEdit = widget.docId != null;
    final title = isEdit ? 'Edit Invoice' : 'New Invoice';

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: BookendedCanvas(
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 96),
          children: [
            _buildCustomerCard(),
            _buildDatesCard(),
            _buildLineItemsCard(),
            _buildSummaryCard(),
            _buildNotesCard(),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CancelSaveBar(
            onCancel: () => Navigator.of(context).pop(),
            onSave: _saving ? null : _save,
            isSaving: _saving,
            reserveNavBarSpace: false,
          ),
          DetailsAppBar(title: title),
          const HomeNavBarAdapter(),
        ],
      ),
    );
  }

  // ── cards ─────────────────────────────────────────────────────────

  Widget _buildCustomerCard() {
    return ContainerActionWidget(
      title: 'Bill To',
      actionText: '',
      content: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _customerCollection.orderBy('name').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox(
              height: 60,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final docs = snapshot.data!.docs;
          final items = docs.map((d) => d.reference).toList();
          return SearchAddSelectDropdown<
              DocumentReference<Map<String, dynamic>>>(
            label: 'Customer',
            items: items,
            initialValue: _customerRef,
            itemLabel: (ref) {
              final match = docs.where((doc) => doc.reference == ref);
              if (match.isEmpty) {
                return _customerName.isEmpty ? 'Unnamed' : _customerName;
              }
              return (match.first.data()['name'] ?? 'Unnamed') as String;
            },
            searchLabelText: 'Search Customers',
            onChanged: (val) {
              setState(() {
                _customerRef = val;
                if (val != null) {
                  final match = docs.where((doc) => doc.reference == val);
                  _customerName = match.isEmpty
                      ? ''
                      : (match.first.data()['name'] ?? '') as String;
                } else {
                  _customerName = '';
                }
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildDatesCard() {
    return ContainerActionWidget(
      title: 'Dates',
      actionText: '',
      content: Column(
        children: [
          _dateRow(
            label: 'Issue Date',
            date: _issueDate,
            icon: Icons.calendar_today_outlined,
            onTap: () => _pickDate(isIssueDate: true),
          ),
          const SizedBox(height: 12),
          _dateRow(
            label: 'Due Date',
            date: _dueDate,
            icon: Icons.event_outlined,
            onTap: () => _pickDate(isIssueDate: false),
          ),
        ],
      ),
    );
  }

  Widget _dateRow({
    required String label,
    required DateTime? date,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: TextValueInline(
          header: label,
          value: date != null ? _formatDate(date) : 'Tap to choose',
          icon: icon,
          trailingIcon: Icons.edit_calendar_outlined,
          onTrailingPressed: onTap,
        ),
      ),
    );
  }

  Widget _buildLineItemsCard() {
    return ContainerActionWidget(
      title: 'Products & Services',
      headerActionText: 'Add',
      onHeaderAction: () => _addOrEditLineItem(),
      actionText: '',
      content: _lineItems.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No items yet. Tap "Add" to add a product or service.',
                style: TextStyle(color: Colors.grey[600]),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < _lineItems.length; i++)
                  StandardTileSmallDart(
                    label: _lineItems[i].description.trim().isEmpty
                        ? '(no description)'
                        : _lineItems[i].description.trim(),
                    secondaryText:
                        '${_qtyStr(_lineItems[i].quantity)} × ${_money(_lineItems[i].unitPrice)}'
                        ' = ${_money(_lineItems[i].amount)}',
                    leadingIcon: Icons.inventory_2_outlined,
                    trailingIcon1: Icons.edit_outlined,
                    onTrailing1Tap: () => _addOrEditLineItem(index: i),
                    trailingIcon2: Icons.delete_outline,
                    onTrailing2Tap: () =>
                        setState(() => _lineItems.removeAt(i)),
                    onTap: () => _addOrEditLineItem(index: i),
                  ),
              ],
            ),
    );
  }

  Widget _buildSummaryCard() {
    return ContainerActionWidget(
      title: 'Summary',
      actionText: '',
      content: Column(
        children: [
          _totalRow('Subtotal', _subtotal),
          const SizedBox(height: 4),
          Row(
            children: [
              const Expanded(
                  child: Text('Tax Rate', style: TextStyle(fontSize: 16))),
              SizedBox(
                width: 90,
                child: TextField(
                  controller: _taxRateController,
                  textAlign: TextAlign.end,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    isDense: true,
                    suffixText: '%',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  onChanged: (_) => setState(() {}),
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _totalRow('Tax', _taxAmount),
          const Divider(),
          _totalRow('Total', _total, bold: true),
        ],
      ),
    );
  }

  Widget _buildNotesCard() {
    return ContainerActionWidget(
      title: 'Notes',
      actionText: '',
      content: TextField(
        controller: _notesController,
        decoration: const InputDecoration(
          hintText: 'Notes shown on the invoice',
          border: OutlineInputBorder(),
        ),
        maxLines: 3,
        textInputAction: TextInputAction.newline,
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      ),
    );
  }

  Widget _totalRow(String label, double value, {bool bold = false}) {
    final style = TextStyle(
      fontSize: 16,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(_money(value), style: style),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) => '${dt.month}/${dt.day}/${dt.year}';
}

String _money(double v) => '\$${v.toStringAsFixed(2)}';

String _qtyStr(double qty) =>
    qty.truncateToDouble() == qty ? qty.toStringAsFixed(0) : qty.toString();

// ─────────────────────────────────────────────────────────────────────
// Line-item draft + product option models
// ─────────────────────────────────────────────────────────────────────

class _LineItemDraft {
  _LineItemDraft({
    this.description = '',
    this.quantity = 1,
    this.unitPrice = 0,
    this.productId,
  });

  String description;
  double quantity;
  double unitPrice;
  String? productId;

  double get amount => quantity * unitPrice;
}

/// A selectable product/service. Equality is by [id] so it round-trips through
/// [SearchAddSelectDropdown]'s selection + "contains" checks.
class _ProductOption {
  const _ProductOption({
    required this.id,
    required this.name,
    this.description,
    this.unitPrice,
  });

  final String id;
  final String name;
  final String? description;
  final double? unitPrice;

  @override
  bool operator ==(Object other) => other is _ProductOption && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

// ─────────────────────────────────────────────────────────────────────
// Line-item editor dialog — product picker + rate/qty/description
// ─────────────────────────────────────────────────────────────────────

class _LineItemEditorDialog extends StatefulWidget {
  const _LineItemEditorDialog({
    this.initial,
    required this.productsCollection,
    required this.productOrderField,
    required this.mapProduct,
    this.onCreateProduct,
  });

  final _LineItemDraft? initial;
  final CollectionReference<Map<String, dynamic>> productsCollection;
  final String productOrderField;
  final _ProductOption Function(QueryDocumentSnapshot<Map<String, dynamic>>)
      mapProduct;
  final Future<_ProductOption?> Function(String name, String? description)?
      onCreateProduct;

  @override
  State<_LineItemEditorDialog> createState() => _LineItemEditorDialogState();
}

class _LineItemEditorDialogState extends State<_LineItemEditorDialog> {
  late final TextEditingController _descCtl;
  late final TextEditingController _qtyCtl;
  late final TextEditingController _rateCtl;
  String? _productId;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _descCtl = TextEditingController(text: init?.description ?? '');
    _qtyCtl =
        TextEditingController(text: init != null ? _qtyStr(init.quantity) : '1');
    _rateCtl = TextEditingController(
        text: init != null ? init.unitPrice.toStringAsFixed(2) : '');
    _productId = init?.productId;
  }

  @override
  void dispose() {
    _descCtl.dispose();
    _qtyCtl.dispose();
    _rateCtl.dispose();
    super.dispose();
  }

  double get _amount {
    final qty = double.tryParse(_qtyCtl.text.trim()) ?? 0;
    final rate = double.tryParse(_rateCtl.text.trim()) ?? 0;
    return qty * rate;
  }

  void _onProductChanged(_ProductOption? option) {
    setState(() {
      _productId = option?.id;
      if (option != null) {
        if (_descCtl.text.trim().isEmpty) _descCtl.text = option.name;
        final currentRate = double.tryParse(_rateCtl.text.trim()) ?? 0;
        if (option.unitPrice != null && currentRate == 0) {
          _rateCtl.text = option.unitPrice!.toStringAsFixed(2);
        }
      }
    });
  }

  void _submit() {
    final desc = _descCtl.text.trim();
    final qty = double.tryParse(_qtyCtl.text.trim()) ?? 0;
    final rate = double.tryParse(_rateCtl.text.trim()) ?? 0;
    if (desc.isEmpty && _productId == null) {
      _toast('Pick a product or enter a description');
      return;
    }
    if (qty <= 0) {
      _toast('Enter a quantity greater than zero');
      return;
    }
    Navigator.of(context).pop(_LineItemDraft(
      description: desc,
      quantity: qty,
      unitPrice: rate,
      productId: _productId,
    ));
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: widget.productsCollection
          .orderBy(widget.productOrderField)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ??
            <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        final options = docs.map(widget.mapProduct).toList();
        _ProductOption? selected;
        for (final o in options) {
          if (o.id == _productId) {
            selected = o;
            break;
          }
        }

        return DialogAction(
          title: widget.initial == null ? 'Add Item' : 'Edit Item',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SearchAddSelectDropdown<_ProductOption>(
                label: 'Product / Service',
                items: options,
                initialValue: selected,
                itemLabel: (o) => o.name,
                searchLabelText: 'Search products',
                addDialogTitle: 'New Product',
                onAdd: widget.onCreateProduct,
                onChanged: _onProductChanged,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descCtl,
                decoration: const InputDecoration(
                  labelText: 'Description / Notes',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                onTapOutside: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _qtyCtl,
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      onTapOutside: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _rateCtl,
                      decoration: const InputDecoration(
                        labelText: 'Rate',
                        prefixText: '\$ ',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      onTapOutside: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Amount',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(_money(_amount),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          cancelText: 'Cancel',
          onCancel: () => Navigator.of(context).pop(),
          actionText: 'Save',
          onAction: _submit,
        );
      },
    );
  }
}
