// lib/features/finances/forms/finance_account_form.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/widgets/layout/bookended_canvas.dart';
import 'package:kleenops_admin/app/shared_widgets/forms/cancel_save_adapter.dart';
import 'package:shared_widgets/dialogs/dialog_select.dart';
import 'package:shared_widgets/services/firestore_service.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';

class FinanceAccountForm extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final String? docId;

  const FinanceAccountForm({
    super.key,
    required this.companyRef,
    this.docId,
  });

  @override
  State<FinanceAccountForm> createState() => _FinanceAccountFormState();
}

class _FinanceAccountFormState extends State<FinanceAccountForm> {
  final _formKey = GlobalKey<FormState>();
  final _fs = FirestoreService();

  final _nameCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  String _type = 'Asset';
  String? _parentAccountId;

  /// Name as loaded, to detect renames (so we can clear the stale localized
  /// name map that the Balance Sheet / P&L render from).
  String _originalName = '';

  bool _loading = false;
  bool _saving = false;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _accountDocs = [];

  bool get _isEditing => widget.docId != null;

  static const _accountTypes = [
    'Asset',
    'Liability',
    'Equity',
    'Revenue',
    'Expense',
  ];

  @override
  void initState() {
    super.initState();
    _loadAccounts();
    if (_isEditing) _loadExisting();
  }

  Future<void> _loadAccounts() async {
    final snap = await FirebaseFirestore.instance
        .collection('account')
        .orderBy('name')
        .get();
    if (mounted) setState(() => _accountDocs = snap.docs);
  }

  Future<void> _loadExisting() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('account')
          .doc(widget.docId)
          .get();
      final data = snap.data();
      if (data == null) return;

      _nameCtrl.text = (data['name'] ?? '').toString();
      _originalName = _nameCtrl.text;
      _descriptionCtrl.text = (data['description'] ?? '').toString();
      _type = (data['type'] ?? 'Asset').toString();

      final parent = data['parentAccountId'];
      if (parent is DocumentReference) {
        _parentAccountId = parent.id;
      } else if (parent is String && parent.isNotEmpty) {
        _parentAccountId = parent;
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    final newName = _nameCtrl.text.trim();
    final data = <String, dynamic>{
      'name': newName,
      'type': _type,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // On rename, drop the stale localized-name map so every view (Balance
    // Sheet / P&L use `nameLocalized`, the Ledger uses `name`) falls back to
    // the freshly-typed name. Re-localization can repopulate it later.
    if (_isEditing && newName != _originalName) {
      data['nameLocalized'] = FieldValue.delete();
    }

    final desc = _descriptionCtrl.text.trim();
    if (desc.isNotEmpty) {
      data['description'] = desc;
    } else if (_isEditing) {
      data['description'] = FieldValue.delete();
    }

    if (_parentAccountId != null) {
      data['parentAccountId'] =
          FirebaseFirestore.instance.collection('account').doc(_parentAccountId);
    } else if (_isEditing) {
      data['parentAccountId'] = FieldValue.delete();
    }

    if (!_isEditing) {
      data['createdAt'] = FieldValue.serverTimestamp();
      data['balance'] = 0;
    }

    try {
      await _fs.saveDocument(
        collectionRef: FirebaseFirestore.instance.collection('account'),
        data: data,
        docId: widget.docId,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        SnackbarService.instance.showSnackBar(
          SnackBar(duration: const Duration(seconds: 5), content: Text('Failed to save account: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// The doc id of [d]'s parent account (DocumentReference or raw String),
  /// or '' when it is a top-level account.
  String _parentIdOf(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final p = d.data()['parentAccountId'];
    if (p is DocumentReference) return p.id;
    if (p is String) return p;
    return '';
  }

  /// Display name for the currently-selected parent (or the top-level hint).
  String get _parentDisplayName {
    if (_parentAccountId == null) return 'None (top-level account)';
    for (final d in _accountDocs) {
      if (d.id == _parentAccountId) {
        return (d.data()['name'] ?? _parentAccountId).toString();
      }
    }
    return 'None (top-level account)';
  }

  /// Flattens the chart of accounts into a depth-first ordered list with a depth
  /// per node, so the parent picker can indent children under their parents the
  /// same way the Balance Sheet / P&L do.
  List<_AccountOption> _buildAccountTree() {
    final byId = {for (final d in _accountDocs) d.id: d};
    final childrenByParent =
        <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    for (final d in _accountDocs) {
      var pid = _parentIdOf(d);
      // An account whose parent is missing is treated as top-level.
      if (pid.isNotEmpty && !byId.containsKey(pid)) pid = '';
      childrenByParent.putIfAbsent(pid, () => []).add(d);
    }
    for (final list in childrenByParent.values) {
      list.sort((a, b) => (a.data()['name'] ?? '')
          .toString()
          .toLowerCase()
          .compareTo((b.data()['name'] ?? '').toString().toLowerCase()));
    }

    final out = <_AccountOption>[];
    final visited = <String>{};
    void walk(String parentId, int depth) {
      for (final d in childrenByParent[parentId] ?? const []) {
        if (!visited.add(d.id)) continue; // guard against parent cycles
        out.add(_AccountOption(
          id: d.id,
          name: (d.data()['name'] ?? d.id).toString(),
          depth: depth,
        ));
        walk(d.id, depth + 1);
      }
    }

    walk('', 0);
    return out;
  }

  /// Every account that descends from [id] — excluded from the parent picker so
  /// an account can never be made its own (grand)child.
  Set<String> _descendantsOf(String id) {
    final byParent = <String, List<String>>{};
    for (final d in _accountDocs) {
      byParent.putIfAbsent(_parentIdOf(d), () => []).add(d.id);
    }
    final out = <String>{};
    final stack = <String>[id];
    while (stack.isNotEmpty) {
      final cur = stack.removeLast();
      for (final child in byParent[cur] ?? const []) {
        if (out.add(child)) stack.add(child);
      }
    }
    return out;
  }

  Future<void> _pickAccountType() async {
    final result = await showDialog<String>(
      context: context,
      builder: (c) => DialogSelect<String>(
        title: 'Account Type',
        items: _accountTypes,
        tileType: DialogSelectTileType.radio,
        initialSelection: _type,
        itemLabel: (t) => t,
        onCancel: () => Navigator.pop(c),
        onSubmit: (res) => Navigator.pop(c, res.firstOrNull),
      ),
    );
    if (result != null && mounted) setState(() => _type = result);
  }

  Future<void> _pickParentAccount() async {
    final excluded = widget.docId == null
        ? const <String>{}
        : {widget.docId!, ..._descendantsOf(widget.docId!)};
    final options = <_AccountOption>[
      const _AccountOption(
          id: '', name: 'None (top-level account)', depth: 0, isNone: true),
      ..._buildAccountTree().where((o) => !excluded.contains(o.id)),
    ];

    final result = await showDialog<_AccountOption>(
      context: context,
      builder: (c) => DialogSelect<_AccountOption>(
        title: 'Parent Account',
        items: options,
        tileType: DialogSelectTileType.radio,
        initialSelection: options.firstWhere(
          (o) => o.id == (_parentAccountId ?? ''),
          orElse: () => options.first,
        ),
        itemLabel: (o) => o.indentedLabel,
        itemSearchString: (o) => o.name,
        onCancel: () => Navigator.pop(c),
        onSubmit: (res) => Navigator.pop(c, res.firstOrNull),
      ),
    );
    if (result != null && mounted) {
      setState(() => _parentAccountId = result.isNone ? null : result.id);
    }
  }

  /// A read-only, tappable field that opens a [DialogSelect] picker.
  Widget _pickerField({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(value, overflow: TextOverflow.ellipsis),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BookendedCanvas(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Account Name'),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                    textInputAction: TextInputAction.next,
                    onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                  ),
                  const SizedBox(height: 16),
                  _pickerField(
                    label: 'Account Type',
                    value: _type,
                    icon: Icons.category_outlined,
                    onTap: _pickAccountType,
                  ),
                  const SizedBox(height: 16),
                  _pickerField(
                    label: 'Parent Account (optional)',
                    value: _parentDisplayName,
                    icon: Icons.account_tree_outlined,
                    onTap: _pickParentAccount,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionCtrl,
                    decoration: const InputDecoration(labelText: 'Description'),
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 2,
                    maxLines: 4,
                    textInputAction: TextInputAction.newline,
                    onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                  ),
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
            isSaving: _saving,
            reserveNavBarSpace: false,
          ),
          DetailsAppBar(title: _isEditing ? 'Edit Account' : 'New Account'),
          const HomeNavBarAdapter(),
        ],
      ),
    );
  }
}

/// One row in the parent-account picker. [depth] drives the leading indentation
/// so children sit under their parents (mirroring the Balance Sheet / P&L).
/// Equality is by [id] so a stub can preselect the live item.
class _AccountOption {
  const _AccountOption({
    required this.id,
    required this.name,
    required this.depth,
    this.isNone = false,
  });

  final String id;
  final String name;
  final int depth;
  final bool isNone;

  /// Two em-spaces of indentation per depth level, then the account name.
  String get indentedLabel => '${'  ' * depth}$name';

  @override
  bool operator ==(Object other) => other is _AccountOption && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
