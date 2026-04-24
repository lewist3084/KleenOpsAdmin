import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/containers/container_header.dart';
import 'package:shared_widgets/containers/container_action.dart';

class ScrapeJobDetails extends StatefulWidget {
  final String docId;

  const ScrapeJobDetails({super.key, required this.docId});

  @override
  State<ScrapeJobDetails> createState() => _ScrapeJobDetailsState();
}

class _ScrapeJobDetailsState extends State<ScrapeJobDetails> {
  bool _resuming = false;

  Future<void> _resume(BuildContext context, String jobType) async {
    if (_resuming) return;
    setState(() => _resuming = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('resumeScrapeJob');
      await callable.call({'jobId': widget.docId});
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(
        content: Text('Resume requested — the worker will skip already-staged items.'),
      ));
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('Resume failed: ${e.message ?? e.code}'),
        backgroundColor: Colors.red,
      ));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('Resume failed: $e'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _resuming = false);
    }
  }

  Future<void> _markFailed(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark job as failed?'),
        content: const Text(
          'Use this to unstick a job whose worker was killed. '
          'The job doc will be set to status=failed so the UI unsticks. '
          'You can then Resume to pick up any missing items.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mark failed'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await FirebaseFirestore.instance.collection('scrapeJob').doc(widget.docId).set({
        'status': 'failed',
        'completedAt': FieldValue.serverTimestamp(),
        'errors': FieldValue.arrayUnion([
          {
            'message': 'Manually marked failed from admin UI',
            'timestamp': DateTime.now().toIso8601String(),
          },
        ]),
      }, SetOptions(merge: true));
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Job marked failed.')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('Update failed: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('scrapeJob').doc(widget.docId).snapshots(),
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
        final failedResults = (results['failed'] as num?)?.toInt() ?? 0;
        final failedProgress = (progress['failed'] as num?)?.toInt() ?? 0;
        final failedCount = failedResults > failedProgress ? failedResults : failedProgress;
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

        final isCombined = jobType == 'combined';
        final canResume = isCombined &&
            (status == 'running' ||
                status == 'failed' ||
                status == 'cancelled' ||
                status == 'completed');
        final canMarkFailed = status == 'running';

        return Scaffold(
          appBar: AppBar(
            title: Text(vendorName),
            actions: [
              if (canResume)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: TextButton.icon(
                    onPressed: _resuming ? null : () => _resume(context, jobType),
                    icon: _resuming
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.replay),
                    label: const Text('Resume'),
                  ),
                ),
              if (canMarkFailed)
                IconButton(
                  tooltip: 'Mark failed (unstick)',
                  icon: const Icon(Icons.stop_circle_outlined),
                  onPressed: () => _markFailed(context),
                ),
            ],
          ),
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
                    if (failedCount > 0)
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
