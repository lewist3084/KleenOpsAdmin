// lib/content/hr/hrEmployeeEdit.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/services/firestore_service.dart';
import 'package:kleenops_admin/app/shared_widgets/forms/cancel_save_adapter.dart';
import 'package:kleenops_admin/services/storage_service.dart';
import 'package:path/path.dart' as p;

class HrEmployeeEdit extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> employeeRef;
  final String currentName;
  final String currentRoleName;
  final String currentImageUrl;

  const HrEmployeeEdit({
    super.key,
    required this.employeeRef,
    required this.currentName,
    required this.currentRoleName,
    required this.currentImageUrl,
  });

  @override
  _HrEmployeeEditState createState() => _HrEmployeeEditState();
}

class _HrEmployeeEditState extends State<HrEmployeeEdit> {
  late final TextEditingController _nameController;
  late final TextEditingController _roleController;
  late final TextEditingController _imageUrlController;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _roleController = TextEditingController(text: widget.currentRoleName);
    _imageUrlController = TextEditingController(text: widget.currentImageUrl);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _updateEmployee() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final imageUrl = _imageUrlController.text.trim();
    final data = <String, dynamic>{
      'name': _nameController.text.trim(),
      'roleName': _roleController.text.trim(),
    };

    try {
      await FirestoreService().saveDocument(
        collectionRef: widget.employeeRef.parent,
        docId: widget.employeeRef.id,
        data: data,
      );
      await _syncProfileImageFile(imageUrl);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Employee details updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _syncProfileImageFile(String imageUrl) async {
    final companyRef = widget.employeeRef.parent.parent;
    if (companyRef == null) return;
    final fileCollection = FirebaseFirestore.instance.collection('file');
    final existingSnap = await fileCollection
        .where('memberId', isEqualTo: widget.employeeRef.id)
        .where('memberMediaRole', isEqualTo: 'profile')
        .get();

    if (imageUrl.isEmpty) {
      if (existingSnap.docs.isEmpty) return;
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in existingSnap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      return;
    }

    final existingDoc =
        existingSnap.docs.isNotEmpty ? existingSnap.docs.first : null;
    final docRef = existingDoc?.reference ?? fileCollection.doc();
    final storagePath = _storagePathFromUrl(imageUrl);
    final extension = _extensionFromUrl(imageUrl);

    final payload = <String, dynamic>{
      'firestorePath': docRef.path,
      'downloadUrl': imageUrl,
      'name': '${_nameController.text.trim()} Profile Image',
      'mediaType': 'Image',
      'fileType': 'image',
      'memberId': widget.employeeRef.id,
      'memberMediaRole': 'profile',
      'order': 0,
      'isMaster': true,
      'updatedAt': FieldValue.serverTimestamp(),
      if (existingDoc == null) 'createdAt': FieldValue.serverTimestamp(),
    };
    if (storagePath != null && storagePath.isNotEmpty) {
      payload['storagePath'] = storagePath;
    }
    if (extension.isNotEmpty) {
      payload['fileExtension'] = extension;
    }

    await docRef.set(payload, SetOptions(merge: true));
  }

  String? _storagePathFromUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('gs://')) {
      final withoutScheme = trimmed.substring(5);
      final parts = withoutScheme.split('/');
      if (parts.length >= 2) {
        return parts.sublist(1).join('/');
      }
      return null;
    }
    if (trimmed.startsWith('http')) {
      final path = StorageService().extractPathFromUrl(trimmed).trim();
      return path.isNotEmpty ? path : null;
    }
    return trimmed.contains('/') ? trimmed : null;
  }

  String _extensionFromUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return '';
    final storagePath = _storagePathFromUrl(trimmed);
    final path = storagePath ?? (Uri.tryParse(trimmed)?.path ?? trimmed);
    final ext = p.extension(path).toLowerCase();
    if (ext.isEmpty) return '';
    return ext.startsWith('.') ? ext.substring(1) : ext;
  }

  Widget _buildImagePreview() {
    final url = _imageUrlController.text.trim();
    if (url.isEmpty) {
      return Image.asset(
        'assets/logo.png',
        width: 120,
        height: 120,
        fit: BoxFit.cover,
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      width: 120,
      height: 120,
      fit: BoxFit.cover,
      placeholder: (_, __) => const CircularProgressIndicator(),
      errorWidget: (_, __, ___) => const Icon(Icons.error, size: 60),
    );
  }

  @override
  Widget build(BuildContext context) {
    final form = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey[300],
                      child: ClipOval(child: _buildImagePreview()),
                    ),
                  ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _imageUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Image URL',
                        icon: Icon(Icons.image),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        icon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _roleController,
                      decoration: const InputDecoration(
                        labelText: 'Role',
                        icon: Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                ],
              ),
            ),
          );

    return Scaffold(
      appBar: const StandardAppBar(title: 'Edit Employee'),
      body: form,
      bottomNavigationBar: CancelSaveBar(
        onCancel: () => Navigator.of(context).pop(),
        onSave: _isLoading ? null : _updateEmployee,
      ),
    );
  }
}
