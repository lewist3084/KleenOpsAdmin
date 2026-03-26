// lib/widgets/fields/multi_scan_field.dart
// Stub — admin app does not use barcode/NFC/BLE scanning.

import 'package:flutter/material.dart';

/// A TextFormField stub. The real widget in kleenops supports barcode, NFC
/// and BLE scanning; the admin app only needs the text field portion.
class MultiScanField extends StatelessWidget {
  final String labelText;
  final FormFieldSetter<String>? onSaved;
  final FormFieldValidator<String>? validator;
  final String? initialValue;

  const MultiScanField({
    super.key,
    required this.labelText,
    this.onSaved,
    this.validator,
    this.initialValue,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initialValue,
      decoration: InputDecoration(
        labelText: labelText,
        border: const OutlineInputBorder(),
      ),
      onSaved: onSaved,
      validator: validator,
    );
  }
}
