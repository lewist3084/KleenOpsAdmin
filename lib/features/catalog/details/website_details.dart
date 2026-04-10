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
              _DiscoveredFieldsSection(brandOwnerId: docId),
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

/// "Discovered Fields" section — derives a per-vendor map of what the scraper
/// is actually finding, computed from real `stagedProduct` documents instead
/// of a static configuration. For each unique key seen across the most recent
/// staged products from this brand owner, shows:
///
///   - the field name
///   - coverage (% of products that had a non-empty value for it)
///   - a sample value from one of the products
///
/// This is the lightweight alternative to building a configurable
/// `fieldMappings` config on the brandOwner doc — see the discussion in the
/// commit that added this widget. The reads cap at 100 docs per brand owner.
class _DiscoveredFieldsSection extends StatefulWidget {
  final String brandOwnerId;
  const _DiscoveredFieldsSection({required this.brandOwnerId});

  @override
  State<_DiscoveredFieldsSection> createState() =>
      _DiscoveredFieldsSectionState();
}

class _DiscoveredFieldsSectionState extends State<_DiscoveredFieldsSection> {
  late Future<_DiscoveredFieldsResult> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadDiscoveredFields();
  }

  Future<_DiscoveredFieldsResult> _loadDiscoveredFields() async {
    final snap = await FirebaseFirestore.instance
        .collection('stagedProduct')
        .where('brandOwnerId', isEqualTo: widget.brandOwnerId)
        .limit(100)
        .get();

    final totalDocs = snap.docs.length;
    if (totalDocs == 0) {
      return const _DiscoveredFieldsResult(totalDocs: 0, fields: []);
    }

    // Aggregate keys from each doc's `detailData.allSpecs` map. We track the
    // count of docs that had a non-empty value, and remember a single sample
    // value from the first doc that populated the field.
    final counts = <String, int>{};
    final samples = <String, String>{};

    for (final doc in snap.docs) {
      final data = doc.data();
      final detail = data['detailData'];
      if (detail is! Map) continue;
      final allSpecs = detail['allSpecs'];
      if (allSpecs is! Map) continue;

      for (final entry in allSpecs.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        final asString = _stringify(value);
        if (asString.isEmpty) continue;
        counts[key] = (counts[key] ?? 0) + 1;
        samples.putIfAbsent(key, () => asString);
      }
    }

    final fields = counts.entries
        .map((e) => _DiscoveredField(
              key: e.key,
              count: e.value,
              total: totalDocs,
              sample: samples[e.key] ?? '',
            ))
        .toList()
      ..sort((a, b) {
        // Highest coverage first, then alphabetical for ties.
        final byCount = b.count.compareTo(a.count);
        if (byCount != 0) return byCount;
        return a.key.toLowerCase().compareTo(b.key.toLowerCase());
      });

    return _DiscoveredFieldsResult(totalDocs: totalDocs, fields: fields);
  }

  /// Coerces a stored value into a single-line string for the sample column.
  /// Lists and maps render as their JSON-ish toString clipped — we just need
  /// enough for the user to recognize what kind of data lives there.
  String _stringify(dynamic value) {
    if (value == null) return '';
    if (value is String) return value.trim();
    if (value is num || value is bool) return value.toString();
    if (value is List) return value.isEmpty ? '' : '[${value.length} items]';
    if (value is Map) return value.isEmpty ? '' : '{${value.length} keys}';
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DiscoveredFieldsResult>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return ContainerActionWidget(
            title: 'Discovered Fields',
            actionText: '',
            content: const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (snapshot.hasError) {
          return ContainerActionWidget(
            title: 'Discovered Fields',
            actionText: '',
            content: Text('Error: ${snapshot.error}'),
          );
        }

        final result = snapshot.data!;
        if (result.totalDocs == 0) {
          return ContainerActionWidget(
            title: 'Discovered Fields',
            actionText: '',
            content: Text(
              'No staged products yet for this brand owner — '
              'run a scrape job to see what fields the scraper finds.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          );
        }
        if (result.fields.isEmpty) {
          return ContainerActionWidget(
            title: 'Discovered Fields',
            actionText: '',
            content: Text(
              'Scraped ${result.totalDocs} product(s) but none populated '
              'detailData.allSpecs — check the extractor.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          );
        }

        return ContainerActionWidget(
          title: 'Discovered Fields (${result.fields.length})',
          actionText: '',
          // Collapse if there are a lot of fields so the page stays scannable.
          expandable: result.fields.length > 8,
          expandThreshold: 8,
          totalCount: result.fields.length,
          collapsedContent: _buildFieldList(
            result.fields.take(8).toList(),
            result.totalDocs,
            footer: 'Sampled ${result.totalDocs} recent product(s)',
          ),
          expandedContent: _buildFieldList(
            result.fields,
            result.totalDocs,
            footer: 'Sampled ${result.totalDocs} recent product(s)',
          ),
          content: _buildFieldList(
            result.fields.length > 8
                ? result.fields.take(8).toList()
                : result.fields,
            result.totalDocs,
            footer: 'Sampled ${result.totalDocs} recent product(s)',
          ),
        );
      },
    );
  }

  Widget _buildFieldList(
    List<_DiscoveredField> fields,
    int totalDocs, {
    required String footer,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final f in fields) _buildFieldRow(f),
        const SizedBox(height: 8),
        Text(
          footer,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade500,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildFieldRow(_DiscoveredField f) {
    final pct = (f.count / f.total * 100).round();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.label_outline, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  f.key,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                if (f.sample.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      f.sample,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Coverage pill — green when broadly populated, amber otherwise.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: pct >= 75
                  ? Colors.green.withValues(alpha: 0.12)
                  : pct >= 25
                      ? Colors.orange.withValues(alpha: 0.12)
                      : Colors.grey.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$pct%  ·  ${f.count}/${f.total}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: pct >= 75
                    ? Colors.green.shade800
                    : pct >= 25
                        ? Colors.orange.shade800
                        : Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoveredField {
  final String key;
  final int count;
  final int total;
  final String sample;

  const _DiscoveredField({
    required this.key,
    required this.count,
    required this.total,
    required this.sample,
  });
}

class _DiscoveredFieldsResult {
  final int totalDocs;
  final List<_DiscoveredField> fields;

  const _DiscoveredFieldsResult({
    required this.totalDocs,
    required this.fields,
  });
}
