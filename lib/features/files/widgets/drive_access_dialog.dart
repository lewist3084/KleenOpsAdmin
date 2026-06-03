// Manage-access dialog for a shared drive. Lists every company member with a
// checkbox; the set of checked members becomes the drive's `memberIds`, which
// is exactly what the Firestore rules use to gate shared-drive access.
//
// The signed-in member is always kept checked (and disabled) so the editor
// can't lock the current user â€” or everyone â€” out of the drive.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kleenops_admin/common/utils/snackbar_service.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/features/files/data/drive_model.dart';
import 'package:kleenops_admin/repositories/file_repository.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:shared_widgets/theme/app_palette.dart';

class _Member {
  const _Member({required this.id, required this.name, required this.subtitle});
  final String id;
  final String name;
  final String subtitle;
}

class DriveAccessDialog extends ConsumerStatefulWidget {
  const DriveAccessDialog({
    super.key,
    required this.companyId,
    required this.drive,
  });

  final String companyId;
  final DriveModel drive;

  @override
  ConsumerState<DriveAccessDialog> createState() => _DriveAccessDialogState();
}

class _DriveAccessDialogState extends ConsumerState<DriveAccessDialog> {
  late Future<List<_Member>> _membersFuture;
  late Set<String> _selected;
  String? _selfMemberId;
  final TextEditingController _searchCtl = TextEditingController();
  String _search = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = {...widget.drive.memberIds};
    final userData = ref.read(userDocumentProvider).maybeWhen(
          data: (d) => d,
          orElse: () => const <String, dynamic>{},
        );
    final m = userData['memberRef'];
    _selfMemberId = m is DocumentReference ? m.id : null;
    if (_selfMemberId != null) _selected.add(_selfMemberId!);
    _membersFuture = _loadMembers();
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<List<_Member>> _loadMembers() async {
    // Members live under the overlord doc (`kleenops/{id}/member`); derive the
    // collection from the drive's own ref so we never hard-code the namespace.
    final companyRef = widget.drive.ref.parent.parent;
    if (companyRef == null) return const <_Member>[];
    final snap = await companyRef.collection('member').get();
    final members = snap.docs.map((d) {
      final data = d.data();
      return _Member(
        id: d.id,
        name: _displayName(data),
        subtitle: _subtitle(data),
      );
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return members;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(fileRepositoryProvider).updateDriveAccess(
            driveRef: widget.drive.ref,
            memberIds: _selected.toList(),
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      SnackbarService.instance.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          content: Text('Could not update access: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteScope.of(context);
    return DialogAction(
      title: 'Manage Access â€” ${widget.drive.name}',
      content: SizedBox(
        width: double.maxFinite,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _searchCtl,
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search, size: 20),
                hintText: 'Search people',
                border: OutlineInputBorder(),
              ),
              onChanged: (t) =>
                  setState(() => _search = t.trim().toLowerCase()),
              textInputAction: TextInputAction.search,
              onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<_Member>>(
                future: _membersFuture,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final members = snapshot.data!
                      .where((m) =>
                          _search.isEmpty ||
                          m.name.toLowerCase().contains(_search) ||
                          m.subtitle.toLowerCase().contains(_search))
                      .toList();
                  if (members.isEmpty) {
                    return const Center(child: Text('No people found.'));
                  }
                  return ListView.builder(
                    itemCount: members.length,
                    itemBuilder: (context, i) {
                      final m = members[i];
                      final isSelf = m.id == _selfMemberId;
                      return CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: palette.primary2,
                        checkColor: palette.primary1,
                        value: _selected.contains(m.id),
                        title: Text(m.name),
                        subtitle: Text(isSelf ? 'You' : m.subtitle),
                        onChanged: isSelf
                            ? null
                            : (checked) => setState(() {
                                  if (checked == true) {
                                    _selected.add(m.id);
                                  } else {
                                    _selected.remove(m.id);
                                  }
                                }),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${_selected.length} '
                '${_selected.length == 1 ? 'person has' : 'people have'} '
                'access',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ),
      cancelText: 'Cancel',
      onCancel: () => Navigator.of(context).pop(),
      actionText: _saving ? 'Savingâ€¦' : 'Save',
      onAction: _save,
    );
  }

  static String _displayName(Map<String, dynamic> data) {
    final first = (data['firstName'] as String?)?.trim() ?? '';
    final last = (data['lastName'] as String?)?.trim() ?? '';
    final combined = '$first $last'.trim();
    if (combined.isNotEmpty) return combined;
    for (final key in const ['name', 'displayName', 'fullName']) {
      final v = (data[key] as String?)?.trim() ?? '';
      if (v.isNotEmpty) return v;
    }
    final email = (data['email'] as String?)?.trim() ?? '';
    if (email.isNotEmpty) return email;
    return 'Member';
  }

  static String _subtitle(Map<String, dynamic> data) {
    final role = (data['roleName'] as String?)?.trim() ?? '';
    if (role.isNotEmpty) return role;
    final email = (data['email'] as String?)?.trim() ?? '';
    return email;
  }
}

