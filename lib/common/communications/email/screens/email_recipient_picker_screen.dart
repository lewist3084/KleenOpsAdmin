// lib/common/communications/email/screens/email_recipient_picker_screen.dart
//
// Member picker ported from the kleenops app. Lists active company members who
// have a primary email, grouped by team; multi-select; Navigator.pop returns
// the selected addresses as List<String> for the compose screen's To/Cc/Bcc.
//
// ADMIN ADAPTATIONS: resolves the company + member from the mailbox providers
// (not the overlord entity); drops the AI-canvas and external-contacts
// coupling; adds a free-text field so the overlord can address external
// company emails. Selection state lives in a ChangeNotifier so tapping a tile
// only rebuilds the count bar, FAB label, and the affected tile/header.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_widgets/lists/standardView.dart';
import 'package:shared_widgets/tiles/standard_tile_small.dart';
import 'package:shared_widgets/theme/app_palette.dart';
import 'package:shared_widgets/utils/contact_info.dart';

import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import '../providers/email_providers.dart';

class _MemberItem {
  const _MemberItem({
    required this.name,
    required this.email,
    this.avatarUrl,
    this.teamRef,
  });

  final String name;
  final String email;
  final String? avatarUrl;
  final DocumentReference<Map<String, dynamic>>? teamRef;
}

enum EmailRecipientField { to, cc, bcc }

/// Tracks the set of selected emails for the picker.
class _EmailSelection extends ChangeNotifier {
  _EmailSelection(Iterable<String> initial) {
    _values.addAll(initial.map((e) => e.toLowerCase()));
  }

  final Set<String> _values = <String>{};

  int get length => _values.length;
  bool get isEmpty => _values.isEmpty;
  bool get isNotEmpty => _values.isNotEmpty;
  bool contains(String email) => _values.contains(email.toLowerCase());
  List<String> toList() => _values.toList();

  void toggle(String email) {
    final key = email.toLowerCase();
    if (_values.contains(key)) {
      _values.remove(key);
    } else {
      _values.add(key);
    }
    notifyListeners();
  }

  void addAll(Iterable<String> emails) {
    final before = _values.length;
    _values.addAll(emails.map((e) => e.toLowerCase()));
    if (_values.length != before) notifyListeners();
  }

  void removeAll(Iterable<String> emails) {
    final before = _values.length;
    _values.removeAll(emails.map((e) => e.toLowerCase()));
    if (_values.length != before) notifyListeners();
  }

  void clear() {
    if (_values.isEmpty) return;
    _values.clear();
    notifyListeners();
  }
}

class EmailRecipientPickerScreen extends ConsumerStatefulWidget {
  const EmailRecipientPickerScreen({
    super.key,
    required this.field,
    this.initialEmails = const <String>[],
  });

  final EmailRecipientField field;
  final List<String> initialEmails;

  @override
  ConsumerState<EmailRecipientPickerScreen> createState() =>
      _EmailRecipientPickerScreenState();
}

class _EmailRecipientPickerScreenState
    extends ConsumerState<EmailRecipientPickerScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _addController = TextEditingController();
  String _searchQuery = '';
  bool _searchVisible = false;
  late final _EmailSelection _selected = _EmailSelection(widget.initialEmails);

  void _toggleSearch() => setState(() => _searchVisible = !_searchVisible);

  String get _title {
    switch (widget.field) {
      case EmailRecipientField.to:
        return 'To';
      case EmailRecipientField.cc:
        return 'Cc';
      case EmailRecipientField.bcc:
        return 'Bcc';
    }
  }

  bool _looksLikeEmail(String s) {
    final t = s.trim();
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t);
  }

  void _addTyped() {
    final value = _addController.text.trim();
    if (_looksLikeEmail(value)) {
      _selected.addAll([value]);
      _addController.clear();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _addController.dispose();
    _selected.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final companyRef = ref.watch(mailboxCompanyRefProvider);
    final memberRef = ref.watch(mailboxMemberRefProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          IconButton(
            icon: Icon(_searchVisible ? Icons.search_off : Icons.search),
            tooltip: 'Search',
            onPressed: _toggleSearch,
          ),
        ],
      ),
      body: SafeArea(
        child: companyRef == null || memberRef == null
            ? const Center(child: Text('No mailbox available.'))
            : Column(
                children: [
                  // Free-text add (overlord can address external companies).
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _addController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              isDense: true,
                              hintText: 'Add an email address',
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => _addTyped(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          tooltip: 'Add address',
                          onPressed: _addTyped,
                        ),
                      ],
                    ),
                  ),
                  if (_searchVisible)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          isDense: true,
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Search team members',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) =>
                            setState(() => _searchQuery = value.toLowerCase()),
                      ),
                    ),
                  ListenableBuilder(
                    listenable: _selected,
                    builder: (context, _) => _selected.isEmpty
                        ? const SizedBox.shrink()
                        : _SelectedBar(selection: _selected),
                  ),
                  Expanded(
                    child: _MembersList(
                      companyRef: companyRef,
                      memberRef: memberRef,
                      searchQuery: _searchQuery,
                      selection: _selected,
                    ),
                  ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'emailRecipientConfirmFab',
        onPressed: () => Navigator.of(context).pop(_selected.toList()),
        icon: const Icon(Icons.check),
        label: ListenableBuilder(
          listenable: _selected,
          builder: (_, __) => Text(
            _selected.isEmpty ? 'Done' : 'Done (${_selected.length})',
          ),
        ),
      ),
    );
  }
}

class _SelectedBar extends StatelessWidget {
  const _SelectedBar({required this.selection});

  final _EmailSelection selection;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: palette.primary2.withValues(alpha: 0.1),
      child: Row(
        children: [
          Icon(Icons.people, size: 20, color: palette.primary2),
          const SizedBox(width: 8),
          Text(
            '${selection.length} selected',
            style: TextStyle(
              color: palette.primary2,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: selection.clear,
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

class _MembersList extends StatefulWidget {
  const _MembersList({
    required this.companyRef,
    required this.memberRef,
    required this.searchQuery,
    required this.selection,
  });

  final DocumentReference<Map<String, dynamic>> companyRef;
  final DocumentReference<Map<String, dynamic>> memberRef;
  final String searchQuery;
  final _EmailSelection selection;

  @override
  State<_MembersList> createState() => _MembersListState();
}

class _MembersListState extends State<_MembersList> {
  final Map<String, String> _teamNames = {};
  Stream<QuerySnapshot<Map<String, dynamic>>>? _membersStream;

  DocumentReference<Map<String, dynamic>>? _teamRefFromValue(dynamic value) {
    if (value == null) return null;
    if (value is DocumentReference) {
      return value.withConverter<Map<String, dynamic>>(
        fromFirestore: (s, _) => s.data() ?? <String, dynamic>{},
        toFirestore: (m, _) => m,
      );
    }
    if (value is String && value.trim().isNotEmpty) {
      final trimmed = value.trim();
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
    if (cached != null && cached.trim().isNotEmpty) return cached;
    final segments = path.split('/');
    final id = segments.isNotEmpty ? segments.last : path;
    return id.trim().isEmpty ? 'Other' : id;
  }

  int _teamGroupSort(String left, String right) {
    final nameA = left.split('#').last.toLowerCase();
    final nameB = right.split('#').last.toLowerCase();
    return nameA.compareTo(nameB);
  }

  @override
  Widget build(BuildContext context) {
    final query = widget.companyRef
        .collection('member')
        .where('active', isEqualTo: true);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _membersStream ??= query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];

        final members = <_MemberItem>[];
        for (final doc in docs) {
          if (doc.id == widget.memberRef.id) continue;
          final data = doc.data();
          final email = parseContactInfo(data).primaryEmail?.value;
          if (email == null || email.isEmpty) continue;

          final name = (data['name'] as String?) ??
              (data['displayName'] as String?) ??
              'Unknown';
          if (widget.searchQuery.isNotEmpty) {
            final hay = '${name.toLowerCase()} ${email.toLowerCase()}';
            if (!hay.contains(widget.searchQuery)) continue;
          }
          members.add(_MemberItem(
            name: name,
            email: email,
            avatarUrl: data['avatarUrl'] as String?,
            teamRef: _teamRefFromValue(data['primaryTeamId']),
          ));
        }

        members.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

        // Lazy-load team names for grouping headers.
        final teamPaths = members
            .map((m) => m.teamRef?.path)
            .whereType<String>()
            .where((p) => !_teamNames.containsKey(p))
            .toSet();
        if (teamPaths.isNotEmpty) {
          () async {
            final snaps = await Future.wait(
              teamPaths.map((p) => widget.companyRef.firestore.doc(p).get()),
            );
            for (final snap in snaps) {
              final name = (snap.data()?['name'] as String?)?.trim() ?? snap.id;
              if (name.isNotEmpty) _teamNames[snap.reference.path] = name;
            }
            if (mounted) setState(() {});
          }();
        }

        if (members.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.people_outline,
                    size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  widget.searchQuery.isEmpty
                      ? 'No members with email addresses'
                      : 'No members matching "${widget.searchQuery}"',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        final membersByTeam = <String, List<_MemberItem>>{};
        for (final m in members) {
          final teamPath = m.teamRef?.path ?? '';
          membersByTeam.putIfAbsent(teamPath, () => []).add(m);
        }

        return StandardView<_MemberItem>(
          items: members,
          groupBy: (m) {
            final path = m.teamRef?.path ?? '';
            final name = _teamDisplayName(path);
            return '$path#$name';
          },
          groupSort: _teamGroupSort,
          groupCollapsible: true,
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
          itemBuilder: (m) => _MemberTile(
            member: m,
            selection: widget.selection,
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

  final _EmailSelection selection;
  final List<_MemberItem> teamMembers;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteScope.of(context);
    return ListenableBuilder(
      listenable: selection,
      builder: (context, _) {
        final allSelected =
            teamMembers.every((m) => selection.contains(m.email));
        final someSelected =
            teamMembers.any((m) => selection.contains(m.email));
        return GestureDetector(
          onTap: () {
            if (allSelected) {
              selection.removeAll(teamMembers.map((m) => m.email));
            } else {
              selection.addAll(teamMembers.map((m) => m.email));
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
  const _MemberTile({required this.member, required this.selection});

  final _MemberItem member;
  final _EmailSelection selection;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteScope.of(context);
    return ListenableBuilder(
      listenable: selection,
      builder: (context, _) {
        final isSelected = selection.contains(member.email);
        return StandardTileSmallDart(
          label: member.name,
          labelStyle: const TextStyle(fontSize: 14, color: Colors.black),
          secondaryText: member.email,
          leadingWidget: CircleAvatar(
            radius: 18,
            backgroundColor: palette.primary2.withValues(alpha: 0.1),
            backgroundImage: member.avatarUrl != null
                ? NetworkImage(member.avatarUrl!)
                : null,
            child: member.avatarUrl == null
                ? Icon(Icons.badge_outlined, color: palette.primary2, size: 18)
                : null,
          ),
          trailingIcon1:
              isSelected ? Icons.check_box : Icons.check_box_outline_blank,
          trailingIconColor: palette.primary2,
          onTrailing1Tap: () => selection.toggle(member.email),
          onTap: () => selection.toggle(member.email),
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
