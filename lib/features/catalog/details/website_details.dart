import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/containers/container_header.dart';
import 'package:shared_widgets/containers/container_action.dart';
import '../forms/website_form.dart';

class WebsiteDetails extends StatelessWidget {
  final String docId;

  const WebsiteDetails({super.key, required this.docId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('brandOwner').doc(docId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final data = snapshot.data!.data() ?? {};
        final name = (data['name'] ?? '').toString();
        final baseUrl = (data['baseUrl'] ?? '').toString();
        final websiteType = (data['websiteType'] ?? '').toString();
        final notes = (data['notes'] ?? '').toString();
        final rateLimits = data['rateLimits'] is Map
            ? Map<String, dynamic>.from(data['rateLimits'] as Map) : <String, dynamic>{};
        final apiConfig = data['apiConfig'] is Map
            ? Map<String, dynamic>.from(data['apiConfig'] as Map) : <String, dynamic>{};
        final lastScraped = data['lastScrapedAt'];
        final createdAt = data['createdAt'];

        return Scaffold(
          appBar: AppBar(title: Text(name)),
          body: ListView(
            children: [
              ContainerHeader(
                showImage: false,
                titleHeader: 'Company',
                title: name,
                descriptionHeader: 'Website',
                description: baseUrl.isNotEmpty ? baseUrl : 'No URL set',
                textIcon: Icons.business,
                descriptionIcon: Icons.language,
              ),
              ContainerActionWidget(
                title: 'Website Configuration',
                actionText: '',
                content: Column(
                  children: [
                    _row(Icons.dns_outlined, 'Website Type', websiteType.isNotEmpty ? websiteType : 'Not set'),
                    _row(Icons.language, 'Base URL', baseUrl.isNotEmpty ? baseUrl : 'Not set'),
                    _row(Icons.timer_outlined, 'Delay Between Products', '${rateLimits['interItemDelayMs'] ?? 3000} ms'),
                    _row(Icons.format_list_numbered, 'Max Products Per Run', '${rateLimits['maxProductsPerRun'] ?? 200}'),
                  ],
                ),
              ),
              if (apiConfig.isNotEmpty)
                ContainerActionWidget(
                  title: 'API Configuration',
                  actionText: '',
                  content: Column(
                    children: [
                      for (final entry in apiConfig.entries)
                        _row(Icons.api, entry.key, entry.value.toString()),
                    ],
                  ),
                ),
              ContainerActionWidget(
                title: 'Activity',
                actionText: '',
                content: Column(
                  children: [
                    _row(Icons.schedule, 'Last Scraped', _fmtTs(lastScraped)),
                    _row(Icons.calendar_today, 'Created', _fmtTs(createdAt)),
                  ],
                ),
              ),
              if (notes.isNotEmpty)
                ContainerActionWidget(
                  title: 'Notes',
                  actionText: '',
                  content: Text(notes),
                ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => WebsiteForm(docId: docId, data: data)),
            ),
            child: const Icon(Icons.edit),
          ),
        );
      },
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          SizedBox(width: 140, child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13))),
          Expanded(child: Text(value.isEmpty ? 'N/A' : value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  String _fmtTs(dynamic ts) {
    if (ts is Timestamp) {
      final dt = ts.toDate();
      return '${dt.month}/${dt.day}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return 'Never';
  }
}
