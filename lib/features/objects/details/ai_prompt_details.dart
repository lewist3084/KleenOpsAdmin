import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:shared_widgets/containers/container_header.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:shared_widgets/fields/markup_image_field.dart'
    show MarkupImageField, buildImageWidget;
import 'package:kleenops_admin/features/objects/forms/ai_prompt_form.dart';
import 'package:kleenops_admin/services/ai/ai_context_service.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';

/// Displays a single AI prompt document.
class AiPromptDetailsScreen extends StatefulWidget {
  final String docId;

  const AiPromptDetailsScreen({super.key, required this.docId});

  @override
  State<AiPromptDetailsScreen> createState() => _AiPromptDetailsScreenState();
}

class _AiPromptDetailsScreenState extends State<AiPromptDetailsScreen> {
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _docStream;

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
    final docId = widget.docId;
    final docRef = FirebaseFirestore.instance.collection('aiPrompt').doc(docId);

    Widget buildBottomBar({VoidCallback? onAiPressed}) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: 'AI Prompt',
            onAiPressed: onAiPressed,
          ),
          const HomeNavBarAdapter(highlightSelected: false),
        ],
      );
    }

    Future<void> addFile() async {
      String? newUrl;
      await showDialog(
        context: context,
        builder: (ctx) => DialogAction(
          title: 'Add File',
          content: MarkupImageField(
            onImageChanged: (url) => newUrl = url,
            onMarkupTap: () {},
            storageFolder: 'aiPrompt/$docId/files',
          ),
          cancelText: 'Cancel',
          actionText: 'Save',
          onCancel: () => Navigator.of(ctx).pop(),
          onAction: () => Navigator.of(ctx).pop(),
        ),
      );
      if (newUrl != null) {
        await docRef.update({
          'files': FieldValue.arrayUnion([newUrl]),
        });
      }
    }

    return Scaffold(
      appBar: null,
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final controller = ref.read(aiCanvasControllerProvider);
          return buildBottomBar(onAiPressed: controller.toggle);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AiPromptForm(docId: docId),
            ),
          );
        },
        child: const Icon(Icons.edit),
      ),
      body: _wrapCanvas(
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _docStream ??= docRef.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: Text('Document not found'));
            }

            final data = snapshot.data!.data()!;
            final name = data['name'] as String? ?? '';
            final description = data['description'] as String? ?? '';
            final prompt = data['prompt'] as String? ?? '';
            final files = List<String>.from(
              data['files'] as List<dynamic>? ?? const [],
            );

            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ContainerHeader(
                    image: null,
                    showImage: false,
                    titleHeader: 'Name',
                    title: name,
                    descriptionHeader: 'Description',
                    description: description,
                  ),
                  ContainerActionWidget(
                    title: 'Files',
                    content: files.isEmpty
                        ? const Text('No files uploaded')
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: files
                                .map(
                                  (url) => Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 8.0),
                                    child: SizedBox(
                                      height: 100,
                                      width: double.infinity,
                                      child: buildImageWidget(url),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                    actionText: 'Add',
                    onAction: addFile,
                  ),
                  ContainerActionWidget(
                    title: 'Prompt',
                    content: Text(prompt),
                    actionText: '',
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
