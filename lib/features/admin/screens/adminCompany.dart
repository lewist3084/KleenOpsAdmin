import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:shared_widgets/containers/container_header.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:kleenops_admin/widgets/fields/google_address.dart';
import 'package:shared_widgets/fields/markup_image_field.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/constants/google_api_key.dart';
import 'package:kleenops_admin/features/admin/forms/adminCompanyForm.dart';
import 'package:kleenops_admin/features/admin/utils/company_file_images.dart';

/// Content widget for the Admin Company tab/screen.
class AdminCompanyContent extends ConsumerStatefulWidget {
  const AdminCompanyContent({super.key});

  @override
  ConsumerState<AdminCompanyContent> createState() =>
      _AdminCompanyContentState();
}

class _AdminCompanyContentState extends ConsumerState<AdminCompanyContent> {
  late final ScrollController _scrollController;
  final ValueNotifier<bool> _fabVisible = ValueNotifier<bool>(true);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fabVisible.dispose();
    super.dispose();
  }

  Widget _buildAnimatedFab(DocumentReference<Map<String, dynamic>> companyRef,
          String name, String imageUrl) =>
      ValueListenableBuilder<bool>(
        valueListenable: _fabVisible,
        builder: (_, visible, child) => AnimatedOpacity(
          duration: const Duration(milliseconds: 250),
          opacity: visible ? 1.0 : 0.0,
          child: child,
        ),
        child: FloatingActionButton(
          heroTag: 'editCompany',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const AdminCompanyFormScreen(),
            ),
          ),
          child: const Icon(Icons.edit),
        ),
      );

  Future<void> _editCompany(
    DocumentReference<Map<String, dynamic>> companyRef,
    String currentName,
    String currentImage,
  ) async {
    final nameCtl = TextEditingController(text: currentName);
    String imageUrl = currentImage;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDState) => DialogAction(
          title: 'Edit Company',
          cancelText: 'Cancel',
          actionText: 'Save',
          onCancel: () => Navigator.of(ctx2).pop(),
          onAction: () async {
            await companyRef.update({
              'name': nameCtl.text.trim(),
              'mainImage': FieldValue.delete(),
              'images': FieldValue.delete(),
            });
            await CompanyFileImages.syncHeaderImages(
              companyRef: companyRef,
              images: [
                if (imageUrl.trim().isNotEmpty)
                  {'url': imageUrl.trim(), 'order': 0, 'isMaster': true},
              ],
              name: nameCtl.text.trim(),
            );
            if (mounted) Navigator.of(ctx2).pop();
          },
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MarkupImageField(
                  imageUrl: imageUrl,
                  onImageChanged: (url) => setDState(() => imageUrl = url),
                  onMarkupTap: () => ScaffoldMessenger.of(ctx2).showSnackBar(
                    const SnackBar(content: Text('Markup tapped')),
                  ),
                  storageFolder: 'company/${companyRef.id}/mainImage',
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameCtl,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addPhoneNumber(
      DocumentReference<Map<String, dynamic>> companyRef) async {
    final phoneCtl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => DialogAction(
        title: 'Add Phone',
        cancelText: 'Cancel',
        actionText: 'Save',
        onCancel: () => Navigator.of(ctx).pop(),
        onAction: () async {
          final phone = phoneCtl.text.trim();
          if (phone.isNotEmpty) {
            await companyRef.update({
              'phoneNumbers': FieldValue.arrayUnion([phone])
            });
          }
          if (mounted) Navigator.of(ctx).pop();
        },
        content: TextField(
          controller: phoneCtl,
          decoration: const InputDecoration(labelText: 'Phone Number'),
          keyboardType: TextInputType.phone,
        ),
      ),
    );
  }

  Future<void> _addEmail(
      DocumentReference<Map<String, dynamic>> companyRef) async {
    final emailCtl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => DialogAction(
        title: 'Add Email',
        cancelText: 'Cancel',
        actionText: 'Save',
        onCancel: () => Navigator.of(ctx).pop(),
        onAction: () async {
          final email = emailCtl.text.trim();
          if (email.isNotEmpty) {
            await companyRef.update({
              'emails': FieldValue.arrayUnion([email])
            });
          }
          if (mounted) Navigator.of(ctx).pop();
        },
        content: TextField(
          controller: emailCtl,
          decoration: const InputDecoration(labelText: 'Email'),
          keyboardType: TextInputType.emailAddress,
        ),
      ),
    );
  }

  Future<void> _addLocation(
      DocumentReference<Map<String, dynamic>> companyRef) async {
    final addressCtl = TextEditingController();
    final cityCtl = TextEditingController();
    final stateCtl = TextEditingController();
    final zipCtl = TextEditingController();
    String type = 'Office';
    double? lat;
    double? lng;

    await showDialog(
      context: context,
      builder: (ctx) => DialogAction(
        title: 'Add Location',
        cancelText: 'Cancel',
        actionText: 'Save',
        onCancel: () => Navigator.of(ctx).pop(),
        onAction: () async {
          final map = {
            'address': addressCtl.text.trim(),
            'city': cityCtl.text.trim(),
            'state': stateCtl.text.trim(),
            'zip': zipCtl.text.trim(),
            'type': type,
            if (lat != null) 'lat': lat,
            if (lng != null) 'lng': lng,
          };
          await companyRef.update({
            'locations': FieldValue.arrayUnion([map])
          });
          if (mounted) Navigator.of(ctx).pop();
        },
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GoogleAddressField(
                apiKey: kGoogleApiKey,
                controller: addressCtl,
                onSelected: (m) {
                  lat = (m['lat'] as num?)?.toDouble();
                  lng = (m['lng'] as num?)?.toDouble();
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: cityCtl,
                decoration: const InputDecoration(labelText: 'City'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: stateCtl,
                decoration: const InputDecoration(labelText: 'State'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: zipCtl,
                decoration: const InputDecoration(labelText: 'Zip Code'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'Office', child: Text('Office')),
                  DropdownMenuItem(
                      value: 'Warehouse', child: Text('Warehouse')),
                ],
                onChanged: (v) => type = v ?? 'Office',
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final companyAsync = ref.watch(companyIdProvider);
    final bool hideChrome = false;

    return companyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (companyRef) {
        if (companyRef == null) {
          return const Center(child: Text('No company found.'));
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: companyRef.snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.data!.exists) {
              return const Center(child: Text('Company not found.'));
            }

            final data = snapshot.data!.data() ?? {};
            final name = data['name'] as String? ?? '';
            final locations = (data['locations'] as List<dynamic>? ?? [])
                .map((loc) => Map<String, dynamic>.from(loc as Map))
                .toList();
            final phoneNumbers = (data['phoneNumbers'] as List<dynamic>? ?? [])
                .map((e) => e.toString())
                .toList();
            final emails = (data['emails'] as List<dynamic>? ?? [])
                .map((e) => e.toString())
                .toList();

            final locationWidgets = locations.map<Widget>((loc) {
              final address = loc['address'] ?? '';
              final city = loc['city'] ?? '';
              final state = loc['state'] ?? '';
              final zip = loc['zip'] ?? '';
              final type = loc['type'] ?? '';
              final parts = [address, city, state, zip]
                  .where((e) => (e as String).isNotEmpty)
                  .join(', ');
              final display =
                  type.toString().isNotEmpty ? '$parts ($type)' : parts;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text(display),
              );
            }).toList();

            final phoneWidgets = phoneNumbers.map<Widget>((p) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text(p),
              );
            }).toList();

            final emailWidgets = emails.map<Widget>((e) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text(e),
              );
            }).toList();

            final bottomPadding =
                (hideChrome ? 16.0 : kBottomNavigationBarHeight + 16.0) +
                    MediaQuery.of(context).padding.bottom;

            final headerImagesFuture = CompanyFileImages.headerImageEntries(
              companyRef: companyRef,
            );

            return Stack(
              children: [
                NotificationListener<ScrollNotification>(
                  onNotification: (scroll) {
                    if (scroll is ScrollUpdateNotification &&
                        scroll.scrollDelta != null) {
                      if (scroll.scrollDelta! > 0 && _fabVisible.value) {
                        _fabVisible.value = false;
                      } else if (scroll.scrollDelta! < 0 &&
                          !_fabVisible.value) {
                        _fabVisible.value = true;
                      }
                    }
                    return false;
                  },
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: EdgeInsets.only(bottom: bottomPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: headerImagesFuture,
                          builder: (context, imageSnap) {
                            final fileImages = imageSnap.data ??
                                const <Map<String, dynamic>>[];
                            final fileImageUrl = fileImages.isNotEmpty
                                ? (fileImages.first['url'] as String?)?.trim()
                                : null;
                            final resolvedImageUrl = (fileImageUrl != null &&
                                    fileImageUrl.isNotEmpty)
                                ? fileImageUrl
                                : '';
                            final headerImages =
                                fileImages.isNotEmpty ? fileImages : null;
                            return ContainerHeader(
                              image: resolvedImageUrl.isNotEmpty
                                  ? resolvedImageUrl
                                  : null,
                              images: headerImages,
                              showImage: resolvedImageUrl.isNotEmpty,
                              titleHeader: 'Name',
                              title: name,
                              descriptionHeader: '',
                              description: '',
                            );
                          },
                        ),
                        ContainerActionWidget(
                          title: 'Phone (Main)',
                          actionText: 'Add',
                          onAction: () => _addPhoneNumber(companyRef),
                          content: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: phoneWidgets.isNotEmpty
                                ? phoneWidgets
                                : const [Text('No phone numbers found.')],
                          ),
                        ),
                        ContainerActionWidget(
                          title: 'Email (Main)',
                          actionText: 'Add',
                          onAction: () => _addEmail(companyRef),
                          content: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: emailWidgets.isNotEmpty
                                ? emailWidgets
                                : const [Text('No emails found.')],
                          ),
                        ),
                        ContainerActionWidget(
                          title: 'Locations',
                          actionText: 'Add',
                          onAction: () => _addLocation(companyRef),
                          content: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: locationWidgets.isNotEmpty
                                ? locationWidgets
                                : const [Text('No locations found.')],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: _buildAnimatedFab(
                    companyRef,
                    name,
                    '',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
