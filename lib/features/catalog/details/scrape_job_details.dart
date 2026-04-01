import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/containers/container_header.dart';
import 'package:shared_widgets/containers/container_action.dart';

class ScrapeJobDetails extends StatelessWidget {
  final String docId;

  const ScrapeJobDetails({super.key, required this.docId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('scrapeJob').doc(docId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final data = snapshot.data!.data() ?? {};
        final vendorName = (data['vendorName'] ?? 'Scrape Job').toString();
        final brandName = (data['brandName'] ?? '').toString();
        final status = (data['status'] ?? 'unknown').toString();
        final targetUrl = (data['targetUrl'] ?? '').toString();
        final jobType = (data['jobType'] ?? '').toString();

        final results = data['results'] is Map
            ? Map<String, dynamic>.from(data['results'] as Map)
            : <String, dynamic>{};
        final progress = data['progress'] is Map
            ? Map<String, dynamic>.from(data['progress'] as Map)
            : <String, dynamic>{};

        final totalFound = results['totalFound'] ?? results['totalProducts'] ?? 0;
        final stagedCount = results['stagedProducts'] ?? progress['staged'] ?? 0;
        final failedCount = results['failed'] ?? 0;
        final categoryName = (results['categoryName'] ?? '').toString();
        final processed = results['processed'] ?? 0;

        final createdAt = data['createdAt'];
        final startedAt = data['startedAt'];
        final completedAt = data['completedAt'];

        // Calculate duration
        String duration = 'N/A';
        if (startedAt is Timestamp && completedAt is Timestamp) {
          final diff = completedAt.toDate().difference(startedAt.toDate());
          if (diff.inMinutes > 0) {
            duration = '${diff.inMinutes}m ${diff.inSeconds % 60}s';
          } else {
            duration = '${diff.inSeconds}s';
          }
        }

        final statusColor = switch (status) {
          'completed' => Colors.green,
          'running' => Colors.blue,
          'failed' => Colors.red,
          'cancelled' => Colors.grey,
          _ => Colors.orange,
        };

        return Scaffold(
          appBar: AppBar(title: Text(vendorName)),
          body: ListView(
            children: [
              ContainerHeader(
                showImage: false,
                titleHeader: 'Job Name',
                title: vendorName,
                descriptionHeader: 'Brand',
                description: brandName.isNotEmpty ? brandName : 'No brand specified',
                textIcon: Icons.downloading,
                descriptionIcon: Icons.branding_watermark_outlined,
              ),
              ContainerActionWidget(
                title: 'Status',
                actionText: '',
                content: Column(
                  children: [
                    _statusRow(status, statusColor),
                    const SizedBox(height: 8),
                    _row(Icons.category_outlined, 'Job Type', jobType),
                    if (categoryName.isNotEmpty) _row(Icons.folder_outlined, 'Category', categoryName),
                    _row(Icons.link, 'Target URL', targetUrl),
                  ],
                ),
              ),
              ContainerActionWidget(
                title: 'Results',
                actionText: '',
                content: Column(
                  children: [
                    _metricRow(Icons.search, 'Products Found', '$totalFound', Colors.blue),
                    _metricRow(Icons.check_circle_outline, 'Staged', '$stagedCount', Colors.green),
                    _metricRow(Icons.published_with_changes, 'Processed', '$processed', Colors.teal),
                    if ((failedCount as num) > 0)
                      _metricRow(Icons.error_outline, 'Failed', '$failedCount', Colors.red),
                  ],
                ),
              ),
              ContainerActionWidget(
                title: 'Performance',
                actionText: '',
                content: Column(
                  children: [
                    _row(Icons.timer_outlined, 'Duration', duration),
                    _row(Icons.play_arrow_outlined, 'Started', _fmtTs(startedAt)),
                    _row(Icons.stop_outlined, 'Completed', _fmtTs(completedAt)),
                    _row(Icons.calendar_today_outlined, 'Created', _fmtTs(createdAt)),
                    if (totalFound > 0 && startedAt is Timestamp && completedAt is Timestamp) ...[
                      () {
                        final secs = completedAt.toDate().difference(startedAt.toDate()).inSeconds;
                        final perProduct = secs > 0 ? (secs / (totalFound as num)).toStringAsFixed(1) : 'N/A';
                        return _row(Icons.speed, 'Avg per Product', '${perProduct}s');
                      }(),
                    ],
                  ],
                ),
              ),
              if (data['errors'] is List && (data['errors'] as List).isNotEmpty)
                ContainerActionWidget(
                  title: 'Errors',
                  actionText: '',
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final err in data['errors'] as List)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.warning_amber, size: 16, color: Colors.red),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  (err is Map ? (err['message'] ?? err.toString()) : err.toString()).toString(),
                                  style: const TextStyle(fontSize: 12, color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _statusRow(String status, Color color) {
    return Row(
      children: [
        Icon(Icons.circle, size: 14, color: color),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            status.toUpperCase(),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
          ),
        ),
      ],
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
          SizedBox(width: 130, child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13))),
          Expanded(
            child: Text(
              value.isEmpty ? 'N/A' : value,
              style: const TextStyle(fontWeight: FontWeight.w500),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  String _fmtTs(dynamic ts) {
    if (ts is Timestamp) {
      final dt = ts.toDate();
      return '${dt.month}/${dt.day}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    }
    return 'N/A';
  }
}
