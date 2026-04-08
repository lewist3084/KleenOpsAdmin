// lib/features/registration/screens/registration_internal_setup_screen.dart
//
// Internal-use registration form:
//   1. Company name
//   2. Property type — pick from the global propertyType collection
//      (sorted alphabetically). The dropdown also offers an "Other"
//      option that opens a small dialog so the user can name their own
//      property type. There is no separate free-text field — the user
//      must always make a choice from the dropdown.
//
// On submit, creates the kleenops doc + member + memberByUid via
// RegistrationService and routes the user to the dashboard. The
// background "basic setup" items will be wired in later.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';

import '../../../app/routes.dart';
import '../../../theme/palette.dart';
import '../../auth/providers/auth_provider.dart';
import '../services/registration_service.dart';

const String _kOtherPropertyTypeKey = '__other__';

class RegistrationInternalSetupScreen extends ConsumerStatefulWidget {
  const RegistrationInternalSetupScreen({super.key});

  @override
  ConsumerState<RegistrationInternalSetupScreen> createState() =>
      _RegistrationInternalSetupScreenState();
}

class _RegistrationInternalSetupScreenState
    extends ConsumerState<RegistrationInternalSetupScreen> {
  final _nameController = TextEditingController();
  // Selected dropdown key: either a property-type doc id, or
  // [_kOtherPropertyTypeKey] when the user chose "Other".
  String? _selectedKey;
  // Map populated by the StreamBuilder so we can resolve the selected
  // key back to a DocumentReference at save time.
  final Map<String, DocumentReference<Map<String, dynamic>>> _refsByKey = {};
  // Free-text name captured when the user picks "Other".
  String? _customPropertyTypeName;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a company name.')),
      );
      return;
    }
    if (_selectedKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick a property type.')),
      );
      return;
    }
    final isOther = _selectedKey == _kOtherPropertyTypeKey;
    final customType = (_customPropertyTypeName ?? '').trim();
    if (isOther && customType.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a name for your property type.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      // If the user already has a kleenops entity (an owner whose
      // entity pre-dates the fork-style flow), backfill the missing
      // fields on the existing doc instead of creating a second one.
      final gate = ref.read(kleenopsProfileGateProvider).asData?.value;
      final existingKleenopsId = gate?.kleenopsId;
      if (existingKleenopsId != null && gate?.isOwner == true) {
        await RegistrationService.instance.updateKleenopsProfile(
          kleenopsId: existingKleenopsId,
          businessType: 'internalUse',
          propertyTypeRef: isOther ? null : _refsByKey[_selectedKey],
          propertyTypeName: isOther ? customType : null,
        );
      } else {
        await RegistrationService.instance.createKleenopsEntity(
          name: name,
          businessType: 'internalUse',
          propertyTypeRef: isOther ? null : _refsByKey[_selectedKey],
          propertyTypeName: isOther ? customType : null,
        );
      }

      // Refresh providers so the router redirect picks up the new membership.
      ref.invalidate(companyIdProvider);
      ref.invalidate(userDocumentProvider);
      ref.invalidate(memberDocRefProvider);
      ref.invalidate(kleenopsProfileGateProvider);

      if (mounted) {
        context.go(AppRoutePaths.dashboard);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating company: $e')),
        );
      }
    }
  }

  String _resolvePropertyTypeName(Map<String, dynamic> data) {
    final raw = data['name'];
    if (raw is String) return raw;
    if (raw is Map) {
      final en = raw['en'];
      if (en is String && en.isNotEmpty) return en;
      for (final v in raw.values) {
        if (v is String && v.isNotEmpty) return v;
      }
    }
    return 'Unnamed type';
  }

  /// Opens a small dialog so the user can name a custom property type.
  /// On save, selects the synthetic "Other" entry and stashes the name;
  /// on cancel, leaves the dropdown selection unchanged from before.
  Future<void> _promptCustomPropertyType({String? previousKey}) async {
    final controller =
        TextEditingController(text: _customPropertyTypeName ?? '');
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return DialogAction(
          title: 'Enter property type',
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Property type name',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) {
              final value = controller.text.trim();
              if (value.isEmpty) return;
              Navigator.of(ctx).pop(value);
            },
          ),
          cancelText: 'Cancel',
          actionText: 'Save',
          onCancel: () => Navigator.of(ctx).pop(),
          onAction: () {
            final value = controller.text.trim();
            if (value.isEmpty) return;
            Navigator.of(ctx).pop(value);
          },
        );
      },
    );
    if (!mounted) return;
    if (result == null || result.isEmpty) {
      // Revert to whatever was selected before "Other" was tapped.
      setState(() => _selectedKey = previousKey);
      return;
    }
    setState(() {
      _selectedKey = _kOtherPropertyTypeKey;
      _customPropertyTypeName = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    const palette = adminPalette;

    // Pre-fill the company name from the existing kleenops doc when an
    // owner has been redirected here to backfill missing fields.
    final gate = ref.watch(kleenopsProfileGateProvider).asData?.value;
    final isBackfill = gate?.kleenopsId != null && gate?.isOwner == true;
    if (isBackfill && _nameController.text.isEmpty) {
      FirebaseFirestore.instance
          .collection('kleenops')
          .doc(gate!.kleenopsId)
          .get()
          .then((snap) {
        if (!mounted) return;
        final existingName = snap.data()?['name'] as String?;
        if (existingName != null && existingName.isNotEmpty &&
            _nameController.text.isEmpty) {
          setState(() => _nameController.text = existingName);
        }
      }).catchError((_) {});
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: palette.primary3.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.apartment,
                          size: 56, color: palette.primary3),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Tell us about your organization',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: palette.primary3,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Just two quick questions and we will set you up.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.grey.shade700,
                            height: 1.5,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),

                    /* ─── Company name ─── */
                    TextField(
                      controller: _nameController,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Company name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    /* ─── Property type dropdown (sorted alphabetically) ─── */
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream:
                          RegistrationService.instance.propertyTypesStream(),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const LinearProgressIndicator();
                        }
                        if (snap.hasError) {
                          return Text(
                            'Error loading property types: ${snap.error}',
                            style: const TextStyle(color: Colors.red),
                          );
                        }
                        final docs = (snap.data?.docs ?? []).toList()
                          ..sort((a, b) => _resolvePropertyTypeName(a.data())
                              .toLowerCase()
                              .compareTo(_resolvePropertyTypeName(b.data())
                                  .toLowerCase()));
                        // Refresh the id->ref lookup whenever the stream
                        // emits so _save() can resolve the selection.
                        _refsByKey
                          ..clear()
                          ..addEntries(
                              docs.map((d) => MapEntry(d.id, d.reference)));
                        return DropdownButtonFormField<String>(
                          initialValue: _selectedKey,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Property type',
                            border: OutlineInputBorder(),
                          ),
                          selectedItemBuilder: (context) {
                            return [
                              ...docs.map((doc) => Text(
                                  _resolvePropertyTypeName(doc.data()))),
                              Text(_customPropertyTypeName?.isNotEmpty == true
                                  ? _customPropertyTypeName!
                                  : 'Other…'),
                            ];
                          },
                          items: [
                            ...docs.map((doc) {
                              return DropdownMenuItem<String>(
                                value: doc.id,
                                child: Text(
                                    _resolvePropertyTypeName(doc.data())),
                              );
                            }),
                            DropdownMenuItem<String>(
                              value: _kOtherPropertyTypeKey,
                              child: Text(
                                _customPropertyTypeName?.isNotEmpty == true
                                    ? 'Other: ${_customPropertyTypeName!}'
                                    : 'Other…',
                                style: const TextStyle(
                                    fontStyle: FontStyle.italic),
                              ),
                            ),
                          ],
                          onChanged: _saving
                              ? null
                              : (v) {
                                  if (v == null) return;
                                  if (v == _kOtherPropertyTypeKey) {
                                    _promptCustomPropertyType(
                                        previousKey: _selectedKey);
                                  } else {
                                    setState(() {
                                      _selectedKey = v;
                                      _customPropertyTypeName = null;
                                    });
                                  }
                                },
                        );
                      },
                    ),
                    const SizedBox(height: 32),

                    /* ─── Save button ─── */
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: palette.primary1,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Continue'),
                    ),
                  ],
                ),
              ),
            ),
            // Back arrow last so it sits on top of the scroll view.
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back',
                onPressed: () =>
                    context.go(AppRoutePaths.registrationBusinessType),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
