// lib/features/finances/forms/financeLedgerForm.dart

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kleenops_admin/services/firestore_service.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kleenops_admin/app/shared_widgets/forms/cancel_save_adapter.dart';
import 'package:shared_widgets/search/search_field_action.dart';

class FinanceLedgerForm extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyId;
  final String? docId;

  const FinanceLedgerForm({super.key, required this.companyId, this.docId});

  @override
  FinanceLedgerFormState createState() => FinanceLedgerFormState();
}

class FinanceLedgerFormState extends State<FinanceLedgerForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _memoController = TextEditingController();
  final _imagePicker = ImagePicker();
  // GeminiReceiptService not available in admin; stub for compilation.
  final _receiptService = _ReceiptServiceStub();
  Uint8List? _receiptAttachmentBytes;
  String? _receiptAttachmentName;
  bool _receiptAttachmentIsImage = false;

  DocumentReference<Map<String, dynamic>>? _debitAccountRef;
  DocumentReference<Map<String, dynamic>>? _creditAccountRef;
  DocumentReference<Map<String, dynamic>>? _vendorRef;
  DateTime _entryDate = DateTime.now();
  bool _saving = false;
  bool _processingReceipt = false;
  bool _loading = true;
  String? _suggestedVendorName;
  String? _suggestedDebitAccountName;
  String? _suggestedCreditAccountName;
  DateTime? _suggestedTransactionDate;

  @override
  void initState() {
    super.initState();
    if (widget.docId != null) {
      _loadData();
    } else {
      _loading = false;
    }
  }

  Future<void> _loadData() async {
    final doc =
        await widget.companyId.collection('timeline').doc(widget.docId).get();
    if (doc.exists) {
      final data = doc.data()!;
      _amountController.text = data['amount']?.toString() ?? '';
      _memoController.text = data['name'] ?? '';
      final ts = data['createdAt'] as Timestamp?;
      if (ts != null) _entryDate = ts.toDate();
      final rawDebit = data['debitAccountId'];
      if (rawDebit is DocumentReference<Object?>) {
        _debitAccountRef = rawDebit as DocumentReference<Map<String, dynamic>>?;
      }
      final rawCredit = data['creditAccountId'];
      if (rawCredit is DocumentReference<Object?>) {
        _creditAccountRef =
            rawCredit as DocumentReference<Map<String, dynamic>>?;
      }
      final rawVendor = data['vendorId'];
      if (rawVendor is DocumentReference<Object?>) {
        _vendorRef = rawVendor as DocumentReference<Map<String, dynamic>>?;
      }
    }
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final categoryRef = FirebaseFirestore.instance
        .collection('timelineCategory')
        .doc('jlXgbQiOKD3VjWd7AztM');

    final user = FirebaseAuth.instance.currentUser;
    final userRef = user != null
        ? FirebaseFirestore.instance.collection('user').doc(user.uid)
        : null;

    final data = <String, dynamic>{
      'createdAt': Timestamp.fromDate(_entryDate),
      'name': _memoController.text.trim(),
      'amount': double.parse(_amountController.text.trim()),
      'debitAccountId': _debitAccountRef,
      'creditAccountId': _creditAccountRef,
      if (_vendorRef != null) 'vendorId': _vendorRef,
      'timelineCategoryId': categoryRef,
      'timelineCategory': 'jlXgbQiOKD3VjWd7AztM',
      if (widget.docId == null && userRef != null) 'createdBy': userRef,
    };

    await FirestoreService().saveDocument(
      collectionRef: widget.companyId.collection('timeline'),
      data: data,
      docId: widget.docId,
    );

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _captureReceipt() async {
    if (_saving) return;
    if (_processingReceipt) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait for the current analysis to finish.'),
        ),
      );
      return;
    }
    try {
      final image = await _imagePicker.pickImage(source: ImageSource.camera);
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _receiptAttachmentBytes = bytes;
        _receiptAttachmentName = image.name;
        _receiptAttachmentIsImage = true;
      });
      await _processReceiptBytes(bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to capture receipt: $e')),
      );
    }
  }

  Future<void> _attachReceiptFile() async {
    if (_saving) return;
    if (_processingReceipt) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait for the current analysis to finish.'),
        ),
      );
      return;
    }
    try {
      final result = await FilePicker.platform.pickFiles(withData: true);
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      Uint8List? bytes = file.bytes;
      if (bytes == null && file.path != null) {
        final pickedFile = XFile(file.path!);
        bytes = await pickedFile.readAsBytes();
      }
      if (bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to read selected file.')),
        );
        return;
      }
      final extension = file.extension?.toLowerCase() ?? '';
      const imageExtensions = {
        'jpg',
        'jpeg',
        'png',
        'gif',
        'bmp',
        'webp',
        'heic',
        'heif',
      };
      if (!mounted) return;
      setState(() {
        _receiptAttachmentBytes = bytes;
        _receiptAttachmentName = file.name;
        _receiptAttachmentIsImage = imageExtensions.contains(extension);
      });
      await _processReceiptBytes(bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to attach file: $e')),
      );
    }
  }

  Future<void> _processReceiptBytes(Uint8List bytes) async {
    if (!mounted) return;
    setState(() => _processingReceipt = true);
    try {
      final result = await _receiptService.extractLedgerFields(
        bytes,
        mimeType: _resolveReceiptMimeType(),
        usageSource: 'finances',
        usageSourceContext: 'finance_ledger_form',
      );
      if (!mounted) return;
      _applyReceiptExtraction(
        amount: result.amount,
        memo: result.memo,
        vendorName: result.vendorName,
        debitAccountName: result.debitAccountName,
        creditAccountName: result.creditAccountName,
        transactionDate: result.transactionDate,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.hasAnyData
                ? 'Receipt details applied. Review before saving.'
                : 'Receipt analyzed but no structured data was found.',
          ),
        ),
      );
    } on GeminiReceiptException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Receipt processing failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _processingReceipt = false);
      }
    }
  }

  void _applyReceiptExtraction({
    double? amount,
    String? memo,
    DocumentReference<Map<String, dynamic>>? debitAccount,
    DocumentReference<Map<String, dynamic>>? creditAccount,
    DocumentReference<Map<String, dynamic>>? vendor,
    String? vendorName,
    String? debitAccountName,
    String? creditAccountName,
    DateTime? transactionDate,
  }) {
    setState(() {
      if (amount != null) {
        _amountController.text = amount.toStringAsFixed(2);
      }
      if (memo != null) {
        _memoController.text = memo;
      }
      _debitAccountRef = debitAccount ?? _debitAccountRef;
      _creditAccountRef = creditAccount ?? _creditAccountRef;
      _vendorRef = vendor ?? _vendorRef;
      if (transactionDate != null) {
        _entryDate = transactionDate;
      }
      _suggestedVendorName = vendorName ?? _suggestedVendorName;
      _suggestedDebitAccountName =
          debitAccountName ?? _suggestedDebitAccountName;
      _suggestedCreditAccountName =
          creditAccountName ?? _suggestedCreditAccountName;
      _suggestedTransactionDate = transactionDate ?? _suggestedTransactionDate;
    });
  }

  String? _resolveReceiptMimeType() {
    if (_receiptAttachmentName == null || !_receiptAttachmentIsImage) {
      return null;
    }
    final name = _receiptAttachmentName!.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    if (name.endsWith('.gif')) return 'image/gif';
    if (name.endsWith('.bmp')) return 'image/bmp';
    if (name.endsWith('.heic') || name.endsWith('.heif')) {
      return 'image/heic';
    }
    return 'image/jpeg';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: const StandardAppBar(title: 'Ledger Entry'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildReceiptCaptureSection(context),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 24),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: widget.companyId
                  .collection('companyCompany')
                  .orderBy('name')
                  .snapshots(),
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
                  label: 'Vendor',
                  items: items,
                  initialValue: _vendorRef,
                  itemLabel: (ref) {
                    final d = docs.firstWhere((doc) => doc.reference == ref);
                    return (d.data()['name'] ?? 'Unnamed Vendor') as String;
                  },
                  onChanged: (val) => setState(() => _vendorRef = val),
                );
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (v) => v == null || double.tryParse(v) == null
                  ? 'Enter amount'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _memoController,
              decoration: const InputDecoration(
                labelText: 'Memo',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: widget.companyId
                  .collection('account')
                  .orderBy('name')
                  .snapshots(),
              builder: (ctx, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs;
                final items = docs.map((d) {
                  final name = d.data()['name'] ?? 'Unnamed';
                  return DropdownMenuItem(
                    value: d.reference,
                    child: Text(name),
                  );
                }).toList();
                return Column(
                  children: [
                    DropdownButtonFormField<
                        DocumentReference<Map<String, dynamic>>>(
                      initialValue: _debitAccountRef,
                      decoration: const InputDecoration(
                        labelText: 'Debit Account',
                      ),
                      items: items,
                      onChanged: (r) => setState(() => _debitAccountRef = r),
                      validator: (v) =>
                          v == null ? 'Select debit account' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<
                        DocumentReference<Map<String, dynamic>>>(
                      initialValue: _creditAccountRef,
                      decoration: const InputDecoration(
                        labelText: 'Credit Account',
                      ),
                      items: items,
                      onChanged: (r) => setState(() => _creditAccountRef = r),
                      validator: (v) =>
                          v == null ? 'Select credit account' : null,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: CancelSaveBar(
          onCancel: () => Navigator.of(context).pop(),
          onSave: _saving ? null : _save,
        ),
      ),
    );
  }

  Widget _buildReceiptCaptureSection(BuildContext context) {
    final theme = Theme.of(context);
    final canInteract = !_saving && !_processingReceipt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Receipt Capture',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.insert_drive_file_outlined),
                label: const Text('Upload receipt'),
                onPressed: canInteract ? _attachReceiptFile : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Take photo'),
                onPressed: canInteract ? _captureReceipt : null,
              ),
            ),
          ],
        ),
        if (_processingReceipt) ...[
          const SizedBox(height: 12),
          Row(
            children: const [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text('Analyzing receipt...'),
              ),
            ],
          ),
        ],
        if (_receiptAttachmentBytes != null && !_processingReceipt) ...[
          const SizedBox(height: 12),
          if (_receiptAttachmentIsImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                _receiptAttachmentBytes!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Row(
                children: [
                  const Icon(Icons.insert_drive_file_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _receiptAttachmentName ?? 'Attachment ready for AI',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          if (_receiptAttachmentName != null) ...[
            const SizedBox(height: 8),
            Text(
              _receiptAttachmentName!,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
        if (!_processingReceipt &&
            (_suggestedVendorName != null ||
                _suggestedDebitAccountName != null ||
                _suggestedCreditAccountName != null ||
                _suggestedTransactionDate != null)) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI suggestions',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_suggestedVendorName != null)
                  Text('Vendor: $_suggestedVendorName'),
                if (_suggestedDebitAccountName != null)
                  Text('Debit account: $_suggestedDebitAccountName'),
                if (_suggestedCreditAccountName != null)
                  Text('Credit account: $_suggestedCreditAccountName'),
                if (_suggestedTransactionDate != null)
                  Text(
                    'Transaction date: '
                    '${_suggestedTransactionDate!.toIso8601String().split('T').first}',
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ── Stubs for AI receipt service not available in admin ──────────────

class _ReceiptServiceStub {
  Future<_ReceiptResult> extractLedgerFields(
    dynamic bytes, {
    String? mimeType,
    String? usageSource,
    String? usageSourceContext,
  }) async {
    throw GeminiReceiptException('Receipt AI not available in admin app.');
  }
}

class _ReceiptResult {
  final double? amount;
  final String? memo;
  final String? vendorName;
  final String? debitAccountName;
  final String? creditAccountName;
  final DateTime? transactionDate;
  final bool hasAnyData;

  _ReceiptResult({
    this.amount,
    this.memo,
    this.vendorName,
    this.debitAccountName,
    this.creditAccountName,
    this.transactionDate,
    this.hasAnyData = false,
  });
}

class GeminiReceiptException implements Exception {
  final String message;
  GeminiReceiptException(this.message);
  @override
  String toString() => message;
}
