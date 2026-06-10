// team_select.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kleenops_admin/repositories/user_repository.dart';

class TeamReferenceDropdown extends StatefulWidget {
  final DocumentReference? selectedTeam;
  final ValueChanged<DocumentReference?> onChanged;

  const TeamReferenceDropdown({
    super.key,
    required this.selectedTeam,
    required this.onChanged,
  });

  @override
  State<TeamReferenceDropdown> createState() => _TeamReferenceDropdownState();
}

class _TeamReferenceDropdownState extends State<TeamReferenceDropdown> {
  List<DocumentReference> _teams = [];
  final Map<String, String> _teamNames = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() => _loading = false);
        return;
      }
      // Find active membership for this user via memberByUid index
      final mSnap = await UserRepository()
          .memberByUidGroup(currentUser.uid)
          .limit(1)
          .get();

      if (mSnap.docs.isEmpty) {
        setState(() => _loading = false);
        return;
      }

      final indexDoc = mSnap.docs.first;
      final indexData = indexDoc.data();
      if (indexData['active'] != true) {
        setState(() => _loading = false);
        return;
      }
      final memberId = indexData['memberId'] as String?;
      if (memberId == null || memberId.isEmpty) {
        setState(() => _loading = false);
        return;
      }
      final companyRef = indexDoc.reference.parent.parent!;
      final memberSnap =
          await companyRef.collection('member').doc(memberId).get();
      if (!memberSnap.exists) {
        setState(() => _loading = false);
        return;
      }
      final memberData = memberSnap.data() ?? {};
      final List<dynamic> teamAccess = memberData['teamAccess'] ?? [];
      final List<DocumentReference> references =
          teamAccess.cast<DocumentReference>();
      _teams = references;

      for (final ref in references) {
        final snap = await ref.get();
        if (snap.exists) {
          final data = snap.data() as Map<String, dynamic>?;
          final name = data?['name'] ?? ref.id;
          _teamNames[ref.id] = name;
        } else {
          _teamNames[ref.id] = ref.id;
        }
      }
    } catch (e) {
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: LinearProgressIndicator(),
      );
    }

    if (_teams.isEmpty) {
      return const Text('No team references found');
    }

    return DropdownButtonFormField<DocumentReference>(
      initialValue: widget.selectedTeam,
      decoration: const InputDecoration(labelText: 'Team'),
      items: _teams.map((ref) {
        final name = _teamNames[ref.id] ?? ref.id;
        return DropdownMenuItem(
          value: ref,
          child: Text(name),
        );
      }).toList(),
      onChanged: widget.onChanged,
      validator: (val) => val == null ? 'Required' : null,
    );
  }
}
