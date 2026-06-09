// lib/widgets/fields/user_multi_select.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/tiles/selectable_row_tile.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';

import 'package:shared_widgets/search/search_field_action.dart';
import 'package:shared_widgets/buttons/button_select_text.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';

/// A multi-select dropdown for choosing users.
/// It shows only users whose `primaryTeamId` is in [accessibleTeamIds].
class UserMultiSelectDropdown extends StatefulWidget {
  const UserMultiSelectDropdown({
    super.key,
    required this.labelText,
    required this.accessibleTeamIds,
    required this.selectedUsers,
    required this.onChanged,
  });

  final String labelText;
  final List<DocumentReference> accessibleTeamIds;
  final List<DocumentReference> selectedUsers;
  final ValueChanged<List<DocumentReference>> onChanged;

  @override
  State<UserMultiSelectDropdown> createState() =>
      _UserMultiSelectDropdownState();
}

class _UserMultiSelectDropdownState extends State<UserMultiSelectDropdown> {
  /// Download every active user whose primaryTeamId is in [accessibleTeamIds].
  Future<List<Map<String, dynamic>>> _fetchUsers() async {
    final opts = <Map<String, dynamic>>[];
    if (widget.accessibleTeamIds.isEmpty) return opts;

    final companyRef =
        widget.accessibleTeamIds.first.parent.parent as DocumentReference;

    Future<void> getChunk(List<DocumentReference> chunk) async {
      try {
        final qs = await companyRef
            .collection('member')
            .where('primaryTeamId', whereIn: chunk)
            .get();
        for (final doc in qs.docs) {
          final data = doc.data();
          if (data['active'] == true) {
            opts.add({
              'userRef': doc.reference,
              'label': (data['name'] as String?) ?? doc.id,
            });
          }
        }
      } catch (e) {
        if (mounted) {
          SnackbarService.instance.showSnackBar(
            SnackBar(duration: const Duration(seconds: 5), content: Text('Load users failed: $e')),
          );
        }
      }
    }

    const chunkSize = 10;
    for (var i = 0; i < widget.accessibleTeamIds.length; i += chunkSize) {
      await getChunk(widget.accessibleTeamIds.sublist(
        i,
        (i + chunkSize).clamp(0, widget.accessibleTeamIds.length),
      ));
    }

    opts.sort((a, b) =>
        (a['label'] as String).toLowerCase().compareTo((b['label'] as String).toLowerCase()));
    return opts;
  }

  Future<void> _openSelector() async {
    var tmp = List<DocumentReference>.from(widget.selectedUsers);
    final searchCtl = TextEditingController();
    String search = '';

    final opts = await _fetchUsers();
    if (!mounted) return;
    if (opts.isEmpty) {
      SnackbarService.instance.showSnackBar(
        const SnackBar(duration: Duration(seconds: 5), content: Text('No users found.')),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (ctx) => DialogAction(
        title: widget.labelText,
        cancelText: 'Cancel',
        actionText: 'OK',
        onCancel: () => Navigator.of(ctx).pop(),
        onAction: () {
          Navigator.of(ctx).pop();
          widget.onChanged(tmp);
        },
        content: StatefulBuilder(
          builder: (context, setDlg) {
            final filtered = opts
                .where((o) => (o['label'] as String)
                    .toLowerCase()
                    .contains(search))
                .toList();
            final allSelected = filtered.isNotEmpty &&
                filtered.every((o) => tmp.contains(o['userRef']));
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SearchFieldAction(
                  controller: searchCtl,
                  labelText: 'Search users',
                  onChanged: (v) => setDlg(() => search = v.toLowerCase()),
                  actionIcon: Icon(
                    allSelected
                        ? Icons.check_box_outline_blank
                        : Icons.check_box,
                  ),
                  actionHighlighted: true,
                  actionTooltip: allSelected ? 'Deselect all' : 'Select all',
                  onAction: () => setDlg(() {
                    if (!allSelected) {
                      tmp = filtered
                          .map((o) => o['userRef'] as DocumentReference)
                          .toList();
                    } else {
                      tmp.removeWhere(
                          (r) => filtered.map((o) => o['userRef']).contains(r));
                    }
                  }),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.6,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final o = filtered[i];
                      final ref = o['userRef'] as DocumentReference;
                      final selected = tmp.contains(ref);
                      return SelectableRowTile<DocumentReference>(
                        value: ref,
                        label: o['label'] as String,
                        selected: selected,
                        onTap: () => setDlg(() {
                          if (selected) {
                            tmp.remove(ref);
                          } else {
                            tmp.add(ref);
                          }
                        }),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );

    FocusScope.of(context).unfocus();
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => searchCtl.dispose());
      setState(() {});
    }
  }

  /// Fetch a single user's name for display
  Future<String> _getUserName(DocumentReference ref) async {
    final snap = await ref.get();
    final data = snap.data() as Map<String, dynamic>? ?? {};
    return (data['name'] as String?) ?? ref.id;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _openSelector,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: widget.labelText,
          border: const OutlineInputBorder(),
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.selectedUsers.isEmpty
              ? [const Text('Tap to select users')]
              : widget.selectedUsers.map((ref) {
                  return FutureBuilder<String>(
                    future: _getUserName(ref),
                    builder: (ctx, snap) {
                      final label = snap.data ?? '…';
                      return ButtonSelectText(
                        label: label,
                        selected: true,
                        onTap: () {
                          final newSel =
                              List<DocumentReference>.from(widget.selectedUsers);
                          newSel.remove(ref);
                          widget.onChanged(newSel);
                        },
                      );
                    },
                  );
                }).toList(),
        ),
      ),
    );
  }
}
