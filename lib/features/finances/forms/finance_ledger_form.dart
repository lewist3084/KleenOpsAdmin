// lib/features/finances/forms/finance_ledger_form.dart

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/services/firestore_service.dart';
import 'package:shared_widgets/finance/ledger_entry_critic.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/widgets/layout/bookended_canvas.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kleenops_admin/app/shared_widgets/forms/cancel_save_adapter.dart';
import 'package:shared_widgets/search/search_field_action.dart';
import 'package:kleenops_admin/services/firebase_ai/gemini_receipt_service.dart';
import 'package:kleenops_admin/services/storage_service.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';

/// A captured receipt page held in memory until the entry is saved.
class _ReceiptAttachment {
  _ReceiptAttachment({
    required this.bytes,
    required this.name,
    required this.mimeType,
    required this.isImage,
  });

  final Uint8List bytes;
  final String name;
  final String mimeType;
  final bool isImage;
}

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
  final _receiptService = GeminiReceiptService();

  final List<_ReceiptAttachment> _receiptImages = [];
  List<String> _existingReceiptUrls = const [];
  List<ReceiptLineItem> _lineItems = const [];

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

  // Review state — set when a reviewer opens an already-scanned entry.
  bool _wasReceiptScanned = false;
  bool _pendingReview = false;
  String? _scannedByName;

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
      _existingReceiptUrls = _stringList(data['receiptImageUrls']);
      _lineItems = _lineItemsFromData(data['receiptLineItems']);
      _wasReceiptScanned = data['receiptScanned'] == true;
      _pendingReview = _wasReceiptScanned && data['reviewConfirmed'] != true;
      _scannedByName = (data['scannedByName'] as String?)?.trim();
    }
    setState(() => _loading = false);
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static List<ReceiptLineItem> _lineItemsFromData(dynamic raw) {
    if (raw is! List) return const [];
    final items = <ReceiptLineItem>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final description = (entry['description'] ?? '').toString().trim();
      if (description.isEmpty) continue;
      final amountRaw = entry['amount'];
      final account = (entry['account'] ?? '').toString().trim();
      items.add(
        ReceiptLineItem(
          description: description,
          amount: amountRaw is num ? amountRaw.toDouble() : null,
          account: account.isEmpty ? null : account,
        ),
      );
    }
    return items;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Deterministic backwards-entry check before posting. May swap the chosen
    // debit/credit accounts if the user accepts the suggested correction.
    if (!await _confirmLedgerDirection()) return;

    setState(() => _saving = true);

    try {
      final categoryRef = FirebaseFirestore.instance
          .collection('timelineCategory')
          .doc('jlXgbQiOKD3VjWd7AztM');

      final user = FirebaseAuth.instance.currentUser;
      final userRef = user != null
          ? FirebaseFirestore.instance.collection('user').doc(user.uid)
          : null;

      final receiptUrls = <String>[..._existingReceiptUrls];
      if (_receiptImages.isNotEmpty) {
        receiptUrls.addAll(await _uploadReceiptImages());
      }
      final bool hasReceipt = receiptUrls.isNotEmpty || _lineItems.isNotEmpty;

      ({String memberId, String name, DocumentReference<Map<String, dynamic>>? ref})?
          scanner;
      if (_receiptImages.isNotEmpty && user != null) {
        scanner = await _resolveMember(user);
      }

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
        if (receiptUrls.isNotEmpty) 'receiptImageUrls': receiptUrls,
        if (_lineItems.isNotEmpty)
          'receiptLineItems': _lineItems.map((e) => e.toMap()).toList(),
        if (hasReceipt) 'receiptScanned': true,
        if (scanner != null) ...{
          if (scanner.memberId.isNotEmpty)
            'scannedByMemberId': scanner.memberId,
          if (scanner.ref != null) 'scannedByMemberRef': scanner.ref,
          'scannedByName': scanner.name,
          'scannedAt': Timestamp.now(),
        },
      };

      if (_pendingReview && _receiptImages.isEmpty) {
        data['reviewConfirmed'] = true;
        data['reviewedAt'] = Timestamp.now();
        final reviewer = user != null ? await _resolveMember(user) : null;
        if (reviewer != null) {
          if (reviewer.memberId.isNotEmpty) {
            data['reviewedByMemberId'] = reviewer.memberId;
          }
          data['reviewedByName'] = reviewer.name;
        }
      }

      await FirestoreService().saveDocument(
        collectionRef: widget.companyId.collection('timeline'),
        data: data,
        docId: widget.docId,
      );

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      SnackbarService.instance.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          content: Text('Unable to save entry: $e'),
        ),
      );
    }
  }

  Future<List<String>> _uploadReceiptImages() async {
    final storage = StorageService();
    final urls = <String>[];
    final stamp = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < _receiptImages.length; i++) {
      final image = _receiptImages[i];
      final ext = image.isImage ? 'jpg' : _extensionForName(image.name);
      final path =
          'company/${widget.companyId.id}/finance/receipts/${stamp}_$i.$ext';
      urls.add(
        await storage.uploadData(image.bytes, path, contentType: image.mimeType),
      );
    }
    return urls;
  }

  static String _extensionForName(String name) {
    final dot = name.lastIndexOf('.');
    if (dot == -1 || dot == name.length - 1) return 'bin';
    return name.substring(dot + 1).toLowerCase();
  }

  /// Resolves the acting member for this company. Admin operators may not be
  /// company members, so this falls back to the auth display name/email.
  Future<
      ({
        String memberId,
        String name,
        DocumentReference<Map<String, dynamic>>? ref
      })?> _resolveMember(User user) async {
    try {
      final idx =
          await widget.companyId.collection('memberByUid').doc(user.uid).get();
      final memberId = idx.data()?['memberId'] as String?;
      if (memberId != null && memberId.isNotEmpty) {
        final ref = widget.companyId.collection('member').doc(memberId);
        final memberSnap = await ref.get();
        final name = (memberSnap.data()?['name'] as String?)?.trim() ?? '';
        return (memberId: memberId, name: name, ref: ref);
      }
    } catch (_) {
      // fall through to auth identity
    }
    final fallbackName =
        (user.displayName?.trim().isNotEmpty ?? false) ? user.displayName! : (user.email ?? 'Unknown');
    return (memberId: '', name: fallbackName, ref: null);
  }

  /// Runs the deterministic ledger critic on the chosen accounts. Returns true
  /// to proceed with the save. When the user accepts the suggested correction,
  /// swaps [_debitAccountRef] and [_creditAccountRef] before returning true.
  Future<bool> _confirmLedgerDirection() async {
    final debit = _debitAccountRef;
    final credit = _creditAccountRef;
    if (debit == null || credit == null) return true;

    Map<String, dynamic>? debitData;
    Map<String, dynamic>? creditData;
    try {
      final results = await Future.wait([debit.get(), credit.get()]);
      debitData = results[0].data();
      creditData = results[1].data();
    } catch (_) {
      return true; // Never block a save on a critic read failure.
    }

    final verdict = critiqueLedgerEntry(
      debitType: (debitData?['type'] ?? '').toString(),
      creditType: (creditData?['type'] ?? '').toString(),
      debitName: (debitData?['name'] ?? '').toString(),
      creditName: (creditData?['name'] ?? '').toString(),
      memo: _memoController.text,
      amount: double.tryParse(_amountController.text.trim()),
    );
    if (verdict.isClean || !mounted) return true;

    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Check this entry'),
        content: Text(verdict.message ?? 'This entry may be reversed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'anyway'),
            child: const Text('Save anyway'),
          ),
          if (verdict.suggestSwap)
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'swap'),
              child: const Text('Swap & save'),
            ),
        ],
      ),
    );

    switch (choice) {
      case 'swap':
        setState(() {
          final tmp = _debitAccountRef;
          _debitAccountRef = _creditAccountRef;
          _creditAccountRef = tmp;
        });
        return true;
      case 'anyway':
        return true;
      default:
        return false;
    }
  }

  Future<void> _captureReceipt() async {
    if (!_canCapture()) return;
    try {
      final image = await _imagePicker.pickImage(source: ImageSource.camera);
      if (image == null) return;
      final bytes = await image.readAsBytes();
      _addAttachment(
        _ReceiptAttachment(
          bytes: bytes,
          name: image.name,
          mimeType: _mimeForName(image.name) ?? 'image/jpeg',
          isImage: true,
        ),
      );
      await _reanalyze();
    } catch (e) {
      _showError('Unable to capture receipt: $e');
    }
  }

  Future<void> _attachReceiptFile() async {
    if (!_canCapture()) return;
    try {
      final result = await FilePicker.platform
          .pickFiles(withData: true, allowMultiple: true);
      if (result == null || result.files.isEmpty) return;
      var added = false;
      for (final file in result.files) {
        Uint8List? bytes = file.bytes;
        if (bytes == null && file.path != null) {
          bytes = await XFile(file.path!).readAsBytes();
        }
        if (bytes == null) continue;
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
        _addAttachment(
          _ReceiptAttachment(
            bytes: bytes,
            name: file.name,
            mimeType: _mimeForName(file.name) ?? 'image/jpeg',
            isImage: imageExtensions.contains(extension),
          ),
        );
        added = true;
      }
      if (added) await _reanalyze();
    } catch (e) {
      _showError('Unable to attach file: $e');
    }
  }

  bool _canCapture() {
    if (_saving) return false;
    if (_processingReceipt) {
      _showError('Please wait for the current analysis to finish.');
      return false;
    }
    return true;
  }

  void _addAttachment(_ReceiptAttachment attachment) {
    setState(() => _receiptImages.add(attachment));
  }

  Future<void> _removeReceiptImage(int index) async {
    if (index < 0 || index >= _receiptImages.length) return;
    setState(() => _receiptImages.removeAt(index));
    if (_receiptImages.isEmpty) {
      setState(() {
        _lineItems = const [];
        _suggestedVendorName = null;
        _suggestedDebitAccountName = null;
        _suggestedCreditAccountName = null;
      });
      return;
    }
    await _reanalyze();
  }

  /// Re-runs extraction across ALL currently captured pages so a multi-photo
  /// receipt is treated as one transaction.
  Future<void> _reanalyze() async {
    if (_receiptImages.isEmpty) return;
    setState(() => _processingReceipt = true);
    try {
      final result = await _receiptService.extractLedgerFields(
        _receiptImages
            .map((a) => ReceiptImageInput(a.bytes, mimeType: a.mimeType))
            .toList(),
        usageSource: 'finances',
        usageSourceContext: 'finance_ledger_form',
      );
      if (!mounted) return;
      _applyReceiptExtraction(result);
      _showError(
        result.hasAnyData
            ? 'Receipt analyzed. Review the breakdown before saving.'
            : 'Receipt analyzed but no structured data was found.',
      );
    } on GeminiReceiptException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Receipt processing failed: $e');
    } finally {
      if (mounted) setState(() => _processingReceipt = false);
    }
  }

  void _applyReceiptExtraction(ReceiptExtractionResult result) {
    setState(() {
      if (result.amount != null) {
        _amountController.text = result.amount!.toStringAsFixed(2);
      }
      if (result.memo != null) {
        _memoController.text = result.memo!;
      }
      if (result.transactionDate != null) {
        _entryDate = result.transactionDate!;
      }
      _lineItems = result.lineItems;
      _suggestedVendorName = result.vendorName ?? _suggestedVendorName;
      _suggestedDebitAccountName =
          result.debitAccountName ?? _suggestedDebitAccountName;
      _suggestedCreditAccountName =
          result.creditAccountName ?? _suggestedCreditAccountName;
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    SnackbarService.instance.showSnackBar(
      SnackBar(duration: const Duration(seconds: 5), content: Text(message)),
    );
  }

  String? _mimeForName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.bmp')) return 'image/bmp';
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    return null;
  }

  double get _lineItemsTotal =>
      _lineItems.fold(0.0, (running, item) => running + (item.amount ?? 0));

  bool get _hasReceiptContent =>
      _receiptImages.isNotEmpty ||
      _existingReceiptUrls.isNotEmpty ||
      _lineItems.isNotEmpty;

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
      body: BookendedCanvas(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_pendingReview) _buildReviewBanner(context),
              _buildReceiptCaptureSection(context),
              if (_hasReceiptContent || _processingReceipt) ...[
                const SizedBox(height: 12),
                _buildBreakdownSection(context),
              ],
              const SizedBox(height: 12),
              _buildEntrySection(context),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CancelSaveBar(
            onCancel: () => Navigator.of(context).pop(),
            onSave: _saving ? null : _save,
            reserveNavBarSpace: false,
          ),
          const DetailsAppBar(title: 'Ledger Entry'),
          const HomeNavBarAdapter(),
        ],
      ),
    );
  }

  Widget _buildReviewBanner(BuildContext context) {
    final theme = Theme.of(context);
    final who = (_scannedByName != null && _scannedByName!.isNotEmpty)
        ? _scannedByName!
        : 'a team member';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.fact_check_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Scanned by $who. Confirm the vendor and account placement, then '
              'save to finish the review.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  // ── Container 1: Receipt Capture ──────────────────────────────────
  Widget _buildReceiptCaptureSection(BuildContext context) {
    final theme = Theme.of(context);
    final canInteract = !_saving && !_processingReceipt;

    return ContainerActionWidget(
      title: 'Receipt Capture',
      actionText: '',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add one or more photos of the receipt. Long receipts can span '
            'several pictures — they are read together as one transaction.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
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
          if (_existingReceiptUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildExistingReceiptThumbs(),
          ],
          if (_receiptImages.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildCapturedThumbs(canInteract),
          ],
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
                Expanded(child: Text('Analyzing receipt...')),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCapturedThumbs(bool canInteract) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < _receiptImages.length; i++)
          _thumb(
            child: _receiptImages[i].isImage
                ? Image.memory(_receiptImages[i].bytes, fit: BoxFit.cover)
                : const Center(child: Icon(Icons.insert_drive_file_outlined)),
            onRemove: canInteract ? () => _removeReceiptImage(i) : null,
          ),
      ],
    );
  }

  Widget _buildExistingReceiptThumbs() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final url in _existingReceiptUrls)
          _thumb(
            child: Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Center(child: Icon(Icons.broken_image_outlined)),
            ),
          ),
      ],
    );
  }

  Widget _thumb({required Widget child, VoidCallback? onRemove}) {
    return SizedBox(
      width: 84,
      height: 84,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(10), child: child),
          if (onRemove != null)
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(2),
                  child: const Icon(Icons.close, size: 16, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Container 2: Items & Categories (AI breakdown preview) ────────
  Widget _buildBreakdownSection(BuildContext context) {
    final theme = Theme.of(context);

    Widget content;
    if (_processingReceipt && _lineItems.isEmpty) {
      content = const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Pulling items from the receipt...'),
      );
    } else if (_lineItems.isEmpty) {
      content = Text(
        'No itemized lines detected yet. Add a clearer photo to break the '
        'receipt out by account.',
        style:
            theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
      );
    } else {
      content = _buildGroupedItems(context);
    }

    return ContainerActionWidget(
      title: 'Items & Categories',
      actionText: '',
      content: content,
    );
  }

  Widget _buildGroupedItems(BuildContext context) {
    final theme = Theme.of(context);
    final groups = <String, List<ReceiptLineItem>>{};
    for (final item in _lineItems) {
      groups.putIfAbsent(item.accountLabel, () => []).add(item);
    }
    final sortedKeys = groups.keys.toList()..sort();

    final children = <Widget>[];
    for (final key in sortedKeys) {
      final items = groups[key]!;
      final subtotal = items.fold(0.0, (s, i) => s + (i.amount ?? 0));
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  key,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                _money(subtotal),
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
      for (final item in items) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 2, bottom: 2),
            child: Row(
              children: [
                Expanded(child: Text(item.description)),
                const SizedBox(width: 8),
                Text(
                  item.amount != null ? _money(item.amount!) : '—',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        );
      }
    }

    children.add(const Divider(height: 20));
    children.add(
      Row(
        children: [
          Expanded(
            child: Text(
              'Total',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Text(
            _money(_lineItemsTotal),
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  static String _money(double value) => '\$${value.toStringAsFixed(2)}';

  // ── Container 3: Vendor & Total (the saved ledger fields) ─────────
  Widget _buildEntrySection(BuildContext context) {
    return ContainerActionWidget(
      title: 'Vendor & Total',
      actionText: '',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
              _maybeAutoSelectVendor(docs);
              return SearchAddSelectDropdown<
                  DocumentReference<Map<String, dynamic>>>(
                label: 'Vendor',
                items: items,
                initialValue: _vendorRef,
                itemLabel: (ref) {
                  final d = docs.firstWhere((doc) => doc.reference == ref,
                      orElse: () => docs.first);
                  return (d.data()['name'] ?? 'Unnamed Vendor') as String;
                },
                onChanged: (val) => setState(() => _vendorRef = val),
              );
            },
          ),
          if (_suggestedVendorName != null && _vendorRef == null) ...[
            const SizedBox(height: 6),
            _suggestionHint('Suggested vendor: $_suggestedVendorName'),
          ],
          const SizedBox(height: 16),
          TextFormField(
            controller: _amountController,
            decoration: const InputDecoration(
              labelText: 'Total amount',
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) => v == null || double.tryParse(v) == null
                ? 'Enter amount'
                : null,
            textInputAction: TextInputAction.next,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _memoController,
            decoration: const InputDecoration(
              labelText: 'Memo',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.done,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<
                      DocumentReference<Map<String, dynamic>>>(
                    initialValue: _debitAccountRef,
                    decoration:
                        const InputDecoration(labelText: 'Debit Account'),
                    items: items,
                    onChanged: (r) => setState(() => _debitAccountRef = r),
                    validator: (v) =>
                        v == null ? 'Select debit account' : null,
                  ),
                  if (_suggestedDebitAccountName != null) ...[
                    const SizedBox(height: 6),
                    _suggestionHint('Suggested: $_suggestedDebitAccountName'),
                  ],
                  const SizedBox(height: 16),
                  DropdownButtonFormField<
                      DocumentReference<Map<String, dynamic>>>(
                    initialValue: _creditAccountRef,
                    decoration:
                        const InputDecoration(labelText: 'Credit Account'),
                    items: items,
                    onChanged: (r) => setState(() => _creditAccountRef = r),
                    validator: (v) =>
                        v == null ? 'Select credit account' : null,
                  ),
                  if (_suggestedCreditAccountName != null) ...[
                    const SizedBox(height: 6),
                    _suggestionHint('Suggested: $_suggestedCreditAccountName'),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _suggestionHint(String text) {
    return Row(
      children: [
        const Icon(Icons.auto_awesome, size: 14, color: Colors.grey),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: Colors.grey.shade700,
            ),
          ),
        ),
      ],
    );
  }

  /// Opportunistically preselects the vendor whose name matches the AI
  /// suggestion, once — only when the user has not chosen one yet.
  void _maybeAutoSelectVendor(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final suggestion = _suggestedVendorName?.trim().toLowerCase();
    if (suggestion == null || suggestion.isEmpty || _vendorRef != null) return;
    QueryDocumentSnapshot<Map<String, dynamic>>? match;
    for (final d in docs) {
      if ((d.data()['name'] ?? '').toString().trim().toLowerCase() ==
          suggestion) {
        match = d;
        break;
      }
    }
    if (match == null) return;
    final ref = match.reference;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _vendorRef == null) {
        setState(() => _vendorRef = ref);
      }
    });
  }
}
