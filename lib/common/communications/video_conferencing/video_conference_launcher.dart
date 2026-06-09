import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:shared_widgets/buttons/button_select_text.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:shared_widgets/search/search_field_action.dart';
import 'package:kleenops_admin/widgets/fields/multi_select/user_multi_select.dart';
import 'package:kleenops_admin/services/video_call_overlay_controller.dart';
import 'package:kleenops_admin/services/video_call_service.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';

/// ADMIN: calling identity is the overlord's membership in the TENANT company
/// (where invitees actually ring), not the overlord `kleenops/{id}` entity.
/// Resolved from the mailbox member ref: company = member.parent.parent, plus
/// the member doc's `teamAccess` for the member picker.
class _LauncherIdentity {
  const _LauncherIdentity({
    required this.companyRef,
    required this.memberRef,
    required this.teamAccess,
  });
  final DocumentReference<Map<String, dynamic>> companyRef;
  final DocumentReference<Map<String, dynamic>> memberRef;
  final List<dynamic> teamAccess;
}

final _launcherIdentityProvider =
    FutureProvider.autoDispose<_LauncherIdentity?>((ref) async {
  final memberRef = ref.watch(mailboxMemberRefProvider).asData?.value;
  final companyRef = memberRef?.parent.parent;
  if (memberRef == null || companyRef == null) return null;
  final snap = await memberRef.get();
  final data = snap.data() ?? const <String, dynamic>{};
  return _LauncherIdentity(
    companyRef: companyRef,
    memberRef: memberRef,
    teamAccess: (data['teamAccess'] as List<dynamic>? ?? const []),
  );
});

class VideoConferenceSelection {
  VideoConferenceSelection({
    required this.companyId,
    required this.teamRef,
    required this.teamLabel,
    required this.memberRefs,
    required this.currentMemberId,
    required this.participantMemberIds,
  });

  final String companyId;
  final DocumentReference teamRef;
  final String teamLabel;
  final List<DocumentReference> memberRefs;
  final String currentMemberId;
  final List<String> participantMemberIds;
}

class VideoConferenceLauncher {
  static Future<void> show(
    BuildContext context, {
    VideoCallType callType = VideoCallType.video,
    String? source,
    String? sourceContext,
  }) async {
    final selection = await showDialog<VideoConferenceSelection>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _VideoConferenceDialog(callType: callType),
    );
    if (selection == null) return;

    VideoCallService.instance.startAdHocCall(
      companyId: selection.companyId,
      currentMemberId: selection.currentMemberId,
      participantMemberIds: selection.participantMemberIds,
      teamId: selection.teamRef.path,
      subject: selection.teamLabel,
      callType: callType,
      source: source,
      sourceContext: sourceContext,
    );
  }
}

class _VideoConferenceDialog extends ConsumerStatefulWidget {
  const _VideoConferenceDialog({this.callType = VideoCallType.video});

  final VideoCallType callType;

  @override
  ConsumerState<_VideoConferenceDialog> createState() =>
      _VideoConferenceDialogState();
}

class _VideoConferenceDialogState
    extends ConsumerState<_VideoConferenceDialog> {
  String get _callTitle =>
      widget.callType == VideoCallType.voice ? 'Start Voice Call' : 'Start Video Call';
  DocumentReference? _selectedTeam;
  List<DocumentReference> _selectedMembers = [];
  final Map<String, String> _teamLabelCache = {};
  bool _submitting = false;
  String _teamSearch = '';
  final TextEditingController _teamSearchCtl = TextEditingController();

  @override
  void dispose() {
    _teamSearchCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final identityAsync = ref.watch(_launcherIdentityProvider);

    return identityAsync.when(
      loading: () => _buildProgressDialog(context),
      error: (e, _) =>
          _buildErrorDialog(context, 'Unable to load company information.'),
      data: (identity) {
        if (identity == null) {
          return _buildErrorDialog(
            context,
            'You are not currently associated with an active company.',
          );
        }
        // _buildForm reads userData['memberRef'] + userData['teamAccess'];
        // feed it the tenant-company member identity.
        return _buildForm(context, identity.companyRef, {
          'memberRef': identity.memberRef,
          'teamAccess': identity.teamAccess,
        });
      },
    );
  }

  Widget _buildProgressDialog(BuildContext context) {
    return DialogAction(
      title: _callTitle,
      cancelText: 'Close',
      onCancel: () => Navigator.of(context).pop(),
      showActionButton: false,
      content: const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildErrorDialog(BuildContext context, String message) {
    return DialogAction(
      title: _callTitle,
      cancelText: 'Close',
      onCancel: () => Navigator.of(context).pop(),
      showActionButton: false,
      content: SizedBox(
        height: 120,
        child: Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> companyRef,
    Map<String, dynamic> userData,
  ) {
    final memberRef = userData['memberRef'] as DocumentReference?;
    if (memberRef == null) {
      return _buildErrorDialog(
        context,
        'Unable to resolve your member profile.',
      );
    }

    final rawAccess = (userData['teamAccess'] as List<dynamic>? ?? []);
    final availableTeams = _normalizeTeamRefs(rawAccess, companyRef);

    if (_selectedTeam != null &&
        !availableTeams.any((ref) => ref.path == _selectedTeam!.path)) {
      _selectedTeam = null;
      _selectedMembers = [];
    }

    if (availableTeams.isEmpty) {
      return _buildErrorDialog(
        context,
        'You do not have access to any teams that can be used for a video conference.',
      );
    }

    return FutureBuilder<List<_TeamEntry>>(
      future: _loadTeamEntries(availableTeams),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _buildProgressDialog(context);
        }
        final entries = snapshot.data!;
        final filtered = entries
            .where((entry) =>
                entry.label.toLowerCase().contains(_teamSearch.toLowerCase()))
            .toList();

        return DialogAction(
          title: _callTitle,
          cancelText: 'Cancel',
          actionText: 'Start Call',
          onCancel: () => Navigator.of(context).pop(),
          onAction: () =>
              _submit(context, companyRef, entries, memberRef.id),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_submitting) const LinearProgressIndicator(),
              SearchFieldAction(
                controller: _teamSearchCtl,
                labelText: 'Search teams',
                onChanged: (value) =>
                    setState(() => _teamSearch = value.toLowerCase()),
                actionIcon:
                    Icon(_teamSearch.isEmpty ? Icons.search : Icons.clear),
                actionHighlighted: true,
                actionTooltip: _teamSearch.isEmpty ? 'Search' : 'Clear',
                onAction: () {
                  if (_teamSearch.isNotEmpty) {
                    setState(() {
                      _teamSearchCtl.clear();
                      _teamSearch = '';
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              Text(
                'Teams',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (filtered.isEmpty)
                const Text('No teams match your search.')
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: filtered.map((entry) {
                    final selected = _selectedTeam?.path == entry.ref.path;
                    return ButtonSelectText(
                      label: entry.label,
                      selected: selected,
                      onTap: () {
                        setState(() {
                          _selectedTeam = entry.ref;
                          _selectedMembers = [];
                        });
                      },
                    );
                  }).toList(),
                ),
              const SizedBox(height: 24),
              Opacity(
                opacity: _selectedTeam == null ? 0.6 : 1,
                child: IgnorePointer(
                  ignoring: _selectedTeam == null,
                  child: UserMultiSelectDropdown(
                    labelText: 'Members',
                    accessibleTeamIds:
                        _selectedTeam == null ? [] : [_selectedTeam!],
                    selectedUsers: _selectedMembers,
                    onChanged: (value) => setState(() {
                      _selectedMembers = value;
                    }),
                  ),
                ),
              ),
              if (_selectedTeam == null)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Select a team to choose members.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<List<_TeamEntry>> _loadTeamEntries(
    List<DocumentReference<Map<String, dynamic>>> refs,
  ) async {
    final entries = <_TeamEntry>[];
    for (final ref in refs) {
      final label = await _teamLabel(ref);
      entries.add(_TeamEntry(ref: ref, label: label));
    }
    entries
        .sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return entries;
  }

  List<DocumentReference<Map<String, dynamic>>> _normalizeTeamRefs(
    List<dynamic> raw,
    DocumentReference<Map<String, dynamic>> companyRef,
  ) {
    final seen = <String>{};
    final List<DocumentReference<Map<String, dynamic>>> refs = [];
    for (final entry in raw) {
      DocumentReference<Map<String, dynamic>>? ref;
      if (entry is DocumentReference) {
        ref = entry.withConverter<Map<String, dynamic>>(
          fromFirestore: (s, _) => s.data() ?? <String, dynamic>{},
          toFirestore: (m, _) => m,
        );
      } else if (entry is String) {
        ref = companyRef.collection('team').doc(entry);
      }
      if (ref != null && seen.add(ref.path)) {
        refs.add(ref);
      }
    }
    return refs;
  }

  Future<String> _teamLabel(DocumentReference<Map<String, dynamic>> ref) async {
    final cached = _teamLabelCache[ref.path];
    if (cached != null) return cached;

    final snap = await ref.get();
    final data = snap.data() ?? <String, dynamic>{};
    final label = (data['name'] as String?)?.trim();
    final resolved = (label != null && label.isNotEmpty) ? label : ref.id;
    _teamLabelCache[ref.path] = resolved;
    return resolved;
  }

  Future<void> _submit(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> companyRef,
    List<_TeamEntry> entries,
    String currentMemberId,
  ) async {
    if (_selectedTeam == null) {
      SnackbarService.instance.showSnackBar(
        const SnackBar(duration: Duration(seconds: 5), content: Text('Select a team to start a call.')),
      );
      return;
    }
    if (_selectedMembers.isEmpty) {
      SnackbarService.instance.showSnackBar(
        const SnackBar(duration: Duration(seconds: 5), content: Text('Select at least one member to invite.')),
      );
      return;
    }
    if (_submitting) return;

    setState(() => _submitting = true);
    try {
      final memberIds =
          _resolveMemberIds(_selectedMembers, currentMemberId);
      if (memberIds.isEmpty) {
        SnackbarService.instance.showSnackBar(
          const SnackBar(
              duration: Duration(seconds: 5),
              content: Text('Unable to resolve the selected members.')),
        );
        return;
      }

      final teamLabel = await _teamLabel(
        entries
            .firstWhere((entry) => entry.ref.path == _selectedTeam!.path)
            .ref,
      );

      if (!mounted) return;
      Navigator.of(context).pop(
        VideoConferenceSelection(
          companyId: companyRef.id,
          teamRef: _selectedTeam!,
          teamLabel: teamLabel,
          memberRefs: List<DocumentReference>.from(_selectedMembers),
          currentMemberId: currentMemberId,
          participantMemberIds: memberIds,
        ),
      );
    } catch (e) {
      if (mounted) {
        SnackbarService.instance.showSnackBar(
          SnackBar(duration: const Duration(seconds: 5), content: Text('Unable to start the call: ')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  List<String> _resolveMemberIds(
    List<DocumentReference> refs,
    String currentMemberId,
  ) {
    final memberIds = <String>{};
    for (final ref in refs) {
      final id = ref.id.trim();
      if (id.isNotEmpty) {
        memberIds.add(id);
      }
    }

    if (currentMemberId.isNotEmpty) {
      memberIds.remove(currentMemberId);
    }

    return memberIds.toList();
  }
}

class _TeamEntry {
  _TeamEntry({required this.ref, required this.label});

  final DocumentReference<Map<String, dynamic>> ref;
  final String label;
}
