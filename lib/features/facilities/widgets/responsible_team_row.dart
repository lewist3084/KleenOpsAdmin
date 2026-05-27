// lib/features/facilities/widgets/responsible_team_row.dart
//
// Admin port: top-level `team` collection (no companyRef scoping).
//
// Single "Responsible Team" picker row for the property hierarchy
// (property / building / floor / location). Renders the *effective* team —
// either explicitly set on this doc via `responsibleTeamId`, or inherited
// from an ancestor. Tapping opens a single-select dialog that writes
// `responsibleTeamId` (or clears it to inherit).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:shared_widgets/labels/header_info_icon_value.dart';
import 'package:shared_widgets/tiles/selectable_row_tile.dart';

class ResponsibleTeamRow extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> docRef;

  /// `responsibleTeamId` value on THIS doc (null = inherits).
  final String? localTeamId;

  /// Team resolved from an ancestor (null = no ancestor has a team set).
  final String? inheritedTeamId;

  /// Human-readable name of the ancestor that owns [inheritedTeamId]
  /// (e.g. "Building A"). Surfaced in the picker as "Inherit (from Building A)".
  final String inheritedFromLabel;

  const ResponsibleTeamRow({
    super.key,
    required this.docRef,
    required this.localTeamId,
    this.inheritedTeamId,
    this.inheritedFromLabel = '',
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTeamId = localTeamId ?? inheritedTeamId;
    final isInherited = localTeamId == null && inheritedTeamId != null;

    return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('team')
          .orderBy('name')
          .get(),
      builder: (context, snap) {
        final docs = snap.data?.docs ??
            const <QueryDocumentSnapshot<Map<String, dynamic>>>[];

        String teamName = '';
        if (effectiveTeamId != null && effectiveTeamId.isNotEmpty) {
          final match = docs.where((d) => d.id == effectiveTeamId).toList();
          if (match.isNotEmpty) {
            teamName =
                (match.first.data()['name'] ?? effectiveTeamId).toString();
          } else {
            teamName = effectiveTeamId;
          }
        }
        final display = teamName.isEmpty ? 'Not set' : teamName;
        final suffix = isInherited && inheritedFromLabel.isNotEmpty
            ? '  (from $inheritedFromLabel)'
            : '';

        return InkWell(
          onTap: () => _openPicker(context, docs),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: HeaderInfoIconValue(
              header: 'Responsible Team',
              value: '$display$suffix',
              icon: Icons.group_outlined,
              trailingIcon: Icons.edit_outlined,
              onTrailingPressed: () => _openPicker(context, docs),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openPicker(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    String? draft = localTeamId;
    final inheritLabel =
        inheritedTeamId != null && inheritedFromLabel.isNotEmpty
            ? 'Inherit (from $inheritedFromLabel)'
            : 'Not set';

    final result = await showDialog<_PickerResult>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setLocal) => DialogAction(
            title: 'Responsible Team',
            cancelText: 'Cancel',
            onCancel: () => Navigator.of(ctx2).pop(),
            actionText: 'Save',
            onAction: () => Navigator.of(ctx2).pop(_PickerResult(draft)),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: [
                  SelectableRowTile<String>(
                    value: '',
                    selected: draft == null,
                    label: inheritLabel,
                    onTap: () => setLocal(() => draft = null),
                  ),
                  for (final doc in docs)
                    SelectableRowTile<String>(
                      value: doc.id,
                      selected: draft == doc.id,
                      label: (doc.data()['name'] ?? doc.id).toString(),
                      onTap: () => setLocal(() => draft = doc.id),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (result == null) return;
    if (result.teamId == null) {
      await docRef.update({'responsibleTeamId': FieldValue.delete()});
    } else {
      await docRef.update({'responsibleTeamId': result.teamId});
    }
  }
}

class _PickerResult {
  final String? teamId;
  const _PickerResult(this.teamId);
}
