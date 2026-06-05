// lib/common/communications/texting/screens/new_conversation_screen.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/services/ai/ai_context_service.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:shared_widgets/lists/standardView.dart';
import 'package:kleenops_admin/app/shared_widgets/search/search_control_strip_adapter.dart';
import 'package:shared_widgets/tiles/standard_tile_small.dart';
import 'package:shared_widgets/theme/app_palette.dart';
import '../services/texting_service.dart';
import 'text_conversation_detail_screen.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';

/// What the recipient picker should do once members are selected. The admin
/// app only supports starting text conversations (no in-app voice/video call
/// system), so this is text-only.
enum NewConversationMode { text }

/// Member data model for selection
class _MemberItem {
  final DocumentReference<Map<String, dynamic>> ref;
  final String name;
  final String? avatarUrl;
  final DocumentReference<Map<String, dynamic>>? teamRef;

  /// Whether the member is currently clocked in. Drives the clock badge
  /// on the tile, mirroring the Tasks → Team list.
  final bool clockedIn;

  const _MemberItem({
    required this.ref,
    required this.name,
    this.avatarUrl,
    this.teamRef,
    this.clockedIn = false,
  });
}

/// Selected members keyed by member id. Lives outside `setState` so a
/// tap on a tile only rebuilds the count bar, FAB, and the affected
/// tile/header — not the whole StreamBuilder + StandardView.
class _MembersSelection extends ChangeNotifier {
  final Map<String, _MemberItem> _values = {};

  Map<String, _MemberItem> get values => Map.unmodifiable(_values);
  List<_MemberItem> toList() => _values.values.toList();
  int get length => _values.length;
  bool get isEmpty => _values.isEmpty;
  bool get isNotEmpty => _values.isNotEmpty;
  bool contains(String id) => _values.containsKey(id);

  void toggle(_MemberItem m) {
    if (_values.containsKey(m.ref.id)) {
      _values.remove(m.ref.id);
    } else {
      _values[m.ref.id] = m;
    }
    notifyListeners();
  }

  void addAll(Iterable<_MemberItem> members) {
    var changed = false;
    for (final m in members) {
      if (!_values.containsKey(m.ref.id)) {
        _values[m.ref.id] = m;
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  void removeAll(Iterable<_MemberItem> members) {
    var changed = false;
    for (final m in members) {
      if (_values.remove(m.ref.id) != null) changed = true;
    }
    if (changed) notifyListeners();
  }

  void clear() {
    if (_values.isEmpty) return;
    _values.clear();
    notifyListeners();
  }
}

class NewConversationScreen extends ConsumerStatefulWidget {
  const NewConversationScreen({
    super.key,
    this.mode = NewConversationMode.text,
    this.source,
    this.sourceContext,
    this.roomId,
    this.excludeMemberIds = const <String>{},
  });

  final NewConversationMode mode;
  final String? source;
  final String? sourceContext;

  /// When set, the picker adds the chosen members to this existing live
  /// call (via `createVideoRoom`'s invite path) instead of starting a new
  /// conversation or call.
  final String? roomId;

  /// Member ids already in the call — hidden from the picker so they can't
  /// be invited twice. Only meaningful when [roomId] is set.
  final Set<String> excludeMemberIds;

  @override
  ConsumerState<NewConversationScreen> createState() =>
      _NewConversationScreenState();
}

class _NewConversationScreenState extends ConsumerState<NewConversationScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _loading = false;
  bool _searchVisible = false;
  final _MembersSelection _selectedMembers = _MembersSelection();

  void _toggleSearch() => setState(() => _searchVisible = !_searchVisible);

  @override
  void dispose() {
    _searchController.dispose();
    _selectedMembers.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final companyAsync = ref.watch(companyIdProvider);
    final userDocAsync = ref.watch(userDocumentProvider);
    final controller = ref.read(aiCanvasControllerProvider);
    final menuSections = MenuDrawerSections(
      actions: const <ContentMenuItem>[],
      resources: const <ContentMenuItem>[],
    );

    return Scaffold(
      appBar: null,
      body: SafeArea(
        child: companyAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (companyRef) {
            if (companyRef == null) {
              return const Center(child: Text('No company selected.'));
            }

            return userDocAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (userData) {
                final memberRef = userData['memberRef']
                    as DocumentReference<Map<String, dynamic>>?;
                final teamAccess =
                    (userData['teamAccess'] as List<dynamic>? ?? [])
                        .whereType<DocumentReference>()
                        .toList();

                // Get primary team reference
                DocumentReference<Map<String, dynamic>>? primaryTeamRef;
                final primaryRaw = userData['primaryTeamId'];
                if (primaryRaw is DocumentReference) {
                  primaryTeamRef = primaryRaw.withConverter<Map<String, dynamic>>(
                    fromFirestore: (s, _) => s.data() ?? <String, dynamic>{},
                    toFirestore: (m, _) => m,
                  );
                } else if (primaryRaw is String && primaryRaw.isNotEmpty) {
                  final ref = primaryRaw.contains('/')
                      ? companyRef.firestore.doc(primaryRaw)
                      : companyRef.collection('team').doc(primaryRaw);
                  primaryTeamRef = ref.withConverter(
                    fromFirestore: (s, _) => s.data() ?? <String, dynamic>{},
                    toFirestore: (m, _) => m,
                  );
                }

                if (memberRef == null) {
                  return const Center(child: Text('No member record.'));
                }

                return Column(
                  children: [
                    if (_searchVisible)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: SearchControlStrip(
                          controller: _searchController,
                          hintText: 'Search team members',
                          onChanged: (value) => setState(
                              () => _searchQuery = value.toLowerCase()),
                        ),
                      ),
                    Expanded(
                      child: _MembersList(
                        companyRef: companyRef,
                        memberRef: memberRef,
                        teamAccess: teamAccess,
                        primaryTeamRef: primaryTeamRef,
                        searchQuery: _searchQuery,
                        loading: _loading,
                        selection: _selectedMembers,
                        excludeIds: widget.excludeMemberIds,
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: _titleForMode(),
            onAiPressed: controller.toggle,
            menuSections: menuSections,
            showSearchToggle: true,
            searchActive: _searchVisible,
            onSearchToggle: _toggleSearch,
          ),
          const HomeNavBarAdapter(),
        ],
      ),
      floatingActionButton: ListenableBuilder(
        listenable: _selectedMembers,
        builder: (context, _) {
          if (_selectedMembers.isEmpty) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            heroTag: 'startConversationFab',
            onPressed: _loading ? null : _handleStart,
            icon: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(_fabIconForMode()),
            label: Text(_fabLabelForMode()),
          );
        },
      ),
    );
  }

  String _titleForMode() => 'New Message';

  IconData _fabIconForMode() => Icons.chat;

  String _fabLabelForMode() {
    final count = _selectedMembers.length;
    return count == 1 ? 'Start Chat' : 'Start Group ($count)';
  }

  void _handleStart() {
    final companyAsync = ref.read(companyIdProvider);
    final userDocAsync = ref.read(userDocumentProvider);

    companyAsync.whenData((companyRef) {
      if (companyRef == null) return;

      userDocAsync.whenData((userData) {
        final memberRef = userData['memberRef']
            as DocumentReference<Map<String, dynamic>>?;
        final memberName = (userData['name'] as String?) ??
            (userData['displayName'] as String?) ??
            '';

        if (memberRef == null) return;

        _startConversation(
          companyRef: companyRef,
          memberRef: memberRef,
          memberName: memberName,
          selectedMembers: _selectedMembers.toList(),
        );
      });
    });
  }

  Future<void> _startConversation({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required DocumentReference<Map<String, dynamic>> memberRef,
    required String memberName,
    required List<_MemberItem> selectedMembers,
  }) async {
    if (selectedMembers.isEmpty) return;

    setState(() => _loading = true);

    try {
      final service = TextingService(
        companyRef: companyRef,
        memberRef: memberRef,
        memberName: memberName,
      );

      if (selectedMembers.length == 1) {
        // Direct conversation
        final conversation = await service.getOrCreateDirectConversation(
          otherMemberRef: selectedMembers.first.ref,
          otherMemberName: selectedMembers.first.name,
        );

        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => TextConversationDetailScreen(
              conversationRef: conversation.ref,
            ),
          ),
        );
      } else {
        // Group conversation
        final participantRefs = selectedMembers.map((m) => m.ref).toList();
        final participantNames = selectedMembers.map((m) => m.name).toList();

        // Generate default group title from member names
        final groupTitle = participantNames.length <= 3
            ? participantNames.join(', ')
            : '${participantNames.take(2).join(', ')} +${participantNames.length - 2}';

        final conversation = await service.createGroupConversation(
          title: groupTitle,
          participantRefs: participantRefs,
          participantNames: participantNames,
        );

        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => TextConversationDetailScreen(
              conversationRef: conversation.ref,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        SnackbarService.instance.showSnackBar(
          SnackBar(duration: const Duration(seconds: 5), content: Text('Failed to start conversation: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }
}

class _MembersList extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final DocumentReference<Map<String, dynamic>> memberRef;
  final List<DocumentReference> teamAccess;
  final DocumentReference<Map<String, dynamic>>? primaryTeamRef;
  final String searchQuery;
  final bool loading;
  final _MembersSelection selection;

  /// Member ids to hide from the list (e.g. people already in the call
  /// when this picker is used to add participants mid-call).
  final Set<String> excludeIds;

  const _MembersList({
    required this.companyRef,
    required this.memberRef,
    required this.teamAccess,
    required this.primaryTeamRef,
    required this.searchQuery,
    required this.loading,
    required this.selection,
    this.excludeIds = const <String>{},
  });

  @override
  State<_MembersList> createState() => _MembersListState();
}

class _MembersListState extends State<_MembersList> {
  final Map<String, String> _teamNames = {};

  // Live "on a call" set — members with a `status: joined` participant doc
  // in an active video room or open channel. Drives the "On a call" badge.
  //
  // We deliberately do NOT trust the room/channel's `participantMemberIds`
  // array: that is the *invited* set and is never reconciled when someone
  // declines or leaves, so it reports phantom badges. The `participants`
  // sub-collection is the only accurate source of who actually joined, so
  // each active room/channel gets a sub-listener filtered to `joined`.
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _activeRoomsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _activeChannelsSub;
  // Full doc path -> participants sub-listener.
  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
      _participantSubs = {};
  // Full doc path -> set of memberIds currently joined to that room/channel.
  final Map<String, Set<String>> _joinedByDoc = {};
  // Active doc paths seen by each top-level query, tracked separately so a
  // snapshot from one query never cancels the other's sub-listeners.
  final Set<String> _activeRoomPaths = {};
  final Set<String> _activeChannelPaths = {};
  Set<String> _busyIds = const <String>{};

  @override
  void initState() {
    super.initState();
    _activeRoomsSub = widget.companyRef
        .collection('videoRooms')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .listen((snap) => _syncParticipantListeners(snap, _activeRoomPaths));
    _activeChannelsSub = widget.companyRef
        .collection('open_channels')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .listen(
            (snap) => _syncParticipantListeners(snap, _activeChannelPaths));
  }

  /// Attaches a `participants` sub-listener to every newly-active room or
  /// channel and tears down listeners for docs that are no longer active.
  void _syncParticipantListeners(
    QuerySnapshot<Map<String, dynamic>> snap,
    Set<String> tracked,
  ) {
    final current = snap.docs.map((d) => d.reference.path).toSet();

    for (final path in tracked.difference(current)) {
      _participantSubs.remove(path)?.cancel();
      _joinedByDoc.remove(path);
    }

    for (final doc in snap.docs) {
      final path = doc.reference.path;
      if (_participantSubs.containsKey(path)) continue;
      _participantSubs[path] = doc.reference
          .collection('participants')
          .where('status', isEqualTo: 'joined')
          .snapshots()
          .listen((pSnap) {
        _joinedByDoc[path] = pSnap.docs.map((d) => d.id).toSet();
        _recomputeBusy();
      });
    }

    tracked
      ..clear()
      ..addAll(current);
    _recomputeBusy();
  }

  void _recomputeBusy() {
    final busy = <String>{};
    for (final ids in _joinedByDoc.values) {
      busy.addAll(ids);
    }
    if (mounted) setState(() => _busyIds = busy);
  }

  @override
  void dispose() {
    _activeRoomsSub?.cancel();
    _activeChannelsSub?.cancel();
    for (final sub in _participantSubs.values) {
      sub.cancel();
    }
    _participantSubs.clear();
    super.dispose();
  }

  DocumentReference<Map<String, dynamic>>? _teamRefFromValue(dynamic value) {
    if (value == null) return null;
    if (value is DocumentReference) {
      return value.withConverter<Map<String, dynamic>>(
        fromFirestore: (s, _) => s.data() ?? <String, dynamic>{},
        toFirestore: (m, _) => m,
      );
    }
    if (value is String && value.isNotEmpty) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      final ref = trimmed.contains('/')
          ? widget.companyRef.firestore.doc(trimmed)
          : widget.companyRef.collection('team').doc(trimmed);
      return ref.withConverter<Map<String, dynamic>>(
        fromFirestore: (s, _) => s.data() ?? <String, dynamic>{},
        toFirestore: (m, _) => m,
      );
    }
    return null;
  }

  String _teamDisplayName(String path) {
    final cached = _teamNames[path];
    if (cached != null && cached.trim().isNotEmpty) {
      return cached;
    }
    final segments = path.split('/');
    final id = segments.isNotEmpty ? segments.last : path;
    return id.trim().isEmpty ? 'Unknown team' : id;
  }

  int _teamGroupSort(String left, String right) {
    // Keys are in format: path#displayName
    final nameA = left.split('#').last.toLowerCase();
    final nameB = right.split('#').last.toLowerCase();
    return nameA.compareTo(nameB);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final busyIds = _busyIds;

    // Query members that share teams with current user
    Query<Map<String, dynamic>> query = widget.companyRef.collection('member');

    if (widget.teamAccess.isNotEmpty) {
      query = query.where('teamAccess', arrayContainsAny: widget.teamAccess.take(10).toList());
    }

    query = query.where('active', isEqualTo: true);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];

        // Prefetch team names
        final teamAccessPaths = widget.teamAccess.map((ref) => ref.path).toSet();
        final teamNamePrefetchPaths = teamAccessPaths
            .where((path) => !_teamNames.containsKey(path))
            .toSet();
        if (teamNamePrefetchPaths.isNotEmpty) {
          () async {
            final snapshots = await Future.wait(
              teamNamePrefetchPaths.map(
                (path) => widget.companyRef.firestore.doc(path).get(),
              ),
            );
            for (final snap in snapshots) {
              final data = snap.data();
              final name = (data?['name'] as String?)?.trim() ?? snap.id;
              if (name.isNotEmpty) {
                _teamNames[snap.reference.path] = name;
              }
            }
            if (mounted) setState(() {});
          }();
        }

        // Filter out current user and apply search, then convert to _MemberItem
        final members = docs.where((doc) {
          if (doc.id == widget.memberRef.id) return false;
          if (widget.excludeIds.contains(doc.id)) return false;

          final data = doc.data();
          final name = (data['name'] as String?) ??
              (data['displayName'] as String?) ??
              '';

          if (widget.searchQuery.isNotEmpty) {
            return name.toLowerCase().contains(widget.searchQuery);
          }
          return true;
        }).map((doc) {
          final data = doc.data();
          final teamRef = _teamRefFromValue(data['primaryTeamId']);
          return _MemberItem(
            ref: doc.reference.withConverter<Map<String, dynamic>>(
              fromFirestore: (s, _) => s.data() ?? {},
              toFirestore: (m, _) => m,
            ),
            name: (data['name'] as String?) ??
                (data['displayName'] as String?) ??
                'Unknown',
            avatarUrl: data['avatarUrl'] as String?,
            teamRef: teamRef,
            clockedIn: data['clockedIn'] == true,
          );
        }).toList();

        // Sort alphabetically by name within each group
        members.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

        if (members.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 48,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 12),
                Text(
                  widget.searchQuery.isEmpty
                      ? 'No team members found'
                      : 'No members matching "${widget.searchQuery}"',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        }

        // Group members by team for headerTrailingBuilder
        final membersByTeam = <String, List<_MemberItem>>{};
        for (final member in members) {
          final teamPath = member.teamRef?.path ?? '';
          membersByTeam.putIfAbsent(teamPath, () => []).add(member);
        }

        return StandardView<_MemberItem>(
          items: members,
          groupBy: (member) {
            // Use format: path#displayName for proper grouping and display
            final path = member.teamRef?.path ?? '';
            final name = _teamDisplayName(path);
            return '$path#$name';
          },
          groupSort: _teamGroupSort,
          groupCollapsible: true,
          initialGroupExpandedCallback: widget.primaryTeamRef != null
              ? (key) {
                  if (key is! String) return false;
                  final teamPath = key.split('#').first;
                  return teamPath == widget.primaryTeamRef!.path;
                }
              : null,
          headerIcon: Icons.group,
          headerTrailingBuilder: (key) {
            if (key is! String) return const SizedBox.shrink();
            final teamPath = key.split('#').first;
            final teamMembers = membersByTeam[teamPath] ?? [];
            if (teamMembers.isEmpty) return const SizedBox.shrink();
            return _GroupTrailing(
              selection: widget.selection,
              teamMembers: teamMembers,
            );
          },
          indentGroupedItems: false,
          shrinkWrap: false,
          physics: const AlwaysScrollableScrollPhysics(),
          showDividersInFlat: true,
          enableReorder: false,
          itemBuilder: (member) => _MemberTile(
            member: member,
            selection: widget.selection,
            busy: busyIds.contains(member.ref.id),
          ),
        );
      },
    );
  }
}

class _GroupTrailing extends StatelessWidget {
  const _GroupTrailing({
    required this.selection,
    required this.teamMembers,
  });

  final _MembersSelection selection;
  final List<_MemberItem> teamMembers;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteScope.of(context);
    return ListenableBuilder(
      listenable: selection,
      builder: (context, _) {
        final allSelected =
            teamMembers.every((m) => selection.contains(m.ref.id));
        final someSelected =
            teamMembers.any((m) => selection.contains(m.ref.id));
        return GestureDetector(
          onTap: () {
            if (allSelected) {
              selection.removeAll(teamMembers);
            } else {
              selection.addAll(teamMembers);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              allSelected
                  ? Icons.check_box
                  : (someSelected
                      ? Icons.indeterminate_check_box
                      : Icons.check_box_outline_blank),
              size: 20,
              color: palette.primary2,
            ),
          ),
        );
      },
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.selection,
    this.busy = false,
  });

  final _MemberItem member;
  final _MembersSelection selection;

  /// Whether this member is currently in another call/open channel.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteScope.of(context);
    return ListenableBuilder(
      listenable: selection,
      builder: (context, _) {
        final isSelected = selection.contains(member.ref.id);
        return StandardTileSmallDart(
          label: member.name,
          labelStyle: const TextStyle(fontSize: 14, color: Colors.black),
          secondaryText: busy ? 'On a call' : null,
          secondaryTextIcon: busy ? Icons.phone_in_talk : null,
          secondaryTextStyle: TextStyle(
            fontSize: 11,
            color: Colors.orange.shade800,
            fontWeight: FontWeight.w600,
          ),
          leadingWidget: SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: palette.primary2.withValues(alpha: 0.1),
                  backgroundImage: member.avatarUrl != null
                      ? NetworkImage(member.avatarUrl!)
                      : null,
                  child: member.avatarUrl == null
                      ? Text(
                          member.name.isNotEmpty
                              ? member.name[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: palette.primary2,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        )
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: _ClockBadge(clockedIn: member.clockedIn),
                ),
              ],
            ),
          ),
          trailingIcon1: isSelected
              ? Icons.check_box
              : Icons.check_box_outline_blank,
          trailingIconColor: palette.primary2,
          onTrailing1Tap: () => selection.toggle(member),
          onTap: () => selection.toggle(member),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          tileColor: isSelected
              ? palette.primary2.withValues(alpha: 0.05)
              : Colors.white,
        );
      },
    );
  }
}

/// Small clock-status badge overlaid on a member's avatar, mirroring the
/// clocked-in/out icons used in the Tasks → Team list: a filled clock when
/// the member is on the clock, a person outline when they are off duty.
class _ClockBadge extends StatelessWidget {
  const _ClockBadge({required this.clockedIn});

  final bool clockedIn;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: clockedIn ? 'Clocked in' : 'Off duty',
      child: Container(
        width: 16,
        height: 16,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(
          clockedIn ? Icons.access_time_filled : Icons.person_outline,
          size: 14,
          color: clockedIn ? Colors.green.shade600 : Colors.grey.shade500,
        ),
      ),
    );
  }
}

