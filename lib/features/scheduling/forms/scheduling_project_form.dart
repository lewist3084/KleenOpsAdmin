// lib/features/scheduling/forms/scheduling_project_form.dart
//
// Simple create/edit form for a scheduling "project" (companyRef/project).
// A project is just a named bucket tasks can be assigned to, so the form is
// intentionally minimal: a name (required) and an optional description.
// Mirrors the kleenops form.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

import 'package:shared_widgets/services/firestore_service.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/forms/cancel_save_adapter.dart';
import 'package:kleenops_admin/widgets/layout/bookended_canvas.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';

class SchedulingProjectForm extends StatefulWidget {
  const SchedulingProjectForm({
    super.key,
    required this.companyId,
    this.docId,
  });

  final DocumentReference companyId;
  final String? docId; // null ⇒ new

  @override
  State<SchedulingProjectForm> createState() => _SchedulingProjectFormState();
}

class _SchedulingProjectFormState extends State<SchedulingProjectForm> {
  final _formKey = GlobalKey<FormState>();
  final _fs = FirestoreService();

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  bool _loading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.docId != null) _loadExisting();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    setState(() => _loading = true);
    final snap =
        await widget.companyId.collection('project').doc(widget.docId).get();
    if (!mounted) return;
    final d = snap.data() ?? <String, dynamic>{};
    _nameCtrl.text = (d['name'] as String?)?.trim() ?? '';
    _descCtrl.text = (d['description'] as String?)?.trim() ?? '';
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_saving) return;
    setState(() => _saving = true);

    final data = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
    };

    try {
      final coll = widget.companyId.collection('project');
      if (widget.docId == null) {
        final meta = await _fs.buildCreateMeta(coll);
        await coll.add({...data, ...meta});
      } else {
        await coll.doc(widget.docId).set(data, SetOptions(merge: true));
      }
      if (!mounted) return;
      SnackbarService.instance.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          content: Text(widget.docId == null
              ? 'Project created!'
              : 'Project updated!'),
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      SnackbarService.instance.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          content: Text('Save failed: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BookendedCanvas(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 80),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 3,
                    child: _loading
                        ? const LinearProgressIndicator(minHeight: 3)
                        : null,
                  ),
                  ContainerActionWidget(
                    actionText: '',
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Project name',
                          ),
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.words,
                          onTapOutside: (_) =>
                              FocusManager.instance.primaryFocus?.unfocus(),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Description (optional)',
                          ),
                          minLines: 3,
                          maxLines: 6,
                          onTapOutside: (_) =>
                              FocusManager.instance.primaryFocus?.unfocus(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CancelSaveBar(
            onCancel: () => context.pop(),
            onSave: _save,
            reserveNavBarSpace: false,
          ),
          DetailsAppBar(
            title: widget.docId == null ? 'New Project' : 'Edit Project',
          ),
          const HomeNavBarAdapter(section: 'projects'),
        ],
      ),
    );
  }
}
