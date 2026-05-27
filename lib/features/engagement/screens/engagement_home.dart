// lib/features/engagement/screens/engagement_home.dart
//
// Displays app owner reports submitted via the user drawer's "Report Issue"
// flow in either kleenops or kleenops_admin. Reports live in the top-level
// `timeline` collection (which only platformAdmin can read per firestore.rules)
// tagged with type='app_owner_report'. Hub menu links to the ported
// Reports/Stats surfaces.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';

class EngagementHome extends StatelessWidget {
  const EngagementHome({super.key});

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

  @override
  Widget build(BuildContext context) {
    Widget buildBottomBar({MenuDrawerSections? menuSections}) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(title: 'Engagement', menuSections: menuSections),
          const HomeNavBarAdapter(),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: null,
      drawer: const UserDrawer(),
      body: _wrapCanvas(const _AppOwnerReportsList()),
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final menuSections = MenuDrawerSections(
            actions: [
              ContentMenuItem(
                icon: Icons.poll_outlined,
                label: 'Reports',
                onTap: () => context.push(AppRoutePaths.engagementReports),
              ),
              ContentMenuItem(
                icon: Icons.bar_chart_outlined,
                label: 'Stats',
                onTap: () => context.push(AppRoutePaths.engagementStats),
              ),
            ],
          );
          return buildBottomBar(menuSections: menuSections);
        },
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
        final bottomInset = kBottomNavigationBarHeight + 16.0 +
            MediaQuery.of(context).padding.bottom;
        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, bottomInset),
              child: const Column(
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
          padding: EdgeInsets.fromLTRB(12, 12, 12, bottomInset),
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
