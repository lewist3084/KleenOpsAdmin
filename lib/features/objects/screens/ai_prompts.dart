import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:shared_widgets/lists/standardViewGroup.dart';
import 'package:shared_widgets/tiles/standard_tile_small.dart';
import 'package:kleenops_admin/features/objects/details/ai_prompt_details.dart';

/// Displays AI prompts from the top-level `aiPrompt` collection.
class AiPromptsScreen extends StatelessWidget {
  const AiPromptsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('aiPrompt')
        .orderBy('name');

    return Scaffold(
      appBar: const StandardAppBar(title: 'AI Prompts'),
      bottomNavigationBar: const HomeNavBarAdapter(),
      body: StandardViewGroup.paginated(
        query: query,
        itemBuilder: (ctx, doc, _) {
          final data = doc.data();
          return StandardTileSmallDart.iconText(
            leadingicon: Icons.smart_toy_outlined,
            text: data['name'] ?? '',
          );
        },
        onTap: (doc) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AiPromptDetailsScreen(docId: doc.id),
            ),
          );
        },
        emptyBuilder: (_) => const Center(child: Text('No AI prompts')),
      ),
    );
  }
}
