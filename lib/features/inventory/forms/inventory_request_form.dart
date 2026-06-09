// lib/features/inventory/forms/inventory_request_form.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/forms/cancel_save_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';
import 'package:kleenops_admin/widgets/layout/bookended_canvas.dart';
import 'package:shared_widgets/services/firestore_service.dart';

class InventoryRequestForm extends StatefulWidget {
  final String? docId;
  // Route to navigate to after save; defaults to the request-form screen
  // (admin has no inventoryRequestDetails route yet).
  final String? detailsRoute;
  const InventoryRequestForm({super.key, this.docId, this.detailsRoute});

  @override
  InventoryRequestFormState createState() => InventoryRequestFormState();
}

class InventoryRequestFormState extends State<InventoryRequestForm> {
  DocumentReference? _selectedTeam;
  List<DocumentReference> _teamRefs = [];
  bool _loadingTeams = true;
  bool _saving = false;

  String? _docId;

  @override
  void initState() {
    super.initState();
    _docId = widget.docId;
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final indexSnap = await FirebaseFirestore.instance
          .collectionGroup('memberByUid')
          .where('uid', isEqualTo: user.uid)
          .where('active', isEqualTo: true)
          .limit(1)
          .get();
      if (indexSnap.docs.isNotEmpty) {
        final indexDoc = indexSnap.docs.first;
        final memberId = indexDoc.data()['memberId'] as String?;
        if (memberId != null && memberId.trim().isNotEmpty) {
          final companyRef = indexDoc.reference.parent.parent;
          if (companyRef != null) {
            final memberSnap = await companyRef
                .collection('member')
                .doc(memberId.trim())
                .get();
            final data = memberSnap.data() ?? <String, dynamic>{};
            final teamAccess = data['teamAccess'] as List<dynamic>? ?? [];
            _teamRefs = teamAccess.cast<DocumentReference>();
          }
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _loadingTeams = false;
    });
    if (_docId != null) {
      await _loadInventoryRequest();
    }
  }

  Future<void> _loadInventoryRequest() async {
    final invRequestDoc = await FirebaseFirestore.instance
        .collection('inventoryRequest')
        .doc(_docId)
        .get();
    if (invRequestDoc.exists) {
      final data = invRequestDoc.data() as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _selectedTeam = data['teamId'] as DocumentReference?;
      });
    }
  }

  Future<List<DropdownMenuItem<DocumentReference>>>
      _buildTeamDropdownItems() async {
    final List<DropdownMenuItem<DocumentReference>> items = [];
    for (var teamRef in _teamRefs) {
      final teamSnap = await teamRef.get();
      final teamName =
          (teamSnap.data() as Map<String, dynamic>?)?['name'] ?? 'Unknown';
      items.add(
        DropdownMenuItem(
          value: teamRef,
          child: Text(teamName),
        ),
      );
    }
    return items;
  }

  Future<void> _save() async {
    if (_selectedTeam == null) {
      SnackbarService.instance.showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 5),
          content: Text('Please select a team'),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    final isNew = _docId == null || _docId!.isEmpty;
    final data = <String, dynamic>{
      'teamId': _selectedTeam,
      'createdAt': FieldValue.serverTimestamp(),
      if (isNew) 'status': 'draft',
    };

    try {
      final invRequestCollection =
          FirebaseFirestore.instance.collection('inventoryRequest');
      DocumentReference<Map<String, dynamic>> docRef;
      if (_docId != null && _docId!.isNotEmpty) {
        docRef = invRequestCollection.doc(_docId);
      } else {
        docRef = invRequestCollection.doc();
      }
      await FirestoreService().saveDocument(
        collectionRef: invRequestCollection,
        data: data,
        docId: docRef.id,
      );
      if (!mounted) return;
      final detailsPath =
          widget.detailsRoute ?? AppRoutePaths.inventoryRequestForm;
      context.go('$detailsPath?docId=${docRef.id}');
    } catch (e) {
      if (!mounted) return;
      SnackbarService.instance.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          content: Text('Error saving request: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BookendedCanvas(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _loadingTeams
              ? const Center(child: CircularProgressIndicator())
              : FutureBuilder<List<DropdownMenuItem<DocumentReference>>>(
                  future: _buildTeamDropdownItems(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return DropdownButtonFormField<DocumentReference>(
                      decoration: const InputDecoration(labelText: 'Team'),
                      items: snapshot.data,
                      initialValue: _selectedTeam,
                      onChanged: (value) {
                        setState(() {
                          _selectedTeam = value;
                        });
                      },
                    );
                  },
                ),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CancelSaveBar(
            onCancel: () => context.pop(),
            onSave: _save,
            isSaving: _saving,
            reserveNavBarSpace: false,
          ),
          const DetailsAppBar(title: 'Inventory Request'),
          const HomeNavBarAdapter(),
        ],
      ),
    );
  }
}
