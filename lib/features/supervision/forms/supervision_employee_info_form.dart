// lib/features/supervision/forms/supervision_employee_info_form.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/forms/cancel_save_adapter.dart';
import 'package:kleenops_admin/widgets/layout/bookended_canvas.dart';
import 'package:shared_widgets/fields/markup_image_field.dart';
import 'package:shared_widgets/utils/image_payload.dart';
import 'package:kleenops_admin/features/hr/utils/member_file_images.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';

class SupervisionEmployeeInfoFormContent extends ConsumerStatefulWidget {
  final DocumentReference<Map<String, dynamic>> employeeRef;

  const SupervisionEmployeeInfoFormContent({
    super.key,
    required this.employeeRef,
  });

  @override
  ConsumerState<SupervisionEmployeeInfoFormContent> createState() =>
      _SupervisionEmployeeInfoFormContentState();
}

class _SupervisionEmployeeInfoFormContentState
    extends ConsumerState<SupervisionEmployeeInfoFormContent> {
  late TextEditingController _nameController;
  String? _imageUrl;
  List<Map<String, dynamic>> _images = const [];
  bool _loading = true;
  DocumentReference<Map<String, dynamic>>? _companyRef;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _roles = [];
  DocumentReference<Map<String, dynamic>>? _roleRef;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _loadData();
  }

  DocumentReference<Map<String, dynamic>>? _resolveCompanyRef(
    Map<String, dynamic> data,
  ) {
    final rawCompany = data['companyId'];
    if (rawCompany is DocumentReference<Map<String, dynamic>>) {
      return rawCompany;
    }
    if (rawCompany is DocumentReference) {
      return rawCompany.withConverter<Map<String, dynamic>>(
        fromFirestore: (s, _) => s.data() ?? <String, dynamic>{},
        toFirestore: (m, _) => m,
      );
    }
    if (rawCompany is String && rawCompany.isNotEmpty) {
      return FirebaseFirestore.instance
          .collection('company')
          .doc(rawCompany)
          .withConverter<Map<String, dynamic>>(
            fromFirestore: (s, _) => s.data() ?? <String, dynamic>{},
            toFirestore: (m, _) => m,
          );
    }

    // Fallback for legacy nested member docs.
    final parentCompany = widget.employeeRef.parent.parent;
    if (parentCompany != null) {
      return parentCompany.withConverter<Map<String, dynamic>>(
        fromFirestore: (s, _) => s.data() ?? <String, dynamic>{},
        toFirestore: (m, _) => m,
      );
    }
    return null;
  }

  DocumentReference<Map<String, dynamic>>? _resolveRoleRef(dynamic rawRole) {
    if (rawRole is DocumentReference<Map<String, dynamic>>) {
      return rawRole;
    }
    if (rawRole is DocumentReference) {
      return rawRole.withConverter<Map<String, dynamic>>(
        fromFirestore: (s, _) => s.data() ?? <String, dynamic>{},
        toFirestore: (m, _) => m,
      );
    }
    if (rawRole is String && rawRole.isNotEmpty) {
      final roleId = rawRole.split('/').last;
      return FirebaseFirestore.instance
          .collection('role')
          .doc(roleId)
          .withConverter<Map<String, dynamic>>(
            fromFirestore: (s, _) => s.data() ?? <String, dynamic>{},
            toFirestore: (m, _) => m,
          );
    }
    return null;
  }

  Future<void> _loadData() async {
    try {
      final snap = await widget.employeeRef.get();
      final data = snap.data();
      if (data != null) {
        _nameController.text = data['name'] as String? ?? '';
        final companyRef = _resolveCompanyRef(data);
        _companyRef = companyRef;
        if (companyRef != null) {
          final profileUrl = await MemberFileImages.primaryProfileImageUrl(
            companyRef: companyRef,
            memberId: widget.employeeRef.id,
          );
          if (profileUrl.trim().isNotEmpty) {
            _imageUrl = profileUrl.trim();
            _images = canonicalImageGallery(
              buildSingleImageGallery(_imageUrl),
            );
          }
          if (_images.isNotEmpty) {
            _imageUrl = (_images.first['url'] as String?) ?? _imageUrl;
          }
        }
        _roleRef = _resolveRoleRef(data['roleId']);
        // Admin: roles are top-level.
        final rolesSnap =
            await FirebaseFirestore.instance.collection('role').get();
        _roles = rolesSnap.docs;
      }
      if (_images.isNotEmpty) {
        _imageUrl = (_images.first['url'] as String?) ?? _imageUrl;
      }
    } catch (e) {
      SnackbarService.instance.showSnackBar(SnackBar(
          duration: const Duration(seconds: 5),
          content: Text('Error loading data: $e')));
    }
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveForm() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      SnackbarService.instance.showSnackBar(
        const SnackBar(
            duration: Duration(seconds: 5),
            content: Text('Please enter a name')),
      );
      return;
    }
    if (_roleRef == null) {
      SnackbarService.instance.showSnackBar(
        const SnackBar(
            duration: Duration(seconds: 5),
            content: Text('Please select a role')),
      );
      return;
    }

    try {
      final updates = <String, dynamic>{
        'name': name,
        'roleId': _roleRef,
      };
      updates['images'] = FieldValue.delete();
      updates['imageUrl'] = FieldValue.delete();
      QueryDocumentSnapshot<Map<String, dynamic>>? selectedRole;
      for (final role in _roles) {
        if (role.reference == _roleRef) {
          selectedRole = role;
          break;
        }
      }
      if (selectedRole != null) {
        updates['roleName'] =
            (selectedRole.data()['name'] as String?) ?? '';
      }

      await widget.employeeRef.update(updates);
      final companyRef = _companyRef ?? widget.employeeRef.parent.parent;
      if (companyRef != null) {
        final url = (_images.isNotEmpty
                ? (_images.first['url'] as String?)?.trim()
                : _imageUrl?.trim()) ??
            '';
        await MemberFileImages.syncProfileImage(
          companyRef: companyRef,
          memberId: widget.employeeRef.id,
          imageUrl: url,
          memberName: name,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      SnackbarService.instance.showSnackBar(SnackBar(
          duration: const Duration(seconds: 5),
          content: Text('Error saving: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: BookendedCanvas(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MarkupImageField(
                imageUrl: _imageUrl,
                images: _images,
                storageFolder: 'employee/profile/images',
                onImagesChanged: (maps) => setState(() {
                  _images = canonicalImageGallery(maps);
                  _imageUrl = _images.isNotEmpty
                      ? (_images.first['url'] as String?)
                      : '';
                }),
                onImageChanged: (url) => setState(() => _imageUrl = url),
                onMarkupTap: () {
                  // Navigate to your markup editor if available
                },
              ),
              const SizedBox(height: 16.0),
              TextField(
                controller: _nameController,
                textInputAction: TextInputAction.done,
                onTapOutside: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16.0),
              DropdownButtonFormField<
                  DocumentReference<Map<String, dynamic>>>(
                initialValue: _roleRef,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                ),
                items: _roles.map((doc) {
                  final roleData = doc.data();
                  final roleName = roleData['name'] as String? ?? 'Unnamed';
                  return DropdownMenuItem(
                    value: doc.reference,
                    child: Text(roleName),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _roleRef = value);
                },
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CancelSaveBar(
            onCancel: () => Navigator.of(context).pop(),
            onSave: _saveForm,
            reserveNavBarSpace: false,
          ),
          const DetailsAppBar(title: 'Edit Employee Info'),
          const HomeNavBarAdapter(),
        ],
      ),
    );
  }
}
