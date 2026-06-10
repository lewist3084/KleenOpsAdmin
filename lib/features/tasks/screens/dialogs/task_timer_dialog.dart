// lib/features/tasks/screens/dialogs/task_timer_dialog.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';

class TaskTimerDialog {
  /// True while a stored timer is still counting down (end time in the future).
  static bool isActive(Map<String, dynamic>? data, [DateTime? now]) {
    final end = endTime(data);
    if (end == null) return false;
    return end.isAfter(now ?? DateTime.now());
  }

  /// True when a timer was set but its end time has passed.
  static bool isExpired(Map<String, dynamic>? data, [DateTime? now]) {
    final end = endTime(data);
    if (end == null) return false;
    return !end.isAfter(now ?? DateTime.now());
  }

  static DateTime? endTime(Map<String, dynamic>? data) {
    final raw = data?['timerEndTime'];
    if (raw is Timestamp) return raw.toDate();
    return null;
  }

  static Future<void> show({
    required BuildContext context,
    required DocumentReference<Map<String, dynamic>> timelineRef,
    required Map<String, dynamic> taskData,
    required DocumentReference<Map<String, dynamic>> currentMemberRef,
    required String currentMemberId,
    required String currentMemberName,
  }) {
    return showDialog(
      context: context,
      builder: (_) => _TaskTimerDialogBody(
        timelineRef: timelineRef,
        taskData: taskData,
        currentMemberRef: currentMemberRef,
        currentMemberId: currentMemberId,
        currentMemberName: currentMemberName,
      ),
    );
  }
}

class _TaskTimerDialogBody extends StatefulWidget {
  const _TaskTimerDialogBody({
    required this.timelineRef,
    required this.taskData,
    required this.currentMemberRef,
    required this.currentMemberId,
    required this.currentMemberName,
  });

  final DocumentReference<Map<String, dynamic>> timelineRef;
  final Map<String, dynamic> taskData;
  final DocumentReference<Map<String, dynamic>> currentMemberRef;
  final String currentMemberId;
  final String currentMemberName;

  @override
  State<_TaskTimerDialogBody> createState() => _TaskTimerDialogBodyState();
}

class _TaskTimerDialogBodyState extends State<_TaskTimerDialogBody> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleStart() async {
    final text = _controller.text.trim();
    final minutes = int.tryParse(text);
    if (minutes == null || minutes <= 0) {
      setState(() => _errorText = 'Enter a number of minutes greater than 0.');
      _focusNode.requestFocus();
      return;
    }
    final endTs = Timestamp.fromDate(
      DateTime.now().add(Duration(minutes: minutes)),
    );
    await widget.timelineRef.update({
      'timerEndTime': endTs,
      'timerStartedBy': widget.currentMemberRef,
      'timerStartedByMemberId': widget.currentMemberId,
      'timerStartedByName': widget.currentMemberName,
      'timerNotified': false,
    });
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _handleClearTimer() async {
    await widget.timelineRef.update({
      'timerEndTime': FieldValue.delete(),
      'timerStartedBy': FieldValue.delete(),
      'timerStartedByMemberId': FieldValue.delete(),
      'timerStartedByName': FieldValue.delete(),
      'timerNotified': FieldValue.delete(),
    });
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final activeEnd = TaskTimerDialog.endTime(widget.taskData);
    final hasTimer = activeEnd != null;
    final isExpired = hasTimer && !activeEnd.isAfter(now);

    return DialogAction(
      title: 'Timer',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasTimer) ...[
            OutlinedButton.icon(
              icon: const Icon(Icons.timer_off_outlined),
              label: Text(isExpired ? 'Clear Expired Timer' : 'Cancel Timer'),
              onPressed: _handleClearTimer,
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textInputAction: TextInputAction.done,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            decoration: InputDecoration(
              labelText: 'Minutes',
              border: const OutlineInputBorder(),
              errorText: _errorText,
            ),
            onSubmitted: (_) => _handleStart(),
          ),
        ],
      ),
      cancelText: 'Close',
      actionText: hasTimer ? 'Replace' : 'Start',
      onCancel: () => Navigator.of(context).pop(),
      onAction: _handleStart,
    );
  }
}
