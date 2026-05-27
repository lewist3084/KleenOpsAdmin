// lib/features/tasks/forms/tasks_timecard_form.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kleenops_admin/app/shared_widgets/forms/cancel_save_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/widgets/layout/bookended_canvas.dart';
import 'package:shared_widgets/services/firestore_service.dart';

class TasksTimecardForm extends ConsumerStatefulWidget {
  // Kept for API parity with kleenops; admin uses TOP-LEVEL collections.
  final DocumentReference companyId;
  final String? docId; // if null, we're creating a new timecard

  const TasksTimecardForm({
    super.key,
    required this.companyId,
    this.docId,
  });

  @override
  ConsumerState<TasksTimecardForm> createState() => TasksTimecardFormState();
}

class TasksTimecardFormState extends ConsumerState<TasksTimecardForm> {
  DateTime? _startTime;
  DateTime? _endTime;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.docId != null) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    final docRef =
        FirebaseFirestore.instance.collection('timeline').doc(widget.docId!);
    final docSnap = await docRef.get();
    if (docSnap.exists) {
      final data = docSnap.data()!;
      setState(() {
        _startTime = data['startTime'] != null
            ? (data['startTime'] as Timestamp).toDate()
            : null;
        _endTime = data['endTime'] != null
            ? (data['endTime'] as Timestamp).toDate()
            : null;
      });
    }
  }

  Future<void> saveForm() async {
    setState(() => _loading = true);

    Map<String, dynamic> data = {
      'startTime': _startTime,
      'endTime': _endTime,
      'timelineCategory': "X8yZRs8e8xXyHPl4VNAN",
    };

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final memberByUidSnap = await FirebaseFirestore.instance
            .collection('memberByUid')
            .doc(uid)
            .get();
        final memberData = memberByUidSnap.data();
        if (memberByUidSnap.exists && memberData?['active'] == true) {
          final memberId = memberData?['memberId'] as String?;
          if (memberId != null && memberId.isNotEmpty) {
            data['memberId'] =
                FirebaseFirestore.instance.collection('member').doc(memberId);
          }
        }
      }
    } catch (_) {}

    final collectionRef = FirebaseFirestore.instance.collection('timeline');

    await FirestoreService().saveDocument(
      collectionRef: collectionRef,
      data: data,
      docId: widget.docId,
    );

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _selectStartTime() async {
    DateTime now = DateTime.now();
    final DateTime? datePicked = await showDatePicker(
      context: context,
      initialDate: _startTime ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (datePicked != null) {
      final TimeOfDay? timePicked = await showTimePicker(
        context: context,
        initialTime: _startTime != null
            ? TimeOfDay.fromDateTime(_startTime!)
            : TimeOfDay.now(),
      );
      if (timePicked != null) {
        setState(() {
          _startTime = DateTime(datePicked.year, datePicked.month,
              datePicked.day, timePicked.hour, timePicked.minute);
        });
      }
    }
  }

  Future<void> _selectEndTime() async {
    DateTime now = DateTime.now();
    final DateTime? datePicked = await showDatePicker(
      context: context,
      initialDate: _endTime ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (datePicked != null) {
      final TimeOfDay? timePicked = await showTimePicker(
        context: context,
        initialTime: _endTime != null
            ? TimeOfDay.fromDateTime(_endTime!)
            : TimeOfDay.now(),
      );
      if (timePicked != null) {
        setState(() {
          _endTime = DateTime(datePicked.year, datePicked.month,
              datePicked.day, timePicked.hour, timePicked.minute);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: BookendedCanvas(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              title: Text(
                _startTime != null
                    ? 'Start Time: ${DateFormat('h:mm a').format(_startTime!)}'
                    : 'Select Start Time',
              ),
              trailing: const Icon(Icons.access_time),
              onTap: _selectStartTime,
            ),
            const Divider(),
            ListTile(
              title: Text(
                _endTime != null
                    ? 'End Time: ${DateFormat('h:mm a').format(_endTime!)}'
                    : 'Select End Time',
              ),
              trailing: const Icon(Icons.access_time),
              onTap: _selectEndTime,
            ),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CancelSaveBar(
            onCancel: () => Navigator.of(context).pop(),
            onSave: (_startTime != null && _endTime != null) ? saveForm : null,
            reserveNavBarSpace: false,
          ),
          const DetailsAppBar(title: 'Edit Timecard'),
          const HomeNavBarAdapter(),
        ],
      ),
    );
  }
}
