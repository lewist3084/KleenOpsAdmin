// lib/features/training/widgets/dialog_assign_trainees.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/features/hr/utils/member_file_images.dart';
import 'package:shared_widgets/buttons/button_select_text.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';

class DialogAssignTrainees extends ConsumerStatefulWidget {
  const DialogAssignTrainees({
    super.key,
    required this.companyRef,
    required this.trainingRef,
    required this.alreadyAssignedMemberIds,
  });

  final DocumentReference<Map<String, dynamic>> companyRef;
  final DocumentReference<Map<String, dynamic>> trainingRef;
  final Set<String> alreadyAssignedMemberIds;

  @override
  ConsumerState<DialogAssignTrainees> createState() =>
      _DialogAssignTraineesState();
}

class _DialogAssignTraineesState extends ConsumerState<DialogAssignTrainees> {
  Future<List<_TeamEntry>>? _teamsFuture;
  DocumentReference<Map<String, dynamic>>? _selectedTeam;

  // memberId -> selected option (persists across team switches)
  final Map<String, _MemberOption> _selected = <String, _MemberOption>{};

  Future<List<_MemberOption>>? _membersFuture;
  String _membersKey = '';

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _teamsFuture = _loadTeams();
  }

  Future<List<_TeamEntry>> _loadTeams() async {
    final snap = await FirebaseFirestore.instance.collection('team').get();
    final entries = snap.docs.map((doc) {
      final data = doc.data();
      final name = (data['name'] as String?)?.trim() ?? '';
      final team = (data['team'] as String?)?.trim() ?? '';
      final label = name.isNotEmpty
          ? name
          : (team.isNotEmpty ? team : doc.id);
      return _TeamEntry(ref: doc.reference, label: label);
    }).toList();
    entries.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return entries;
  }

  Future<List<_MemberOption>> _loadMembers(
    DocumentReference<Map<String, dynamic>> teamRef,
  ) async {
    final snap = await FirebaseFirestore.instance
        .collection('member')
        .where('active', isEqualTo: true)
        .where('primaryTeamId', isEqualTo: teamRef)
        .get();
    final entries = <_MemberOption>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final name = _resolveMemberName(data, doc.id);
      final imageUrl = await MemberFileImages.primaryProfileImageUrl(
        companyRef: widget.companyRef,
        memberId: doc.id,
      );
      entries.add(_MemberOption(
        ref: doc.reference,
        memberId: doc.id,
        name: name,
        imageUrl: imageUrl,
      ));
    }
    entries.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return entries;
  }

  String _resolveMemberName(Map<String, dynamic> data, String fallback) {
    final n = (data['name'] as String?)?.trim();
    if (n != null && n.isNotEmpty) return n;
    final f = (data['firstName'] as String?)?.trim() ?? '';
    final l = (data['lastName'] as String?)?.trim() ?? '';
    final combined = [f, l].where((p) => p.isNotEmpty).join(' ');
    return combined.isEmpty ? fallback : combined;
  }

  void _selectTeam(_TeamEntry entry) {
    if (_selectedTeam?.path == entry.ref.path) return;
    setState(() {
      _selectedTeam = entry.ref;
      _membersKey = entry.ref.path;
      _membersFuture = _loadMembers(entry.ref);
    });
  }

  Future<void> _handleSave() async {
    if (_submitting) return;
    final newAssignees = _selected.values
        .where((m) => !widget.alreadyAssignedMemberIds.contains(m.memberId))
        .toList();
    if (newAssignees.isEmpty) {
      Navigator.of(context).pop(0);
      return;
    }

    setState(() => _submitting = true);
    try {
      final creatorRef = await ref.read(memberDocRefProvider.future);
      final batch = FirebaseFirestore.instance.batch();
      final col = FirebaseFirestore.instance.collection('assignedTraining');
      for (final m in newAssignees) {
        batch.set(col.doc(), {
          'trainingId': widget.trainingRef,
          'memberId': m.ref,
          if (creatorRef != null) 'createdBy': creatorRef,
          'active': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      if (!mounted) return;
      Navigator.of(context).pop(newAssignees.length);
    } catch (e) {
      if (!mounted) return;
      SnackbarService.instance.showSnackBar(
        SnackBar(duration: const Duration(seconds: 5), content: Text('Failed to assign: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DialogAction(
      title: 'Assign Trainees',
      cancelText: 'Cancel',
      actionText: 'Save',
      onCancel: () => Navigator.of(context).pop(),
      onAction: _submitting ? null : _handleSave,
      content: SizedBox(
        width: 480,
        child: FutureBuilder<List<_TeamEntry>>(
          future: _teamsFuture,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final teams = snap.data ?? const <_TeamEntry>[];
            if (teams.isEmpty) {
              return const SizedBox(
                height: 80,
                child: Center(child: Text('No teams in this company.')),
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_submitting) const LinearProgressIndicator(),
                const Text(
                  'Team',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: teams
                      .map((t) => ButtonSelectText(
                            label: t.label,
                            selected: _selectedTeam?.path == t.ref.path,
                            onTap: () => _selectTeam(t),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text(
                      'Members',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    if (_selected.isNotEmpty)
                      Text(
                        '${_pendingNewCount()} new',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildMembersArea(),
              ],
            );
          },
        ),
      ),
    );
  }

  int _pendingNewCount() {
    return _selected.values
        .where((m) => !widget.alreadyAssignedMemberIds.contains(m.memberId))
        .length;
  }

  Widget _buildMembersArea() {
    if (_selectedTeam == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'Select a team to see members.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    return SizedBox(
      height: 320,
      child: FutureBuilder<List<_MemberOption>>(
        key: ValueKey('members-$_membersKey'),
        future: _membersFuture,
        builder: (context, mSnap) {
          if (mSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final members = mSnap.data ?? const <_MemberOption>[];
          if (members.isEmpty) {
            return const Center(
              child: Text('No active members on this team.'),
            );
          }
          return ListView.builder(
            itemCount: members.length,
            itemBuilder: (context, i) {
              final m = members[i];
              final alreadyAssigned =
                  widget.alreadyAssignedMemberIds.contains(m.memberId);
              final isChecked =
                  alreadyAssigned || _selected.containsKey(m.memberId);
              return CheckboxListTile(
                value: isChecked,
                onChanged: alreadyAssigned
                    ? null
                    : (val) {
                        setState(() {
                          if (val == true) {
                            _selected[m.memberId] = m;
                          } else {
                            _selected.remove(m.memberId);
                          }
                        });
                      },
                title: Text(m.name),
                subtitle: alreadyAssigned
                    ? const Text('Already assigned',
                        style: TextStyle(fontSize: 11))
                    : null,
                secondary: CircleAvatar(
                  radius: 18,
                  backgroundImage:
                      m.imageUrl.isNotEmpty ? NetworkImage(m.imageUrl) : null,
                  child: m.imageUrl.isEmpty
                      ? Text(_initials(m.name),
                          style: const TextStyle(fontSize: 12))
                      : null,
                ),
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
              );
            },
          );
        },
      ),
    );
  }

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

class _TeamEntry {
  _TeamEntry({required this.ref, required this.label});
  final DocumentReference<Map<String, dynamic>> ref;
  final String label;
}

class _MemberOption {
  _MemberOption({
    required this.ref,
    required this.memberId,
    required this.name,
    required this.imageUrl,
  });
  final DocumentReference<Map<String, dynamic>> ref;
  final String memberId;
  final String name;
  final String imageUrl;
}
