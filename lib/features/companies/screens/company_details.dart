// lib/features/companies/screens/company_details.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';

import '../../../services/admin_firebase_service.dart';
import '../../../theme/palette.dart';

class CompanyDetails extends StatelessWidget {
  final String companyId;

  const CompanyDetails({super.key, required this.companyId});

  @override
  Widget build(BuildContext context) {
    const palette = adminPalette;
    final svc = AdminFirebaseService.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Company Details'),
        backgroundColor: palette.primary1,
        foregroundColor: Colors.white,
      ),
      body: StandardCanvas(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: svc.companyStream(companyId),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data!.data() ?? {};
            final name = data['name'] as String? ?? '(unnamed)';

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(name,
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text('ID: $companyId',
                      style: Theme.of(context).textTheme.bodySmall),
                  const Divider(height: 32),

                  // Members section
                  Text('Members',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: svc.membersFor(companyId),
                    builder: (context, memberSnap) {
                      if (!memberSnap.hasData) {
                        return const CircularProgressIndicator();
                      }
                      final members = memberSnap.data!.docs;
                      return Column(
                        children: [
                          for (final m in members)
                            ListTile(
                              dense: true,
                              leading: const Icon(Icons.person_outline),
                              title: Text(
                                  m.data()['name'] as String? ?? '(no name)'),
                              subtitle: Text(
                                  m.data()['email'] as String? ?? ''),
                              trailing: Icon(
                                Icons.circle,
                                size: 12,
                                color: m.data()['active'] == true
                                    ? palette.primary4
                                    : Colors.grey,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const Divider(height: 32),

                  // Recent activity
                  Text('Recent Activity',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: svc.timelineFor(companyId, limit: 10),
                    builder: (context, tlSnap) {
                      if (!tlSnap.hasData) {
                        return const CircularProgressIndicator();
                      }
                      final events = tlSnap.data!.docs;
                      if (events.isEmpty) {
                        return const Text('No recent activity.');
                      }
                      return Column(
                        children: [
                          for (final e in events)
                            ListTile(
                              dense: true,
                              leading: const Icon(Icons.history),
                              title: Text(
                                  e.data()['title'] as String? ?? '(event)'),
                              subtitle: Text(
                                  e.data()['description'] as String? ?? ''),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
