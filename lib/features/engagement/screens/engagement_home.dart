// lib/features/engagement/screens/engagement_home.dart
//
// Displays app owner reports submitted via the user drawer's "Report Issue"
// flow in either kleenops or kleenops_admin. Reports live in the top-level
// `timeline` collection (which only platformAdmin can read per firestore.rules)
// tagged with type='app_owner_report'.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';

import '../../../app/routes.dart';
import '../../../app/shared_widgets/drawers/user_drawer.dart';
import '../../../theme/palette.dart';

class EngagementHome extends StatelessWidget {
  const EngagementHome({super.key});

  @override
  Widget build(BuildContext context) {
    const palette = adminPalette;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      drawer: const UserDrawer(),
      appBar: AppBar(
        title: const Text('Engagement'),
        backgroundColor: palette.primary1,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutePaths.dashboard),
        ),
      ),
      body: StandardCanvas(
        child: SafeArea(
          top: true,
          bottom: false,
          child: Stack(
            children: [
              const Positioned.fill(child: _AppOwnerReportsList()),
              const Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: CanvasTopBookend(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppOwnerReportsList extends StatelessWidget {
  const _AppOwnerReportsList();

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('timeline')
        .where('type', isEqualTo: 'app_owner_report')
        .orderBy('createdAt', descending: true);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Failed to load reports: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? const [];
        if (docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.flag_outlined, size: 48, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'No app owner reports yet.',
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Reports submitted via the user drawer in either app '
                    'will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final doc = docs[index];
            return _ReportCard(reportRef: doc.reference, data: doc.data());
          },
        );
      },
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.reportRef, required this.data});

  final DocumentReference<Map<String, dynamic>> reportRef;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final subject = (data['subject'] ?? data['name'] ?? '(no subject)') as String;
    final snippet = (data['snippet'] ?? data['message'] ?? '') as String;
    final reporter =
        (data['reporterDisplayName'] ?? data['reporterEmail'] ?? 'Unknown') as String;
    final sourceApp = (data['sourceApp'] ?? 'unknown') as String;
    final status = (data['status'] ?? 'open') as String;
    final ts = data['createdAt'];
    final dateLabel = ts is Timestamp
        ? DateFormat('MMM d, yyyy h:mm a').format(ts.toDate())
        : '';

    final isResolved = status == 'resolved';

    return Card(
      elevation: 1,
      child: ListTile(
        leading: Icon(
          isResolved ? Icons.check_circle : Icons.flag,
          color: isResolved ? Colors.green : Colors.orange,
        ),
        title: Text(
          subject,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (snippet.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 4),
                child: Text(
                  snippet,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 2,
              children: [
                Text(
                  reporter,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                Text(
                  '· $sourceApp',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                if (dateLabel.isNotEmpty)
                  Text(
                    '· $dateLabel',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
        onTap: () => _showDetails(context),
      ),
    );
  }

  Future<void> _showDetails(BuildContext context) async {
    final subject = (data['subject'] ?? data['name'] ?? '(no subject)') as String;
    final message = (data['message'] ?? '') as String;
    final reporter =
        (data['reporterDisplayName'] ?? data['reporterEmail'] ?? 'Unknown') as String;
    final email = (data['reporterEmail'] ?? '') as String;
    final sourceApp = (data['sourceApp'] ?? 'unknown') as String;
    final status = (data['status'] ?? 'open') as String;
    final isResolved = status == 'resolved';

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(subject),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'From: $reporter${email.isNotEmpty && email != reporter ? ' ($email)' : ''}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              Text(
                'App: $sourceApp · Status: $status',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 12),
              Text(message),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          if (!isResolved)
            TextButton(
              onPressed: () async {
                await reportRef.update({
                  'status': 'resolved',
                  'resolvedAt': FieldValue.serverTimestamp(),
                });
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Mark Resolved'),
            ),
        ],
      ),
    );
  }
}
