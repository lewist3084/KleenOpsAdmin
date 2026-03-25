// marketplaceProductVariants.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:kleenops_admin/l10n/app_localizations.dart';

String _packagingTypeLabel(AppLocalizations loc, String type) {
  switch (type) {
    case 'case':
      return loc.marketplacePackagingTypeCase;
    case 'pallet':
      return loc.marketplacePackagingTypePallet;
    case 'box':
      return loc.marketplacePackagingTypeBox;
    case 'bag':
      return loc.marketplacePackagingTypeBag;
    case 'bundle':
      return loc.marketplacePackagingTypeBundle;
    case 'pack':
      return loc.marketplacePackagingTypePack;
    case 'each':
    default:
      return loc.marketplacePackagingTypeEach;
  }
}

/// Screen for managing product variants (packaging and parts)
class ProductVariantsScreen extends ConsumerStatefulWidget {
  final String productId;
  final String? productName;

  const ProductVariantsScreen({
    super.key,
    required this.productId,
    this.productName,
  });

  @override
  ConsumerState<ProductVariantsScreen> createState() =>
      _ProductVariantsScreenState();
}

class _ProductVariantsScreenState extends ConsumerState<ProductVariantsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _product;
  List<Map<String, dynamic>> _packagingVariants = [];
  List<Map<String, dynamic>> _componentParts = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadVariants();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadVariants() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('getProductVariants');
      final result = await callable.call({'productId': widget.productId});
      final data = result.data as Map<String, dynamic>;

      setState(() {
        _product = data['product'] as Map<String, dynamic>?;
        _packagingVariants = List<Map<String, dynamic>>.from(
          data['packagingVariants'] ?? [],
        );
        _componentParts = List<Map<String, dynamic>>.from(
          data['componentParts'] ?? [],
        );
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final productName = widget.productName ??
        _product?['name'] ??
        loc.marketplaceDefaultProductName;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.marketplaceVariantsTitle(productName)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(loc.marketplaceErrorLoadingVariants,
                          style: TextStyle(color: Colors.grey[600])),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _loadVariants,
                        child: Text(loc.marketplaceRetry),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Container(
                      color: Colors.white,
                      child: TabBar(
                        controller: _tabController,
                        labelColor: Theme.of(context).primaryColor,
                        unselectedLabelColor: Colors.grey[600],
                        indicatorColor: Theme.of(context).primaryColor,
                        tabs: [
                          Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(loc.marketplacePackagingTab),
                                if (_packagingVariants.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .primaryColor
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${_packagingVariants.length}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(loc.marketplacePartsTab),
                                if (_componentParts.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .primaryColor
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${_componentParts.length}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _PackagingVariantsList(
                            variants: _packagingVariants,
                            parentProductId: widget.productId,
                            onRefresh: _loadVariants,
                          ),
                          _ComponentPartsList(
                            parts: _componentParts,
                            parentProductId: widget.productId,
                            onRefresh: _loadVariants,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final currentTab = _tabController.index;
    if (currentTab == 0) {
      _showAddPackagingDialog(context);
    } else {
      _showAddPartDialog(context);
    }
  }

  void _showAddPackagingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _AddPackagingDialog(
        parentProductId: widget.productId,
        onCreated: _loadVariants,
      ),
    );
  }

  void _showAddPartDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _AddPartDialog(
        parentProductId: widget.productId,
        onCreated: _loadVariants,
      ),
    );
  }
}

/// List of packaging variants
class _PackagingVariantsList extends StatelessWidget {
  final List<Map<String, dynamic>> variants;
  final String parentProductId;
  final VoidCallback onRefresh;

  const _PackagingVariantsList({
    required this.variants,
    required this.parentProductId,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    if (variants.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              loc.marketplaceNoPackagingVariants,
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              loc.marketplaceAddPackagingOptionsHint,
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: variants.length,
        itemBuilder: (context, index) {
          final variant = variants[index];
          return _PackagingVariantTile(
            variant: variant,
            onDelete: () => _deleteVariant(context, variant['id']),
            onEdit: () => _editVariant(context, variant),
          );
        },
      ),
    );
  }

  Future<void> _deleteVariant(BuildContext context, String variantId) async {
    final loc = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.marketplaceDeletePackagingVariantTitle),
        content: Text(loc.marketplaceDeleteCannotUndo),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(loc.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(loc.commonDelete),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('deletePackagingVariant');
      await callable.call({'variantId': variantId});
      onRefresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.marketplaceVariantDeleted)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.marketplaceActionFailed(e.toString()))),
        );
      }
    }
  }

  void _editVariant(BuildContext context, Map<String, dynamic> variant) {
    showDialog(
      context: context,
      builder: (ctx) => _EditPackagingDialog(
        variant: variant,
        onUpdated: onRefresh,
      ),
    );
  }
}

/// Single packaging variant tile
class _PackagingVariantTile extends StatelessWidget {
  final Map<String, dynamic> variant;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _PackagingVariantTile({
    required this.variant,
    required this.onDelete,
    required this.onEdit,
  });

  IconData _getPackagingIcon(String? type) {
    switch (type) {
      case 'case':
        return Icons.inventory_2;
      case 'pallet':
        return Icons.grid_view;
      case 'box':
        return Icons.inbox;
      case 'bag':
        return Icons.shopping_bag;
      case 'bundle':
        return Icons.layers;
      case 'pack':
        return Icons.all_inbox;
      case 'each':
      default:
        return Icons.square_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final name = variant['name']?.toString() ?? loc.commonUnnamed;
    final packagingType = variant['packagingType']?.toString() ?? 'each';
    final packQuantity = variant['packQuantity'] ?? 1;
    final upc = variant['upc']?.toString() ??
        variant['objectBarcode']?.toString() ??
        '';
    final productNumber = variant['productNumber']?.toString() ??
        variant['objectProductCode']?.toString() ??
        '';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getPackagingIcon(packagingType),
            color: Colors.blue,
          ),
        ),
        title: Text(name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(
                  label: Text(_packagingTypeLabel(loc, packagingType)),
                  backgroundColor: Colors.grey[100],
                  labelStyle: const TextStyle(fontSize: 10),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                Text(
                  loc.marketplaceQuantityWithValue('$packQuantity'),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            if (upc.isNotEmpty || productNumber.isNotEmpty)
              Text(
                [
                  if (productNumber.isNotEmpty)
                    loc.marketplaceSkuWithValue(productNumber),
                  if (upc.isNotEmpty) loc.marketplaceUpcWithValue(upc),
                ].join(' • '),
                style: TextStyle(color: Colors.grey[500], fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        isThreeLine: upc.isNotEmpty || productNumber.isNotEmpty,
        trailing: PopupMenuButton<String>(
          onSelected: (action) {
            if (action == 'edit') onEdit();
            if (action == 'delete') onDelete();
          },
          itemBuilder: (ctx) => [
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  const Icon(Icons.edit, size: 18),
                  const SizedBox(width: 8),
                  Text(loc.commonEdit),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  const Icon(Icons.delete, size: 18, color: Colors.red),
                  const SizedBox(width: 8),
                  Text(loc.commonDelete,
                      style: const TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// List of component parts
class _ComponentPartsList extends StatelessWidget {
  final List<Map<String, dynamic>> parts;
  final String parentProductId;
  final VoidCallback onRefresh;

  const _ComponentPartsList({
    required this.parts,
    required this.parentProductId,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    if (parts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.build_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              loc.marketplaceNoComponentParts,
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              loc.marketplaceAddReplacementPartsHint,
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: parts.length,
        itemBuilder: (context, index) {
          final part = parts[index];
          return _ComponentPartTile(
            part: part,
            parentProductId: parentProductId,
            onRemove: () => _removePart(context, part['id']),
          );
        },
      ),
    );
  }

  Future<void> _removePart(BuildContext context, String partId) async {
    final loc = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.marketplaceRemovePartTitle),
        content: Text(loc.marketplaceRemovePartBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(loc.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(loc.marketplaceRemove),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('removeComponentPart');
      await callable.call({
        'parentProductId': parentProductId,
        'partId': partId,
      });
      onRefresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.marketplacePartRemoved)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.marketplaceActionFailed(e.toString()))),
        );
      }
    }
  }
}

/// Single component part tile
class _ComponentPartTile extends StatelessWidget {
  final Map<String, dynamic> part;
  final String parentProductId;
  final VoidCallback onRemove;

  const _ComponentPartTile({
    required this.part,
    required this.parentProductId,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final name = part['name']?.toString() ?? loc.marketplaceUnnamedPart;
    final productNumber = part['productNumber']?.toString() ??
        part['objectProductCode']?.toString() ??
        '';
    final isRequired = part['isRequired'] ?? true;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.build, color: Colors.orange),
        ),
        title: Text(name),
        subtitle: Row(
          children: [
            if (productNumber.isNotEmpty)
              Text(
                loc.marketplaceSkuWithValue(productNumber),
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            if (productNumber.isNotEmpty) const SizedBox(width: 8),
            Chip(
              label: Text(isRequired
                  ? loc.marketplaceRequired
                  : loc.marketplaceOptional),
              backgroundColor: isRequired ? Colors.red[50] : Colors.grey[100],
              labelStyle: TextStyle(
                fontSize: 10,
                color: isRequired ? Colors.red : Colors.grey[600],
              ),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
          onPressed: onRemove,
          tooltip: loc.marketplaceRemoveFromProduct,
        ),
      ),
    );
  }
}

/// Dialog to add a packaging variant
class _AddPackagingDialog extends StatefulWidget {
  final String parentProductId;
  final VoidCallback onCreated;

  const _AddPackagingDialog({
    required this.parentProductId,
    required this.onCreated,
  });

  @override
  State<_AddPackagingDialog> createState() => _AddPackagingDialogState();
}

class _AddPackagingDialogState extends State<_AddPackagingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _upcController = TextEditingController();
  final _skuController = TextEditingController();

  String _packagingType = 'case';
  bool _saving = false;

  static const _packagingTypes = [
    {'value': 'each', 'icon': Icons.square_outlined},
    {'value': 'case', 'icon': Icons.inventory_2},
    {'value': 'box', 'icon': Icons.inbox},
    {'value': 'pallet', 'icon': Icons.grid_view},
    {'value': 'bag', 'icon': Icons.shopping_bag},
    {'value': 'bundle', 'icon': Icons.layers},
    {'value': 'pack', 'icon': Icons.all_inbox},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _upcController.dispose();
    _skuController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_saving) return;

    setState(() => _saving = true);

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('createPackagingVariant');

      await callable.call({
        'parentProductId': widget.parentProductId,
        'packagingType': _packagingType,
        'packQuantity': int.tryParse(_quantityController.text) ?? 1,
        'packName': _nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : null,
        'packUpc': _upcController.text.trim().isNotEmpty
            ? _upcController.text.trim()
            : null,
        'packProductNumber': _skuController.text.trim().isNotEmpty
            ? _skuController.text.trim()
            : null,
      });

      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        Navigator.pop(context);
        widget.onCreated();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.marketplacePackagingVariantCreated)),
        );
      }
    } catch (e) {
      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.marketplaceActionFailed(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(
                      loc.marketplaceAddPackagingVariant,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.marketplacePackagingType,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _packagingTypes.map((type) {
                        final isSelected = _packagingType == type['value'];
                        return ChoiceChip(
                          selected: isSelected,
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                type['icon'] as IconData,
                                size: 16,
                                color: isSelected
                                    ? Theme.of(context).primaryColor
                                    : Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(_packagingTypeLabel(
                                  loc, type['value'] as String)),
                            ],
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() =>
                                  _packagingType = type['value'] as String);
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _quantityController,
                      decoration: InputDecoration(
                        labelText: loc.marketplaceQuantityPerPackageRequired,
                        border: const OutlineInputBorder(),
                        hintText: loc.marketplaceQuantityPerPackageHint,
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final qty = int.tryParse(v ?? '');
                        if (qty == null || qty < 1) {
                          return loc.marketplaceEnterValidQuantity;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: loc.marketplaceVariantNameOptional,
                        border: const OutlineInputBorder(),
                        hintText: loc.marketplaceLeaveBlankAutoGenerate,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _skuController,
                      decoration: InputDecoration(
                        labelText: loc.marketplaceSkuProductNumber,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _upcController,
                      decoration: InputDecoration(
                        labelText: loc.marketplaceUpcBarcode,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(loc.commonCancel),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(loc.commonAdd),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog to edit a packaging variant
class _EditPackagingDialog extends StatefulWidget {
  final Map<String, dynamic> variant;
  final VoidCallback onUpdated;

  const _EditPackagingDialog({
    required this.variant,
    required this.onUpdated,
  });

  @override
  State<_EditPackagingDialog> createState() => _EditPackagingDialogState();
}

class _EditPackagingDialogState extends State<_EditPackagingDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _quantityController;
  late TextEditingController _upcController;
  late TextEditingController _skuController;

  late String _packagingType;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.variant['name']?.toString() ?? '',
    );
    _quantityController = TextEditingController(
      text: (widget.variant['packQuantity'] ?? 1).toString(),
    );
    _upcController = TextEditingController(
      text: widget.variant['upc']?.toString() ??
          widget.variant['objectBarcode']?.toString() ??
          '',
    );
    _skuController = TextEditingController(
      text: widget.variant['productNumber']?.toString() ??
          widget.variant['objectProductCode']?.toString() ??
          '',
    );
    _packagingType = widget.variant['packagingType']?.toString() ?? 'case';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _upcController.dispose();
    _skuController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_saving) return;

    setState(() => _saving = true);

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('updatePackagingVariant');

      await callable.call({
        'variantId': widget.variant['id'],
        'packagingType': _packagingType,
        'packQuantity': int.tryParse(_quantityController.text) ?? 1,
        'packName': _nameController.text.trim(),
        'packUpc': _upcController.text.trim(),
        'packProductNumber': _skuController.text.trim(),
      });

      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        Navigator.pop(context);
        widget.onUpdated();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.marketplaceVariantUpdated)),
        );
      }
    } catch (e) {
      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.marketplaceActionFailed(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(
                      loc.marketplaceEditPackagingVariant,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: loc.marketplaceVariantNameRequired,
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) => v?.trim().isEmpty == true
                          ? loc.marketplaceRequired
                          : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _packagingType,
                      decoration: InputDecoration(
                        labelText: loc.marketplacePackagingType,
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                            value: 'each',
                            child: Text(_packagingTypeLabel(loc, 'each'))),
                        DropdownMenuItem(
                            value: 'case',
                            child: Text(_packagingTypeLabel(loc, 'case'))),
                        DropdownMenuItem(
                            value: 'box',
                            child: Text(_packagingTypeLabel(loc, 'box'))),
                        DropdownMenuItem(
                            value: 'pallet',
                            child: Text(_packagingTypeLabel(loc, 'pallet'))),
                        DropdownMenuItem(
                            value: 'bag',
                            child: Text(_packagingTypeLabel(loc, 'bag'))),
                        DropdownMenuItem(
                            value: 'bundle',
                            child: Text(_packagingTypeLabel(loc, 'bundle'))),
                        DropdownMenuItem(
                            value: 'pack',
                            child: Text(_packagingTypeLabel(loc, 'pack'))),
                      ],
                      onChanged: (v) => setState(() => _packagingType = v!),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _quantityController,
                      decoration: InputDecoration(
                        labelText: loc.marketplaceQuantityPerPackageRequired,
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final qty = int.tryParse(v ?? '');
                        if (qty == null || qty < 1) {
                          return loc.marketplaceEnterValidQuantity;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _skuController,
                      decoration: InputDecoration(
                        labelText: loc.marketplaceSkuProductNumber,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _upcController,
                      decoration: InputDecoration(
                        labelText: loc.marketplaceUpcBarcode,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(loc.commonCancel),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(loc.commonSave),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog to add a component part
class _AddPartDialog extends StatefulWidget {
  final String parentProductId;
  final VoidCallback onCreated;

  const _AddPartDialog({
    required this.parentProductId,
    required this.onCreated,
  });

  @override
  State<_AddPartDialog> createState() => _AddPartDialogState();
}

class _AddPartDialogState extends State<_AddPartDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _searchController = TextEditingController();

  bool _createNew = true;
  bool _isRequired = true;
  bool _saving = false;
  bool _searching = false;
  List<Map<String, dynamic>> _searchResults = [];
  String? _selectedPartId;

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.length < 2) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _searching = true);

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('searchProductsForLinking');
      final result = await callable.call({
        'query': query,
        'excludeIds': [widget.parentProductId],
        'limit': 10,
      });

      setState(() {
        _searchResults =
            List<Map<String, dynamic>>.from(result.data['products'] ?? []);
        _searching = false;
      });
    } catch (e) {
      setState(() {
        _searchResults = [];
        _searching = false;
      });
    }
  }

  Future<void> _save() async {
    if (_createNew && !_formKey.currentState!.validate()) return;
    if (!_createNew && _selectedPartId == null) {
      final loc = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.marketplaceSelectPartToLink)),
      );
      return;
    }
    if (_saving) return;

    setState(() => _saving = true);

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('createComponentPart');

      await callable.call({
        'parentProductId': widget.parentProductId,
        if (_createNew) ...{
          'partName': _nameController.text.trim(),
          'partProductNumber': _skuController.text.trim().isNotEmpty
              ? _skuController.text.trim()
              : null,
          'isRequired': _isRequired,
        } else ...{
          'partId': _selectedPartId,
        },
      });

      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        Navigator.pop(context);
        widget.onCreated();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.marketplacePartAdded)),
        );
      }
    } catch (e) {
      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.marketplaceActionFailed(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 450, maxHeight: 550),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(
                      loc.marketplaceAddComponentPart,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        selected: _createNew,
                        label: Text(loc.marketplaceCreateNew),
                        onSelected: (_) => setState(() {
                          _createNew = true;
                          _selectedPartId = null;
                        }),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        selected: !_createNew,
                        label: Text(loc.marketplaceLinkExisting),
                        onSelected: (_) => setState(() => _createNew = false),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _createNew
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: loc.marketplacePartNameRequired,
                                border: const OutlineInputBorder(),
                              ),
                              validator: (v) => v?.trim().isEmpty == true
                                  ? loc.marketplaceRequired
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _skuController,
                              decoration: InputDecoration(
                                labelText: loc.marketplaceSkuProductNumber,
                                border: const OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SwitchListTile(
                              title: Text(loc.marketplaceRequiredPart),
                              subtitle: Text(loc.marketplaceRequiredPartHelp),
                              value: _isRequired,
                              onChanged: (v) => setState(() => _isRequired = v),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                labelText: loc.marketplaceSearchProducts,
                                border: const OutlineInputBorder(),
                                suffixIcon: _searching
                                    ? const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        ),
                                      )
                                    : const Icon(Icons.search),
                              ),
                              onChanged: _search,
                            ),
                            const SizedBox(height: 12),
                            if (_searchResults.isNotEmpty)
                              ...(_searchResults.map((product) {
                                final isSelected =
                                    _selectedPartId == product['id'];
                                return Card(
                                  color: isSelected
                                      ? Theme.of(context)
                                          .primaryColor
                                          .withValues(alpha: 0.1)
                                      : null,
                                  child: ListTile(
                                    leading: Icon(
                                      isSelected
                                          ? Icons.check_circle
                                          : Icons.circle_outlined,
                                      color: isSelected
                                          ? Theme.of(context).primaryColor
                                          : Colors.grey,
                                    ),
                                    title: Text(
                                        product['name'] ?? loc.commonUnnamed),
                                    subtitle: product['productNumber'] != null
                                        ? Text(loc.marketplaceSkuWithValue(
                                            product['productNumber'].toString(),
                                          ))
                                        : null,
                                    onTap: () {
                                      setState(() {
                                        _selectedPartId = product['id'];
                                      });
                                    },
                                  ),
                                );
                              })),
                            if (_searchResults.isEmpty &&
                                _searchController.text.length >= 2 &&
                                !_searching)
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  loc.marketplaceNoProductsFound,
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ),
                          ],
                        ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(loc.commonCancel),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _createNew ? loc.commonAdd : loc.marketplaceLink),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
