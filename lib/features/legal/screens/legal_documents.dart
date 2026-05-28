// lib/features/legal/screens/legal_documents.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/user_drawer.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/theme/app_palette.dart';
import 'package:url_launcher/url_launcher.dart';

class LegalDocumentsScreen extends StatelessWidget {
  const LegalDocumentsScreen({super.key});

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
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: null,
      drawer: const UserDrawer(),
      body: _wrapCanvas(const _LegalDocumentsList()),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          DetailsAppBar(title: 'Documents'),
          HomeNavBarAdapter(),
        ],
      ),
    );
  }
}

class _LegalDocumentsList extends StatelessWidget {
  const _LegalDocumentsList();

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('file')
        .where('category', isEqualTo: 'legal')
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Error loading documents: ${snap.error}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          );
        }
        final docs = snap.data?.docs.toList() ?? [];
        if (docs.isEmpty) {
          return const _EmptyState();
        }

        // Group by subcategory; English first, then translations alphabetical.
        const subcategoryOrder = [
          'privacy-policy',
          'terms-of-service',
          'information-security-policy',
          'data-retention-policy',
        ];
        final groups = <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
        for (final d in docs) {
          final sub = (d.data()['subcategory'] as String?) ?? d.id;
          groups.putIfAbsent(sub, () => []).add(d);
        }
        final orderedSubcats = [
          ...subcategoryOrder.where(groups.containsKey),
          ...groups.keys.where((k) => !subcategoryOrder.contains(k)).toList()
            ..sort(),
        ];
        for (final list in groups.values) {
          list.sort((a, b) {
            final aLang = (a.data()['language'] as String?) ?? 'en';
            final bLang = (b.data()['language'] as String?) ?? 'en';
            if (aLang == 'en' && bLang != 'en') return -1;
            if (bLang == 'en' && aLang != 'en') return 1;
            return aLang.compareTo(bLang);
          });
        }

        final bottomInset = kBottomNavigationBarHeight +
            16.0 +
            MediaQuery.of(context).padding.bottom;
        return ListView(
          padding: EdgeInsets.fromLTRB(16, 24, 16, bottomInset),
          children: [
            for (final sub in orderedSubcats) ...[
              _LegalGroup(subcategory: sub, docs: groups[sub]!),
              const SizedBox(height: 24),
            ],
          ],
        );
      },
    );
  }
}

class _LegalGroup extends StatelessWidget {
  const _LegalGroup({required this.subcategory, required this.docs});

  final String subcategory;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

  static const _titles = {
    'privacy-policy': 'Privacy Policy',
    'terms-of-service': 'Terms of Service',
    'information-security-policy': 'Information Security Policy',
    'data-retention-policy': 'Data Retention & Deletion Policy',
  };

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteScope.of(context);
    final title = _titles[subcategory] ?? subcategory;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: palette.primary1,
            ),
          ),
        ),
        for (var i = 0; i < docs.length; i++) ...[
          _LegalDocTile(doc: docs[i]),
          if (i < docs.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _LegalDocTile extends StatelessWidget {
  const _LegalDocTile({required this.doc});

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteScope.of(context);
    final data = doc.data();
    final language = (data['language'] as String?) ?? 'en';
    final version = (data['version'] as num?)?.toInt();
    final effective = (data['effectiveDate'] as String?) ?? '';
    final publicUrl = (data['publicUrl'] as String?) ?? '';
    final downloadUrl = (data['downloadUrl'] as String?) ?? '';
    final name = language == 'en'
        ? 'English'
        : '${_languageName(language)} ($language)';
    final description = language == 'en'
        ? 'Source / controlling version'
        : 'Translation';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: publicUrl.isEmpty ? null : () => _open(context, publicUrl),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: palette.primary2.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.gavel_outlined, color: palette.primary2),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (version != null) _chip('v$version', palette.primary1),
                        if (effective.isNotEmpty)
                          _chip('Effective $effective', Colors.grey[600]!),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Download PDF',
                icon: const Icon(Icons.picture_as_pdf_outlined),
                color: palette.primary1,
                onPressed:
                    downloadUrl.isEmpty ? null : () => _open(context, downloadUrl),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _languageNames = {
    'en': 'English',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'it': 'Italian',
    'pt': 'Portuguese',
    'hi': 'Hindi',
    'vi': 'Vietnamese',
    'ar': 'Arabic',
    'ja': 'Japanese',
    'ko': 'Korean',
    'zh': 'Chinese (Simplified)',
    'zh_HK': 'Chinese (Traditional, HK)',
    'ru': 'Russian',
    'tl': 'Tagalog',
    'ht': 'Haitian Creole',
    'km': 'Khmer',
    'sm': 'Samoan',
    'to': 'Tongan',
  };

  static String _languageName(String code) => _languageNames[code] ?? code;

  static Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $url')),
      );
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.gavel_outlined, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'No legal documents yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Run functions/scripts/legal-pdfs/build-and-seed.js\nto publish the first revision.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
