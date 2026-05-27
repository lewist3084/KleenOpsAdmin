import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/widgets/layout/bookended_canvas.dart';
import 'package:kleenops_admin/app/shared_widgets/forms/cancel_save_adapter.dart';
import 'package:shared_widgets/services/firestore_service.dart';

class AiPromptForm extends StatefulWidget {
  final String docId;
  const AiPromptForm({super.key, required this.docId});

  @override
  State<AiPromptForm> createState() => _AiPromptFormState();
}

class _AiPromptFormState extends State<AiPromptForm> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _description = '';
  String _prompt = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final doc = await FirebaseFirestore.instance
        .collection('aiPrompt')
        .doc(widget.docId)
        .get();
    if (doc.exists) {
      final data = doc.data()!;
      _name = data['name'] as String? ?? '';
      _description = data['description'] as String? ?? '';
      _prompt = data['prompt'] as String? ?? '';
    }
    setState(() => _loading = false);
  }

  Future<void> _saveForm() async {
    _formKey.currentState?.save();
    final data = {
      'name': _name,
      'description': _description,
      'prompt': _prompt,
    };
    await FirestoreService().saveDocument(
      collectionRef: FirebaseFirestore.instance.collection('aiPrompt'),
      docId: widget.docId,
      data: data,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final Widget formBody = Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                initialValue: _name,
                decoration: const InputDecoration(labelText: 'Name'),
                onSaved: (v) => _name = v ?? '',
                textInputAction: TextInputAction.next,
                onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _description,
                decoration: const InputDecoration(labelText: 'Description'),
                onSaved: (v) => _description = v ?? '',
                textInputAction: TextInputAction.next,
                onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _prompt,
                decoration: const InputDecoration(labelText: 'Prompt'),
                maxLines: null,
                onSaved: (v) => _prompt = v ?? '',
                textInputAction: TextInputAction.newline,
                onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
              ),
            ],
          ),
        ),
      );

    return Scaffold(
      body: BookendedCanvas(child: formBody),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CancelSaveBar(
            onCancel: () => Navigator.of(context).pop(),
            onSave: _saveForm,
            reserveNavBarSpace: false,
          ),
          const DetailsAppBar(title: 'Edit AI Prompt'),
          const HomeNavBarAdapter(),
        ],
      ),
    );
  }
}
