//  customer_dropdown.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerReferenceDropdown extends StatefulWidget {
  final DocumentReference? selectedCustomer;
  final ValueChanged<DocumentReference?> onChanged;

  const CustomerReferenceDropdown({
    super.key,
    required this.selectedCustomer,
    required this.onChanged,
  });

  @override
  State<CustomerReferenceDropdown> createState() =>
      _CustomerReferenceDropdownState();
}

class _CustomerReferenceDropdownState extends State<CustomerReferenceDropdown> {
  bool _loading = true;
  List<DocumentSnapshot> _customerDocs = [];

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    try {
      final query =
          await FirebaseFirestore.instance.collection('customer').get();
      _customerDocs = query.docs;
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: LinearProgressIndicator(),
      );
    }

    if (_customerDocs.isEmpty) {
      return const Text('No customers found');
    }

    return DropdownButtonFormField<DocumentReference>(
      initialValue: widget.selectedCustomer,
      decoration: const InputDecoration(labelText: 'Customer'),
      items: _customerDocs.map((snap) {
        final data = snap.data() as Map<String, dynamic>?;
        final displayValue = (data != null && data.containsKey('nameAbbreviation'))
            ? data['nameAbbreviation']
            : snap.id;
        return DropdownMenuItem(
          value: snap.reference,
          child: Text(displayValue),
        );
      }).toList(),
      onChanged: widget.onChanged,
      validator: (val) => null,
    );
  }
}
