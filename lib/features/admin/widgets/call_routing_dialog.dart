import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';

import '../services/call_routing_service.dart';

/// Dialog for managing call routing: extensions, ring groups, and
/// auto-attendant toggle on provisioned phone numbers.
class CallRoutingDialog extends ConsumerStatefulWidget {
  const CallRoutingDialog({super.key});

  @override
  ConsumerState<CallRoutingDialog> createState() => _CallRoutingDialogState();
}

enum _Tab { extensions, ringGroups }

class _CallRoutingDialogState extends ConsumerState<CallRoutingDialog> {
  final _service = CallRoutingService.instance;
  _Tab _tab = _Tab.extensions;
  bool _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final companyRef = ref.watch(companyIdProvider).asData?.value;
    if (companyRef == null) {
      return const AlertDialog(
        content: SizedBox(
          height: 100,
          child: Center(child: Text('No company selected.')),
        ),
      );
    }

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.phone_in_talk_outlined,
              color: Theme.of(context).primaryColor),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Call Routing', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
      content: SizedBox(
        width: 560,
        height: 480,
        child: Column(
          children: [
            // Tab bar
            Row(
              children: [
                _tabButton('Extensions', _Tab.extensions),
                const SizedBox(width: 8),
                _tabButton('Ring Groups', _Tab.ringGroups),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!,
                    style: const TextStyle(color: Colors.red, fontSize: 13)),
              ),
            const SizedBox(height: 12),
            Expanded(
              child: switch (_tab) {
                _Tab.extensions => _ExtensionsTab(
                    companyRef: companyRef,
                    service: _service,
                    onError: (e) => setState(() => _error = e),
                  ),
                _Tab.ringGroups => _RingGroupsTab(
                    companyRef: companyRef,
                    service: _service,
                    onError: (e) => setState(() => _error = e),
                  ),
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _tabButton(String label, _Tab tab) {
    final selected = _tab == tab;
    return TextButton(
      style: TextButton.styleFrom(
        backgroundColor:
            selected ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
      ),
      onPressed: () => setState(() {
        _tab = tab;
        _error = null;
      }),
      child: Text(label,
          style: TextStyle(
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          )),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Extensions Tab
// ═══════════════════════════════════════════════════════════════

class _ExtensionsTab extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final CallRoutingService service;
  final ValueChanged<String?> onError;

  const _ExtensionsTab({
    required this.companyRef,
    required this.service,
    required this.onError,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Employee Extensions',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Assign Extension'),
              onPressed: () => _showAssignDialog(context),
            ),
          ],
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: service.watchExtensions(companyRef),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(
                  child: Text('No extensions assigned yet.',
                      style: TextStyle(color: Colors.grey)),
                );
              }
              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final data = docs[i].data();
                  final ext = data['extension'] ?? '—';
                  final name = data['displayName'] ?? docs[i].id;
                  final available = data['available'] != false;
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: available
                          ? Colors.green.shade100
                          : Colors.grey.shade200,
                      child: Text(ext,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(name, style: const TextStyle(fontSize: 14)),
                    subtitle: Text(
                      available ? 'Available' : 'Do Not Disturb',
                      style: TextStyle(
                        fontSize: 12,
                        color: available ? Colors.green : Colors.orange,
                      ),
                    ),
                    trailing: Text('ext $ext',
                        style: const TextStyle(
                            fontSize: 13, color: Colors.grey)),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAssignDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _AssignExtensionDialog(
        companyRef: companyRef,
        service: service,
        onError: onError,
      ),
    );
  }
}

// ── Assign Extension Dialog ──────────────────────────────────

class _AssignExtensionDialog extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final CallRoutingService service;
  final ValueChanged<String?> onError;

  const _AssignExtensionDialog({
    required this.companyRef,
    required this.service,
    required this.onError,
  });

  @override
  State<_AssignExtensionDialog> createState() => _AssignExtensionDialogState();
}

class _AssignExtensionDialogState extends State<_AssignExtensionDialog> {
  final _extCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  String? _selectedUid;
  bool _busy = false;
  String? _error;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _members = [];
  bool _loadingMembers = true;
  StreamSubscription? _memberSub;

  @override
  void initState() {
    super.initState();
    _memberSub = widget.service.watchMembers(widget.companyRef).listen((snap) {
      if (mounted) {
        setState(() {
          _members = snap.docs;
          _loadingMembers = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _extCtrl.dispose();
    _nameCtrl.dispose();
    _memberSub?.cancel();
    super.dispose();
  }

  Future<void> _assign() async {
    if (_selectedUid == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.service.manageExtension(
        companyId: widget.companyRef.id,
        targetUid: _selectedUid,
        extension:
            _extCtrl.text.trim().isNotEmpty ? _extCtrl.text.trim() : null,
        displayName:
            _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : null,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.toString().contains('already-exists')
              ? 'That extension number is already taken.'
              : 'Failed to assign extension.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Assign Extension', style: TextStyle(fontSize: 15)),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_loadingMembers)
              const Center(child: CircularProgressIndicator())
            else
              DropdownButtonFormField<String>(
                decoration:
                    const InputDecoration(labelText: 'Select Employee'),
                items: _members.map((doc) {
                  final d = doc.data();
                  final label = d['displayName'] ?? d['name'] ?? doc.id;
                  return DropdownMenuItem(value: doc.id, child: Text(label));
                }).toList(),
                onChanged: (uid) {
                  _selectedUid = uid;
                  // Pre-fill display name
                  if (uid != null) {
                    final match =
                        _members.where((d) => d.id == uid).firstOrNull;
                    if (match != null) {
                      final name = match.data()['displayName'] ??
                          match.data()['name'] ??
                          '';
                      _nameCtrl.text = name;
                    }
                  }
                },
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                hintText: 'Shown to callers',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _extCtrl,
              decoration: const InputDecoration(
                labelText: 'Extension (optional)',
                hintText: 'Leave blank to auto-assign',
              ),
              keyboardType: TextInputType.number,
              maxLength: 3,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!,
                    style: const TextStyle(color: Colors.red, fontSize: 13)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _assign,
          child: _busy
              ? const SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Assign'),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Ring Groups Tab
// ═══════════════════════════════════════════════════════════════

class _RingGroupsTab extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final CallRoutingService service;
  final ValueChanged<String?> onError;

  const _RingGroupsTab({
    required this.companyRef,
    required this.service,
    required this.onError,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Departments',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Ring Group'),
              onPressed: () => _showCreateDialog(context),
            ),
          ],
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: service.watchRingGroups(companyRef),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(
                  child: Text('No ring groups configured yet.',
                      style: TextStyle(color: Colors.grey)),
                );
              }
              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final data = docs[i].data();
                  final name = data['name'] ?? '—';
                  final ext = data['extension'] ?? '?';
                  final members =
                      (data['memberUids'] as List?)?.length ?? 0;
                  final strategy = data['ringStrategy'] ?? 'simultaneous';
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: Theme.of(context)
                          .primaryColor
                          .withOpacity(0.15),
                      child: Text(ext,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                    title:
                        Text(name, style: const TextStyle(fontSize: 14)),
                    subtitle: Text(
                      '$members member${members == 1 ? '' : 's'} · $strategy',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Press $ext',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          onPressed: () =>
                              _showCreateDialog(context, existing: docs[i]),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 18, color: Colors.red),
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Delete Ring Group?'),
                                content: Text(
                                    'Remove "$name"? Callers will no longer be able to press $ext.'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    style: FilledButton.styleFrom(
                                        backgroundColor: Colors.red),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true) {
                              try {
                                await service.deleteRingGroup(
                                    companyRef, docs[i].id);
                              } catch (e) {
                                onError('Failed to delete ring group.');
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showCreateDialog(BuildContext context,
      {QueryDocumentSnapshot<Map<String, dynamic>>? existing}) {
    showDialog(
      context: context,
      builder: (_) => _RingGroupFormDialog(
        companyRef: companyRef,
        service: service,
        onError: onError,
        existing: existing,
      ),
    );
  }
}

// ── Ring Group Form Dialog ───────────────────────────────────

class _RingGroupFormDialog extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final CallRoutingService service;
  final ValueChanged<String?> onError;
  final QueryDocumentSnapshot<Map<String, dynamic>>? existing;

  const _RingGroupFormDialog({
    required this.companyRef,
    required this.service,
    required this.onError,
    this.existing,
  });

  @override
  State<_RingGroupFormDialog> createState() => _RingGroupFormDialogState();
}

class _RingGroupFormDialogState extends State<_RingGroupFormDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _extCtrl;
  Set<String> _selectedUids = {};
  bool _busy = false;
  String? _error;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _members = [];
  bool _loadingMembers = true;
  StreamSubscription? _memberSub;

  @override
  void initState() {
    super.initState();
    final data = widget.existing?.data();
    _nameCtrl = TextEditingController(text: data?['name'] ?? '');
    _extCtrl = TextEditingController(text: data?['extension'] ?? '');
    if (data != null && data['memberUids'] is List) {
      _selectedUids = Set<String>.from(data['memberUids'] as List);
    }
    _memberSub =
        widget.service.watchMembers(widget.companyRef).listen((snap) {
      if (mounted) {
        setState(() {
          _members = snap.docs;
          _loadingMembers = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _extCtrl.dispose();
    _memberSub?.cancel();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final ext = _extCtrl.text.trim();
    if (name.isEmpty || ext.isEmpty) {
      setState(() => _error = 'Name and extension digit are required.');
      return;
    }
    if (!RegExp(r'^[1-9]$').hasMatch(ext)) {
      setState(() => _error = 'Extension must be a single digit 1-9.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await widget.service.manageRingGroup(
        companyId: widget.companyRef.id,
        groupId: widget.existing?.id,
        name: name,
        extension: ext,
        memberUids: _selectedUids.toList(),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.toString().contains('already-exists')
              ? 'A ring group with that extension digit already exists.'
              : 'Failed to save ring group.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit Ring Group' : 'New Ring Group',
          style: const TextStyle(fontSize: 15)),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Department Name',
                  hintText: 'e.g. Sales, Support',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _extCtrl,
                decoration: const InputDecoration(
                  labelText: 'IVR Digit (1-9)',
                  hintText: '"Press 1 for Sales"',
                ),
                keyboardType: TextInputType.number,
                maxLength: 1,
              ),
              const SizedBox(height: 12),
              const Text('Members',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 4),
              if (_loadingMembers)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                ..._members.map((doc) {
                  final d = doc.data();
                  final label = d['displayName'] ?? d['name'] ?? doc.id;
                  final checked = _selectedUids.contains(doc.id);
                  return CheckboxListTile(
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(label, style: const TextStyle(fontSize: 13)),
                    value: checked,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedUids.add(doc.id);
                        } else {
                          _selectedUids.remove(doc.id);
                        }
                      });
                    },
                  );
                }),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!,
                      style:
                          const TextStyle(color: Colors.red, fontSize: 13)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(isEdit ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}
