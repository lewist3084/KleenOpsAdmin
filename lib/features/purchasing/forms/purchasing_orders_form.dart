// lib/features/purchasing/forms/purchasing_orders_form.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/forms/cancel_save_adapter.dart';
import 'package:shared_widgets/services/firestore_service.dart';
import 'package:shared_widgets/search/search_field_action.dart';
import 'package:kleenops_admin/features/purchasing/details/purchasing_order_details.dart';

class PurchasingOrdersForm extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyId;
  final String? docId;

  const PurchasingOrdersForm({
    super.key,
    required this.companyId,
    this.docId,
  });

  @override
  State<PurchasingOrdersForm> createState() => _PurchasingOrdersFormState();
}

class _PurchasingOrdersFormState extends State<PurchasingOrdersForm> {
  final TextEditingController _poNumberController = TextEditingController();
  final TextEditingController _dateController =
      TextEditingController(text: DateFormat('yMMMd').format(DateTime.now()));
  DateTime _createdDate = DateTime.now();
  DocumentReference<Map<String, dynamic>>? _selectedVendor;
  DocumentReference<Map<String, dynamic>>? _selectedTeam;
  DocumentReference<Map<String, dynamic>>? _selectedProject;
  DocumentReference<Map<String, dynamic>>? _selectedPoContact;
  DocumentReference<Map<String, dynamic>>? _selectedVendorContact;
  Map<String, dynamic>? _billingAddress;
  Map<String, dynamic>? _shipToAddress;
  bool _poNumberEditable = false;
  bool _loading = true;
  bool _saving = false;
  late final String _aiContextKey = _buildAiContextKey();

  String _buildAiContextKey() {
    final id = widget.docId?.trim();
    final token = (id != null && id.isNotEmpty)
        ? id
        : UniqueKey().toString();
    return 'purchasing_order_form:$token';
  }

  @override
  void initState() {
    super.initState();
    if (widget.docId != null) {
      _loadData();
    } else {
      _initializePoNumber();
      // Do not pre-fill the PO contact with the current user
      _selectedPoContact = null;
      _selectedVendorContact = null;
    }
  }

  Future<void> _loadData() async {
    try {
      final doc = await widget.companyId
          .collection('purchaseOrder')
          .doc(widget.docId)
          .get();
      if (doc.exists) {
        if (doc.data()?['poNumber'] != null) {
          _poNumberController.text = doc.data()!['poNumber'].toString();
        }
        if (doc.data()?['createdAt'] != null) {
          _createdDate =
              (doc.data()!['createdAt'] as Timestamp).toDate();
          _dateController.text = DateFormat('yMMMd').format(_createdDate);
        }
        _selectedVendor = doc.data()?['vendorId']
            as DocumentReference<Map<String, dynamic>>?;
        _selectedTeam = doc.data()?['teamId']
            as DocumentReference<Map<String, dynamic>>?;
        _selectedProject = doc.data()?['projectId']
            as DocumentReference<Map<String, dynamic>>?;
        _selectedPoContact = doc.data()?['poContactId']
            as DocumentReference<Map<String, dynamic>>?;
        _selectedVendorContact = doc.data()?['vendorContactId']
            as DocumentReference<Map<String, dynamic>>?;
        _billingAddress =
            doc.data()?['billingAddress'] as Map<String, dynamic>?;
        _shipToAddress =
            doc.data()?['shipToAddress'] as Map<String, dynamic>?;
      }
      _poNumberEditable = false;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error loading: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _initializePoNumber() async {
    try {
      final snap = await widget.companyId
          .collection('purchaseOrder')
          .orderBy('poNumber', descending: true)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) {
        _poNumberEditable = true;
      } else {
        final maxNum = snap.docs.first.data()['poNumber'] as int? ?? 0;
        _poNumberController.text = (maxNum + 1).toString();
        _poNumberEditable = false;
      }
    } catch (e) {
      _poNumberEditable = true;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectDate() async {
    // Remove focus from any active field before opening the date picker
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _createdDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        _createdDate = picked;
        _dateController.text = DateFormat('yMMMd').format(picked);
      });
    }
  }

  Future<void> _saveForm() async {
    final poNum = int.tryParse(_poNumberController.text.trim() == ''
        ? '0'
        : _poNumberController.text.trim());
    setState(() => _saving = true);

    final data = {
      if (poNum != null) 'poNumber': poNum,
      'createdAt': Timestamp.fromDate(_createdDate),
      if (_selectedVendor != null) 'vendorId': _selectedVendor,
      if (_selectedTeam != null) 'teamId': _selectedTeam,
      if (_selectedProject != null) 'projectId': _selectedProject,
      if (_selectedPoContact != null) 'poContactId': _selectedPoContact,
      if (_selectedVendorContact != null) 'vendorContactId': _selectedVendorContact,
      if (_billingAddress != null) 'billingAddress': _billingAddress,
      if (_shipToAddress != null) 'shipToAddress': _shipToAddress,
    };

    final collection = widget.companyId.collection('purchaseOrder');
    try {
      final docRef = (widget.docId != null && widget.docId!.isNotEmpty)
          ? collection.doc(widget.docId)
          : collection.doc();
      await docRef.set(data, SetOptions(merge: true));
      if (!mounted) return;
      if (widget.docId == null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => PurchasingOrderDetailsScreen(
              companyId: widget.companyId.id,
              docId: docRef.id,
            ),
          ),
        );
      } else {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }


  @override
  void dispose() {
    _poNumberController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final docId = widget.docId?.trim();
    final orderRef = docId != null && docId.isNotEmpty
        ? widget.companyId.collection('purchaseOrder').doc(docId)
        : null;
    return Scaffold(
      appBar: StandardAppBar(
        title: widget.docId == null
            ? 'New Purchase Order'
            : 'Edit Purchase Order',
      ),
      body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _poNumberController,
                  readOnly: !_poNumberEditable,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'PO Number',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _dateController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  onTap: _selectDate,
                ),
                const SizedBox(height: 16),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: widget.companyId
                      .collection('team')
                      .orderBy('name')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const SizedBox(
                        height: 60,
                        child: Center(child: Text('Error loading teams')),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const SizedBox(
                        height: 60,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final docs = snapshot.data!.docs;
                    final items = docs.map((d) => d.reference).toList();
                    return SearchAddSelectDropdown<
                        DocumentReference<Map<String, dynamic>>>(
                      label: 'Team',
                      items: items,
                      initialValue: _selectedTeam,
                      itemLabel: (ref) {
                        final d = docs.firstWhere((doc) => doc.reference == ref);
                        return (d.data()['name'] ?? 'Unnamed Team') as String;
                      },
                      onChanged: (val) => setState(() => _selectedTeam = val),
                    );
                  },
                ),
                const SizedBox(height: 16),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: widget.companyId
                      .collection('member')
                      .orderBy('name')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const SizedBox(
                        height: 60,
                        child: Center(child: Text('Error loading contacts')),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const SizedBox(
                        height: 60,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final docs = snapshot.data!.docs;
                    final items = docs.map((d) => d.reference).toList();
                    return SearchAddSelectDropdown<
                        DocumentReference<Map<String, dynamic>>>(
                      label: 'PO Contact',
                      items: items,
                      initialValue: _selectedPoContact,
                      itemLabel: (ref) {
                        final d = docs.firstWhere((doc) => doc.reference == ref);
                        return (d.data()['name'] ?? ref.id) as String;
                      },
                      onChanged: (val) =>
                          setState(() => _selectedPoContact = val),
                    );
                  },
                ),
                const SizedBox(height: 16),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: widget.companyId
                      .collection('project')
                      .orderBy('name')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const SizedBox(
                        height: 60,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final docs = snapshot.data!.docs;
                    final items = docs.map((d) => d.reference).toList();
                    return SearchAddSelectDropdown<
                        DocumentReference<Map<String, dynamic>>>(
                      label: 'Project',
                      items: items,
                      initialValue: _selectedProject,
                      itemLabel: (ref) {
                        final d = docs.firstWhere((doc) => doc.reference == ref);
                        return (d.data()['name'] ?? 'Unnamed Project') as String;
                      },
                      onChanged: (val) => setState(() => _selectedProject = val),
                    );
                  },
                ),
                const SizedBox(height: 16),
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: widget.companyId.snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const SizedBox(
                        height: 60,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final data = snap.data!.data() ?? {};
                    final locations =
                        List<Map<String, dynamic>>.from(data['locations'] ?? []);
                    if (locations.isEmpty) {
                      return const Text('No ship to locations found');
                    }
                    return SearchAddSelectDropdown<Map<String, dynamic>>(
                      label: 'Ship To Address',
                      items: locations,
                      initialValue: _shipToAddress,
                      itemLabel: (m) {
                        final parts = [
                          m['address'],
                          m['city'],
                          m['state'],
                          m['zip']
                        ]
                            .whereType<String>()
                            .where((e) => e.isNotEmpty)
                            .join(', ');
                        return parts;
                      },
                      onChanged: (val) => setState(() => _shipToAddress = val),
                    );
                  },
                ),
                const SizedBox(height: 16),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: widget.companyId
                      .collection('companyCompany')
                      .orderBy('name')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const SizedBox(
                        height: 60,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final docs = snapshot.data!.docs;
                    final items = docs.map((d) => d.reference).toList();
                    return SearchAddSelectDropdown<
                        DocumentReference<Map<String, dynamic>>>(
                      label: 'Vendor',
                      items: items,
                      initialValue: _selectedVendor,
                      itemLabel: (ref) {
                        final d = docs.firstWhere((doc) => doc.reference == ref);
                        return (d.data()['name'] ?? 'Unnamed Vendor') as String;
                      },
                      onChanged: (val) => setState(() {
                        _selectedVendor = val;
                        _selectedVendorContact = null;
                        _billingAddress = null;
                      }),
                    );
                  },
                ),
                if (_selectedVendor != null) ...[
                  const SizedBox(height: 16),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: widget.companyId
                        .collection('contact')
                        .where('companyCompanyId', isEqualTo: _selectedVendor)
                        .orderBy('name')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const SizedBox(
                          height: 60,
                          child: Center(child: Text('Error loading contacts')),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const SizedBox(
                          height: 60,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final docs = snapshot.data!.docs;
                      final items = docs.map((d) => d.reference).toList();
                      return SearchAddSelectDropdown<
                          DocumentReference<Map<String, dynamic>>>(
                        label: 'Vendor Contact',
                        items: items,
                        initialValue: _selectedVendorContact,
                        itemLabel: (ref) {
                          final d =
                              docs.firstWhere((doc) => doc.reference == ref);
                          return (d.data()['name'] ?? ref.id) as String;
                        },
                        onChanged: (val) =>
                            setState(() => _selectedVendorContact = val),
                      );
                    },
                  ),
                ],
                if (_selectedVendor != null) ...[
                  const SizedBox(height: 16),
                  StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: _selectedVendor!.snapshots(),
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const SizedBox(
                          height: 60,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final data = snap.data!.data() ?? {};
                      final locations = List<Map<String, dynamic>>.from(
                          data['billingLocations'] ?? []);
                      if (locations.isEmpty) {
                        return const Text('No addresses found for vendor');
                      }
                      return SearchAddSelectDropdown<Map<String, dynamic>>(
                        label: 'Billing Address',
                        items: locations,
                        initialValue: _billingAddress,
                        itemLabel: (m) {
                          final parts = [
                            m['address'],
                            m['city'],
                            m['state'],
                            m['zip']
                          ]
                              .whereType<String>()
                              .where((e) => e.isNotEmpty)
                              .join(', ');
                          return parts;
                        },
                        onChanged: (val) => setState(() => _billingAddress = val),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      bottomNavigationBar: CancelSaveBar(
        onCancel: () => context.pop(),
        onSave: _saving ? null : _saveForm,
        isSaving: _saving,
      ),
    );
  }
}


