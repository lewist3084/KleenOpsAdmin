/* ──────────────────────────────────────────────────────────── */
/*  lib/hr_ticket_scanner_screen.dart                             */
/*  – rev 2025-05-16 – accepts full https:// links or raw IDs  */
/* ──────────────────────────────────────────────────────────── */
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';

class HrTicketScannerScreen extends StatefulWidget {
  const HrTicketScannerScreen({super.key});

  @override
  State<HrTicketScannerScreen> createState() => _HrTicketScannerScreenState();
}

class _HrTicketScannerScreenState extends State<HrTicketScannerScreen> {
  bool _processing = false;
  String? _message;

  String? _extractTicketId(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final uri = Uri.tryParse(trimmed);
    if (uri == null) return trimmed;

    final isLikelyUrl = uri.hasAuthority || uri.scheme.isNotEmpty;
    if (!isLikelyUrl) return trimmed;

    const queryKeys = ['ticketId', 'ticket', 'ticket_id', 't'];
    for (final key in queryKeys) {
      final value = uri.queryParameters[key];
      if (value == null) continue;
      final cleaned = value.trim();
      if (cleaned.isNotEmpty) return cleaned;
    }

    final segments = uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
    if (segments.isEmpty) return trimmed;

    final ticketIndex = segments.indexWhere(
      (segment) {
        final lowered = segment.toLowerCase();
        return lowered == 'tickets' || lowered == 'ticket';
      },
    );
    if (ticketIndex >= 0 && ticketIndex + 1 < segments.length) {
      return segments[ticketIndex + 1];
    }

    final last = segments.last;
    final loweredLast = last.toLowerCase();
    if (loweredLast == 'onboarding' || loweredLast == 'scan') return null;
    return last;
  }

  String _formatFunctionsError(FirebaseFunctionsException error) {
    final code = error.code;
    final message = error.message?.trim();
    final lowerMessage = message?.toLowerCase() ?? '';

    if (code == 'unavailable') {
      return 'Service unavailable. Check your connection and try again.';
    }
    if (code == 'unauthenticated') {
      return 'Please sign in again and retry.';
    }
    if (code == 'permission-denied' || lowerMessage.contains('permission denied')) {
      return 'You do not have permission to assign onboarding tickets.';
    }
    if (code == 'invalid-argument' || lowerMessage.contains('bad arguments')) {
      return 'Invalid onboarding code. Ask the employee to refresh it.';
    }
    if (message != null && message.isNotEmpty) {
      return 'Request failed ($code): $message';
    }
    return 'Request failed ($code).';
  }

  Future<void> _handleCapture(BarcodeCapture capture) async {
    if (_processing) return;
    if (capture.barcodes.isEmpty) return;

    final raw = capture.barcodes.first.rawValue;
    if (raw == null) return;

    final ticketId = _extractTicketId(raw);
    if (ticketId == null || ticketId.length < 8) {
      setState(() {
        _processing = true;
        _message = 'Invalid onboarding code.';
      });
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      setState(() {
        _processing = false;
        _message = null;
      });
      return; // rudimentary sanity check
    }

    setState(() {
      _processing = true;
      _message = 'Processing ticket...';
    });

    final companyRef =
        ModalRoute.of(context)!.settings.arguments as DocumentReference<
            Map<String, dynamic>>?;

    if (companyRef == null) {
      setState(() {
        _processing = false;
        _message = 'Scanner opened without a company context';
      });
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.pop(context);
      return;
    }

    _AssignmentResult? selection;
    try {
      setState(() => _message = 'Loading teams and roles...');
      selection = await _promptAssignment(companyRef);
    } on StateError catch (e) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _message = e.message ?? e.toString();
      });
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      setState(() => _message = null);
      return;
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _message = 'Unable to load teams and roles (${e.code}).';
      });
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      setState(() => _message = null);
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _message = 'Unable to load teams and roles: $e';
      });
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      setState(() => _message = null);
      return;
    }

    if (selection == null) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _message = 'Assignment cancelled';
      });
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() => _message = null);
      return;
    }

    final chosen = selection!;

    try {
      setState(() => _message =
          'Assigning ${chosen.team.label} / ${chosen.role.label}...');

      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable(
        'claimUserTicket',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
      );
      await callable.call({
        'ticketId': ticketId,
        'companyId': companyRef.id,
        'teamId': chosen.team.ref.id,
        'roleId': chosen.role.ref.id,
        if (chosen.profileRef != null) 'profileId': chosen.profileRef!.id,
      });

      if (!mounted) return;
      setState(() =>
          _message = 'Success! ${chosen.team.label} / ${chosen.role.label}');
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.pop(context);
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _message = _formatFunctionsError(e);
      });
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _message = 'Error: $e';
      });
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.pop(context);
    }
  }
  Future<_AssignmentResult?> _promptAssignment(
    DocumentReference<Map<String, dynamic>> companyRef,
  ) async {
    final teamSnap = await FirebaseFirestore.instance.collection('team').get();
    final roleSnap = await FirebaseFirestore.instance.collection('role').get();
    final profileSnap = await companyRef
        .collection('onboardingProfile')
        .orderBy('name')
        .get();

    final teamOptions = teamSnap.docs
        .map((doc) => _AssignmentOption(
              ref: doc.reference,
              label: _resolveLabel(doc.data(), 'team', doc.id),
            ))
        .toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));

    final roleOptions = roleSnap.docs
        .map((doc) => _AssignmentOption(
              ref: doc.reference,
              label: _resolveLabel(doc.data(), 'role', doc.id),
            ))
        .toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));

    final profileOptions = profileSnap.docs
        .map((doc) => _ProfileOption(
              ref: doc.reference,
              label: _resolveLabel(doc.data(), 'profile', doc.id),
              defaultTeamRef: doc.data()['defaultTeamId'] is DocumentReference
                  ? doc.data()['defaultTeamId'] as DocumentReference
                  : null,
              defaultRoleRef: doc.data()['defaultRoleId'] is DocumentReference
                  ? doc.data()['defaultRoleId'] as DocumentReference
                  : null,
            ))
        .toList();

    if (teamOptions.isEmpty) {
      throw StateError('No teams available. Please create a team first.');
    }
    if (roleOptions.isEmpty) {
      throw StateError('No roles available. Please create a role first.');
    }

    _ProfileOption? selectedProfile;
    _AssignmentOption? selectedTeam;
    _AssignmentOption? selectedRole;
    String? errorText;
    void Function(VoidCallback) rebuild = (_) {};

    _AssignmentOption? optionForRef(
      List<_AssignmentOption> options,
      DocumentReference? ref,
    ) {
      if (ref == null) return null;
      for (final opt in options) {
        if (opt.ref.path == ref.path) return opt;
      }
      return null;
    }

    return showDialog<_AssignmentResult>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return DialogAction(
          title: 'Assign team & role',
          content: StatefulBuilder(
            builder: (ctx, setState) {
              rebuild = setState;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (profileOptions.isNotEmpty) ...[
                    DropdownButtonFormField<_ProfileOption?>(
                      value: selectedProfile,
                      decoration: const InputDecoration(
                        labelText: 'Profile (optional)',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<_ProfileOption?>(
                          value: null,
                          child: Text('— None —'),
                        ),
                        ...profileOptions.map(
                          (opt) => DropdownMenuItem<_ProfileOption?>(
                            value: opt,
                            child: Text(opt.label),
                          ),
                        ),
                      ],
                      onChanged: (value) => setState(() {
                        selectedProfile = value;
                        if (value != null) {
                          final teamFromProfile =
                              optionForRef(teamOptions, value.defaultTeamRef);
                          if (teamFromProfile != null) {
                            selectedTeam = teamFromProfile;
                          }
                          final roleFromProfile =
                              optionForRef(roleOptions, value.defaultRoleRef);
                          if (roleFromProfile != null) {
                            selectedRole = roleFromProfile;
                          }
                        }
                        errorText = null;
                      }),
                    ),
                    const SizedBox(height: 16),
                  ],
                  DropdownButtonFormField<_AssignmentOption>(
                    value: selectedTeam,
                    decoration: const InputDecoration(
                      labelText: 'Team',
                      border: OutlineInputBorder(),
                    ),
                    items: teamOptions
                        .map((opt) => DropdownMenuItem(
                              value: opt,
                              child: Text(opt.label),
                            ))
                        .toList(),
                    onChanged: (value) => setState(() {
                      selectedTeam = value;
                      errorText = null;
                    }),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<_AssignmentOption>(
                    value: selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      border: OutlineInputBorder(),
                    ),
                    items: roleOptions
                        .map((opt) => DropdownMenuItem(
                              value: opt,
                              child: Text(opt.label),
                            ))
                        .toList(),
                    onChanged: (value) => setState(() {
                      selectedRole = value;
                      errorText = null;
                    }),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorText!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ],
              );
            },
          ),
          cancelText: 'Cancel',
          onCancel: () => Navigator.pop(dialogCtx, null),
          actionText: 'Save',
          onAction: () {
            if (selectedTeam == null || selectedRole == null) {
              rebuild(() => errorText = 'Select both a team and a role.');
              return;
            }
            Navigator.pop(
              dialogCtx,
              _AssignmentResult(
                team: selectedTeam!,
                role: selectedRole!,
                profileRef: selectedProfile?.ref
                    .withConverter<Map<String, dynamic>>(
                      fromFirestore: (s, _) => s.data() ?? <String, dynamic>{},
                      toFirestore: (m, _) => m,
                    ),
              ),
            );
          },
        );
      },
    );
  }

  String _resolveLabel(
    Map<String, dynamic> data,
    String fallbackKey,
    String fallbackId,
  ) {
    final name = (data['name'] as String?)?.trim();
    if (name != null && name.isNotEmpty) return name;
    final fallback = (data[fallbackKey] as String?)?.trim();
    if (fallback != null && fallback.isNotEmpty) return fallback;
    return fallbackId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MediaQuery.of(context).orientation == Orientation.landscape
          ? null
          : AppBar(title: const Text('Scan onboarding code')),
      body: Stack(
        children: [
          MobileScanner(onDetect: _handleCapture),
          if (_message != null)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_message!, style: const TextStyle(color: Colors.white)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AssignmentOption {
  const _AssignmentOption({
    required this.ref,
    required this.label,
  });

  final DocumentReference<Map<String, dynamic>> ref;
  final String label;
}

class _AssignmentResult {
  const _AssignmentResult({
    required this.team,
    required this.role,
    this.profileRef,
  });

  final _AssignmentOption team;
  final _AssignmentOption role;
  final DocumentReference<Map<String, dynamic>>? profileRef;
}

class _ProfileOption {
  const _ProfileOption({
    required this.ref,
    required this.label,
    this.defaultTeamRef,
    this.defaultRoleRef,
  });

  final DocumentReference<Map<String, dynamic>> ref;
  final String label;
  final DocumentReference? defaultTeamRef;
  final DocumentReference? defaultRoleRef;
}



