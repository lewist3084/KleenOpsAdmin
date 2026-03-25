// lib/features/legal/screens/legal_home.dart
//
// Admin legal document management — stores docs in top-level `file`
// collection with sectionKey: 'legal' for the platform operator's own files.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_widgets/dialogs/legal_document_form.dart';
import 'package:shared_widgets/lists/standardView.dart';
import 'package:shared_widgets/search/search_field_action.dart';
import 'package:shared_widgets/tiles/standard_tile_small.dart';
import 'package:shared_widgets/viewers/pdf_viewer.dart';

import '../../../app/routes.dart';
import '../../../theme/palette.dart';

class LegalHome extends StatefulWidget {
  const LegalHome({super.key});

  @override
  State<LegalHome> createState() => _LegalHomeState();
}

class _LegalHomeState extends State<LegalHome>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _searchCtl = TextEditingController();
  String _search = '';

  static const _tabs = ['All', 'Documents', 'Contracts', 'Compliance'];
  static const _categoryKeys = [null, 'documents', 'contracts', 'compliance'];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtl.dispose();
    super.dispose();
  }

  CollectionReference<Map<String, dynamic>> get _collection =>
      FirebaseFirestore.instance.collection('file');

  Stream<QuerySnapshot<Map<String, dynamic>>> _queryFor(String? category) {
    Query<Map<String, dynamic>> q = _collection;
    if (category != null) {
      q = q.where('category', isEqualTo: category);
    }
    return q.orderBy('name').snapshots();
  }

  void _openForm({Map<String, dynamic>? initialData, String? docId}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LegalDocumentForm(
        storageFolderPath: 'admin/legal',
        initialData: initialData,
        onSave: (data) async {
          data['updatedAt'] = FieldValue.serverTimestamp();
          if (docId == null) {
            data['createdAt'] = FieldValue.serverTimestamp();
            await _collection.add(data);
          } else {
            await _collection.doc(docId).update(data);
          }
        },
      ),
    ));
  }

  void _openPdf(String url) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PdfViewer(pdfUrl: url),
    ));
  }

  @override
  Widget build(BuildContext context) {
    const palette = adminPalette;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Legal'),
        backgroundColor: palette.primary1,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutePaths.dashboard),
        ),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: palette.primary2,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: Column(
        children: [
          SearchFieldAction(
            controller: _searchCtl,
            labelText: 'Search legal documents',
            onChanged: (t) => setState(() => _search = t.toLowerCase().trim()),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: _categoryKeys
                  .map((cat) => _buildList(cat))
                  .toList(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: palette.primary2,
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildList(String? category) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _queryFor(category),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];
        final filtered = docs.where((doc) {
          final name = (doc.data()['name'] ?? '').toString().toLowerCase();
          return name.contains(_search);
        }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Text(
              _search.isEmpty
                  ? 'No documents yet. Tap + to add one.'
                  : 'No documents match "$_search".',
              style: const TextStyle(color: Colors.grey),
            ),
          );
        }

        return StandardView<QueryDocumentSnapshot<Map<String, dynamic>>>(
          items: filtered,
          groupBy: (_) => '',
          disableGrouping: true,
          onTap: (doc) {
            final data = doc.data();
            final url = data['downloadUrl'] as String?;
            if (url != null && url.isNotEmpty) {
              _openPdf(url);
            }
          },
          itemBuilder: (doc) {
            final data = doc.data();
            final name = (data['name'] ?? 'Unnamed').toString();
            final desc = (data['description'] ?? '').toString();
            final cat = (data['category'] ?? '').toString();
            return StandardTileSmallDart.iconText(
              leadingicon: _iconForCategory(cat),
              text: name,
              secondText: desc.isNotEmpty ? desc : legalCategoryLabel(cat),
            );
          },
        );
      },
    );
  }

  IconData _iconForCategory(String cat) {
    switch (cat) {
      case 'contracts':
        return Icons.handshake_outlined;
      case 'compliance':
        return Icons.verified_outlined;
      default:
        return Icons.description_outlined;
    }
  }
}
