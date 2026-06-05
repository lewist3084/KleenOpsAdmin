import 'package:flutter/material.dart';
import 'package:shared_widgets/dialogs/dialog_select.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';

/// Label and icon for the Import entry. Import lives in the user drawer
/// (see `UserDrawer`) so it is always available regardless of the screen.
const String kImportActionLabel = 'Import';
const IconData kImportActionIcon = Icons.move_to_inbox;

enum _ImportOption { pdf, scanText }

Future<void> showImportDialog(BuildContext context) async {
  const importOptions = <_ImportOption>[
    _ImportOption.pdf,
    _ImportOption.scanText,
  ];

  final selection = await showDialog<_ImportOption?>(
    context: context,
    builder: (ctx) => DialogSelect<_ImportOption>(
      title: 'Import',
      items: importOptions,
      tileType: DialogSelectTileType.radio,
      onCancel: () => Navigator.of(ctx).pop(),
      onSubmit: (result) => Navigator.of(ctx).pop(result.firstOrNull),
      itemLabel: _importOptionLabel,
    ),
  );

  if (!context.mounted || selection == null) return;

  switch (selection) {
    case _ImportOption.pdf:
      _showImportPlaceholder(context, 'Import PDF');
      break;
    case _ImportOption.scanText:
      _showImportPlaceholder(context, 'Scan Image Text');
      break;
  }
}

String _importOptionLabel(_ImportOption option) {
  switch (option) {
    case _ImportOption.pdf:
      return 'Import PDF';
    case _ImportOption.scanText:
      return 'Scan Image Text';
  }
}

void _showImportPlaceholder(BuildContext context, String label) {
  SnackbarService.instance.showSnackBar(
    SnackBar(duration: const Duration(seconds: 5), content: Text('$label is not wired yet.')),
  );
}
