// lib/common/communications/phone/screens/call_detail_screen.dart
//
// Ported from the main KleenOps app. Detail view for a single past call,
// opened from the call-history list. Shows call data plus the AI summary
// (when the call was transcribed). The "Call again" action is omitted in the
// admin app — real call placement (Twilio/WebRTC) is out of scope.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:intl/intl.dart';
import 'package:kleenops_admin/common/communications/phone/screens/call_history_screen.dart';

class CallDetailScreen extends StatelessWidget {
  const CallDetailScreen({
    super.key,
    required this.data,
    required this.kind,
  });

  /// The member-timeline call document's data.
  final Map<String, dynamic> data;
  final CallHistoryKind kind;

  bool get _isVideo => kind == CallHistoryKind.video;

  Color get _accent =>
      _isVideo ? const Color(0xFF5E35B1) : const Color(0xFF43A047);

  List<String> get _participantNames =>
      (data['participantNames'] as List?)?.whereType<String>().toList() ??
      const <String>[];

  DateTime? get _when {
    for (final key in const ['timestamp', 'createdAt', 'loggedAt']) {
      final value = data[key];
      if (value is Timestamp) return value.toDate();
    }
    return null;
  }

  List<String> _stringList(String key) {
    final raw = data[key];
    if (raw is! List) return const <String>[];
    return raw
        .map((e) {
          if (e is String) return e;
          if (e is Map) {
            return (e['text'] ?? e['title'] ?? e['description'] ?? '')
                .toString();
          }
          return e.toString();
        })
        .where((s) => s.trim().isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final title =
        (data['title'] as String?) ?? (_isVideo ? 'Video call' : 'Phone call');
    final summary = (data['summary'] as String?)?.trim() ?? '';
    final durationMin = (data['durationMinutes'] as num?)?.toInt();
    final direction = (data['direction'] as String?)?.trim();
    final from = (data['from'] as String?)?.trim();
    final to = (data['to'] as String?)?.trim();
    final loggedBy = (data['loggedByName'] as String?) ??
        (data['createdByName'] as String?);
    final actionItems = _stringList('actionItems');
    final decisions = _stringList('decisions');
    final topics = _stringList('topics');
    final when = _when;

    final detailRows = <Widget>[
      if (_participantNames.isNotEmpty)
        _infoRow(Icons.group_outlined, 'Participants',
            _participantNames.join(', ')),
      if (durationMin != null)
        _infoRow(Icons.timer_outlined, 'Duration', '$durationMin min'),
      if (direction != null && direction.isNotEmpty)
        _infoRow(Icons.swap_horiz, 'Direction',
            '${direction[0].toUpperCase()}${direction.substring(1)}'),
      if (from != null && from.isNotEmpty)
        _infoRow(Icons.call_received, 'From', from),
      if (to != null && to.isNotEmpty) _infoRow(Icons.call_made, 'To', to),
      if (loggedBy != null && loggedBy.isNotEmpty)
        _infoRow(Icons.person_outline, 'Logged by', loggedBy),
    ];

    return Scaffold(
      bottomNavigationBar: const HomeNavBarAdapter(),
      appBar: AppBar(title: const Text('Call details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: _accent.withAlpha(28),
                child: Icon(
                  _isVideo ? Icons.videocam_outlined : Icons.phone_outlined,
                  color: _accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (when != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          DateFormat('EEEE, MMM d, y · h:mm a').format(when),
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          // ── Details ─────────────────────────────────────────────────────
          if (detailRows.isNotEmpty) ...[
            const SizedBox(height: 24),
            _sectionLabel('Details'),
            const SizedBox(height: 8),
            ...detailRows,
          ],

          // ── Summary ─────────────────────────────────────────────────────
          const SizedBox(height: 24),
          _sectionLabel('Summary'),
          const SizedBox(height: 8),
          if (summary.isNotEmpty)
            Text(
              summary,
              style: const TextStyle(fontSize: 14, height: 1.4),
            )
          else
            Text(
              "This call wasn't transcribed — no summary available.",
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade600,
              ),
            ),

          if (actionItems.isNotEmpty) ...[
            const SizedBox(height: 20),
            _sectionLabel('Action items'),
            const SizedBox(height: 8),
            ..._bullets(actionItems),
          ],
          if (decisions.isNotEmpty) ...[
            const SizedBox(height: 20),
            _sectionLabel('Decisions'),
            const SizedBox(height: 8),
            ..._bullets(decisions),
          ],
          if (topics.isNotEmpty) ...[
            const SizedBox(height: 20),
            _sectionLabel('Topics'),
            const SizedBox(height: 8),
            ..._bullets(topics),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: Colors.grey.shade500,
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: Colors.grey.shade500),
          const SizedBox(width: 10),
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _bullets(List<String> items) {
    return items
        .map(
          (item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6, right: 8),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _accent,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(fontSize: 13.5, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        )
        .toList();
  }
}
