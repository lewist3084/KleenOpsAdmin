import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_widgets/containers/container_header.dart';

class SalesProductDetailsScreen extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final String docId;

  const SalesProductDetailsScreen({
    super.key,
    required this.companyRef,
    required this.docId,
  });

  @override
  Widget build(BuildContext context) {
    final docRef = FirebaseFirestore.instance.collection('product').doc(docId);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: docRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!.data()!;
        final name = data['name'] as String? ?? '';
        final desc = data['description'] as String? ?? '';
        return SingleChildScrollView(
          child: ContainerHeader(
            showImage: false,
            titleHeader: 'Product',
            title: name,
            descriptionHeader: 'Description',
            description: desc,
          ),
        );
      },
    );
  }
}

