import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:shared_widgets/services/firestore_service.dart';
import 'package:kleenops_admin/app/shared_widgets/forms/cancel_save_adapter.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:kleenops_admin/services/ai_text_adapter.dart';

class SalesCustomerForm extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;

  const SalesCustomerForm({
    super.key,
    required this.companyRef,
  });

  @override
  State<SalesCustomerForm> createState() => _SalesCustomerFormState();
}

class _SalesCustomerFormState extends State<SalesCustomerForm> {
  final _nameController = TextEditingController();
  final _abbrevController = TextEditingController();
  final FirestoreService _firestore = FirestoreService();

  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _abbrevController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    final abbrev = _abbrevController.text.trim();

    if (name.isEmpty || abbrev.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide name and abbreviation.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _firestore.saveDocument(
        collectionRef: FirebaseFirestore.instance.collection('customer'),
        data: {
          'name': name,
          'nameAbbreviation': abbrev,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save customer: $e')),
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const StandardAppBar(title: 'New Customer'),
      body: AbsorbPointer(
        absorbing: _saving,
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ContainerActionWidget(
                    title: 'Customer Details',
                    actionText: '',
                    content: Column(
                      children: [
                        AITextField(
                          controller: _nameController,
                          labelText: 'Name',
                          minLines: 1,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 16),
                        AITextField(
                          controller: _abbrevController,
                          labelText: 'Name Abbreviation',
                          minLines: 1,
                          maxLines: 1,
                          onChanged: (value) {
                            final upper = value.toUpperCase();
                            if (upper != value) {
                              final selection = _abbrevController.selection;
                              final nextSelection = selection.isValid
                                  ? (selection.isCollapsed
                                      ? TextSelection.collapsed(
                                          offset: upper.length,
                                        )
                                      : selection)
                                  : TextSelection.collapsed(
                                      offset: upper.length,
                                    );
                              _abbrevController.value =
                                  _abbrevController.value.copyWith(
                                text: upper,
                                selection: nextSelection,
                                composing: TextRange.empty,
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_saving)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x88000000),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: CancelSaveBar(
        onCancel: () => Navigator.of(context).pop(),
        onSave: _saving ? null : _handleSave,
      ),
    );
  }
}
