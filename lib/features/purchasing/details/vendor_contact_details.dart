// lib/features/purchasing/details/vendor_contact_details.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:shared_widgets/containers/container_header.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';

const _detailNavBar = SafeArea(
  top: false,
  child: HomeNavBarAdapter(highlightSelected: false),
);

class VendorContactDetails extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyId;
  final String contactId;

  const VendorContactDetails({
    super.key,
    required this.companyId,
    required this.contactId,
  });

  @override
  State<VendorContactDetails> createState() => _VendorContactDetailsState();
}

class _VendorContactDetailsState extends State<VendorContactDetails> {
  Future<void> _addPhoneNumber(
      DocumentReference<Map<String, dynamic>> contactRef,
      {Map<String, dynamic>? existing}) async {
    final phoneCtrl = TextEditingController(text: existing?['number'] ?? '');
    String type = existing?['type'] ?? 'Home';
    bool primary = existing?['primary'] ?? false;

    await showDialog(
      context: context,
      builder: (ctx) => DialogAction(
        title: existing != null ? 'Edit Phone Number' : 'Add Phone Number',
        cancelText: 'Cancel',
        actionText: 'Save',
        onCancel: () => Navigator.of(ctx).pop(),
        onAction: () async {
          final num = phoneCtrl.text.trim();
          if (num.isEmpty) return;
          final map = {'number': num, 'type': type, 'primary': primary};
          if (existing != null) {
            await contactRef
                .update({'phoneNumber': FieldValue.arrayRemove([existing])});
          }
          await contactRef.update({
            'phoneNumber': FieldValue.arrayUnion([map]),
          });
          Navigator.of(ctx).pop();
        },
        content: StatefulBuilder(
          builder: (ctx, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration:
                      const InputDecoration(labelText: 'Phone Number'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(value: 'Home', child: Text('Home')),
                    DropdownMenuItem(
                        value: 'Work Phone', child: Text('Work Phone')),
                    DropdownMenuItem(
                        value: 'Work Cell Phone',
                        child: Text('Work Cell Phone')),
                    DropdownMenuItem(
                        value: 'Personal Cell Phone',
                        child: Text('Personal Cell Phone')),
                  ],
                  onChanged: (val) => setState(() => type = val ?? 'Home'),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Primary'),
                  value: primary,
                  onChanged: (val) => setState(() {
                    primary = val ?? false;
                  }),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _addEmail(
      DocumentReference<Map<String, dynamic>> contactRef) async {
    final emailCtrl = TextEditingController();
    bool primary = false;

    await showDialog(
      context: context,
      builder: (ctx) => DialogAction(
        title: 'Add Email',
        cancelText: 'Cancel',
        actionText: 'Save',
        onCancel: () => Navigator.of(ctx).pop(),
        onAction: () async {
          final email = emailCtrl.text.trim();
          if (email.isEmpty) return;
          final map = {'email': email, 'primary': primary};
          await contactRef.update({
            'email': FieldValue.arrayUnion([map]),
          });
          Navigator.of(ctx).pop();
        },
        content: StatefulBuilder(
          builder: (ctx, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Primary'),
                  value: primary,
                  onChanged: (val) => setState(() {
                    primary = val ?? false;
                  }),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _addSocialMedia(
      DocumentReference<Map<String, dynamic>> contactRef) async {
    final urlCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => DialogAction(
        title: 'Add Social Media',
        cancelText: 'Cancel',
        actionText: 'Save',
        onCancel: () => Navigator.of(ctx).pop(),
        onAction: () async {
          final url = urlCtrl.text.trim();
          if (url.isEmpty) return;
          await contactRef.update({
            'socialMedia': FieldValue.arrayUnion([url]),
          });
          Navigator.of(ctx).pop();
        },
        content: TextField(
          controller: urlCtrl,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(labelText: 'URL'),
        ),
      ),
    );
  }

  Future<void> _addNote(
      DocumentReference<Map<String, dynamic>> contactRef) async {
    final noteCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => DialogAction(
        title: 'Add Note',
        cancelText: 'Cancel',
        actionText: 'Save',
        onCancel: () => Navigator.of(ctx).pop(),
        onAction: () async {
          final note = noteCtrl.text.trim();
          if (note.isEmpty) return;
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) return;
          await contactRef.update({
            'notes': FieldValue.arrayUnion([
              {'note': note, 'createdBy': user.uid}
            ]),
          });
          Navigator.of(ctx).pop();
        },
        content: TextField(
          controller: noteCtrl,
          decoration: const InputDecoration(labelText: 'Note'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contactRef =
        widget.companyId.collection('contact').doc(widget.contactId);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: contactRef.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            bottomNavigationBar: _detailNavBar,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final data = snap.data!.data() ?? {};
        final name = data['name'] ?? '';
        final List<Map<String, dynamic>> phoneList =
            (data['phoneNumber'] as List<dynamic>? ?? [])
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
        final List<Map<String, dynamic>> emailList =
            (data['email'] as List<dynamic>? ?? [])
                .map((e) {
          if (e is String) {
            return {'email': e, 'primary': false};
          }
          return Map<String, dynamic>.from(e as Map);
        }).toList();
        final List<String> socialMediaList =
            List<String>.from(data['socialMedia'] ?? <String>[]);
        final List<Map<String, dynamic>> notesList =
            (data['notes'] as List<dynamic>? ?? [])
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();

        return Scaffold(
          appBar: const StandardAppBar(title: 'Contact'),
          bottomNavigationBar: _detailNavBar,
          body: SingleChildScrollView(
            child: Column(
              children: [
                ContainerHeader(
                  showImage: false,
                  titleHeader: 'Contact',
                  title: name.toString(),
                  descriptionHeader: '',
                  description: '',
                ),
                ContainerActionWidget(
                  title: 'Phone Number',
                  actionText: 'Add',
                  onAction: () => _addPhoneNumber(contactRef),
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: phoneList.map((m) {
                      final number = m['number'] ?? '';
                      final type = m['type'] ?? '';
                      final primary = m['primary'] == true;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: InkWell(
                          onTap: () =>
                              _addPhoneNumber(contactRef, existing: m),
                          child: Text(
                              '$type: $number${primary ? ' (Primary)' : ''}'),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                ContainerActionWidget(
                  title: 'Email',
                  actionText: 'Add',
                  onAction: () => _addEmail(contactRef),
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: emailList
                        .map((e) => Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 4.0),
                              child: Text(
                                  '${e['email']}${e['primary'] == true ? ' (Primary)' : ''}'),
                            ))
                        .toList(),
                  ),
                ),
                ContainerActionWidget(
                  title: 'Social Media',
                  actionText: 'Add',
                  onAction: () => _addSocialMedia(contactRef),
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: socialMediaList
                        .map((e) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 4.0),
                              child: Text(e),
                            ))
                        .toList(),
                  ),
                ),
                ContainerActionWidget(
                  title: 'Notes',
                  actionText: 'Add',
                  onAction: () => _addNote(contactRef),
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: notesList
                        .map((m) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 4.0),
                              child: Text(m['note'] ?? ''),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}


