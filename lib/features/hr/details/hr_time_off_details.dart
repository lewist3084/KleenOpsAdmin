// lib/features/hr/details/hr_time_off_details.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/container_header.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';

class HrTimeOffDetailsScreen extends ConsumerStatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final String docId;

  const HrTimeOffDetailsScreen({
    super.key,
    required this.companyRef,
    required this.docId,
  });

  @override
  ConsumerState<HrTimeOffDetailsScreen> createState() =>
      _HrTimeOffDetailsScreenState();
}

class _HrTimeOffDetailsScreenState
    extends ConsumerState<HrTimeOffDetailsScreen> {
  Map<String, dynamic>? _data;
  String _memberName = '';
  String _approvedByName = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('timeOff')
          .doc(widget.docId)
          .get();
      if (!snap.exists) return;
      final data = snap.data() ?? {};

      _memberName = await _resolveRefName(data['memberId']);
      _approvedByName = await _resolveRefName(data['approvedBy']);

      if (mounted) {
        setState(() {
          _data = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<String> _resolveRefName(dynamic refVal) async {
    if (refVal == null) return '';
    DocumentReference? ref;
    if (refVal is DocumentReference) {
      ref = refVal;
    } else if (refVal is String && refVal.isNotEmpty) {
      return refVal;
    }
    if (ref == null) return '';

    try {
      final snap = await ref.get();
      final data = snap.data();
      if (data is Map<String, dynamic>) {
        final first = (data['firstName'] ?? '').toString().trim();
        final last = (data['lastName'] ?? '').toString().trim();
        final combined =
            [first, last].where((s) => s.isNotEmpty).join(' ');
        if (combined.isNotEmpty) return combined;
        return (data['name'] ?? ref.id).toString();
      }
    } catch (_) {}
    return ref.id;
  }

  String _formatDate(dynamic val) {
    if (val is Timestamp) {
      return DateFormat('yMMMd').format(val.toDate());
    }
    return '';
  }

  Future<void> _updateStatus(String status) async {
    final docRef = FirebaseFirestore.instance
        .collection('timeOff')
        .doc(widget.docId);

    final updateData = <String, dynamic>{'status': status};

    if (status == 'approved' || status == 'denied') {
      try {
        final userData = await ref.read(userDocumentProvider.future);
        final memberRef = userData['memberRef'];
        if (memberRef is DocumentReference) {
          updateData['approvedBy'] = memberRef;
        }
      } catch (_) {}
    }

    try {
      await docRef.update(updateData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Request ${status == 'approved' ? 'approved' : 'denied'}')),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    }
  }

  Widget _wrapCanvas(Widget child) {
    return StandardCanvas(
      child: SafeArea(
        top: true,
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(child: child),
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: CanvasTopBookend(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: null,
      drawer: const UserDrawer(),
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final menuSections = MenuDrawerSections(
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DetailsAppBar(
                title: 'Time Off Details',
                menuSections: menuSections,
              ),
              const HomeNavBarAdapter(highlightSelected: false),
            ],
          );
        },
      ),
      body: _wrapCanvas(
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _data == null
                  ? const Center(child: Text('Request not found.'))
                  : _buildContent(),
        ),
    );
  }

  Widget _buildContent() {
    final data = _data!;
    final status = (data['status'] ?? 'requested').toString();
    final type = (data['type'] ?? '').toString();
    final startDate = _formatDate(data['startDate']);
    final endDate = _formatDate(data['endDate']);
    final hours = data['hours']?.toString() ?? '';
    final notes = (data['notes'] ?? '').toString();
    final isRequested = status.toLowerCase() == 'requested';

    final bottomInset = kBottomNavigationBarHeight +
        16.0 +
        MediaQuery.of(context).padding.bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ContainerHeader(
            showImage: false,
            titleHeader: 'Employee',
            title: _memberName.isNotEmpty ? _memberName : 'Time Off',
            descriptionHeader: 'Status',
            description: status.isNotEmpty
                ? status[0].toUpperCase() + status.substring(1)
                : 'Requested',
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Request Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow('Employee', _memberName),
                  _buildInfoRow('Type',
                      type.isNotEmpty
                          ? type[0].toUpperCase() + type.substring(1)
                          : ''),
                  _buildInfoRow('Status',
                      status.isNotEmpty
                          ? status[0].toUpperCase() + status.substring(1)
                          : ''),
                  _buildInfoRow('Start Date', startDate),
                  _buildInfoRow('End Date', endDate),
                  _buildInfoRow('Hours', hours),
                  if (_approvedByName.isNotEmpty)
                    _buildInfoRow(
                      status == 'denied' ? 'Denied By' : 'Approved By',
                      _approvedByName,
                    ),
                ],
              ),
            ),
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Notes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(notes),
                  ],
                ),
              ),
            ),
          ],
          if (isRequested) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _updateStatus('approved'),
                    icon: const Icon(Icons.check),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _updateStatus('denied'),
                    icon: const Icon(Icons.close),
                    label: const Text('Deny'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
