//  time_picker_field.dart

import 'package:flutter/material.dart';

class TimePickerField extends StatelessWidget {
  final TimeOfDay? selectedTime;
  final ValueChanged<TimeOfDay?> onTimePicked;

  const TimePickerField({
    super.key,
    this.selectedTime,
    required this.onTimePicked,
  });

  @override
  Widget build(BuildContext context) {
    final displayText =
        selectedTime == null ? 'Select Time' : selectedTime!.format(context);

    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: selectedTime ?? TimeOfDay.now(),
        );
        if (picked != null) {
          onTimePicked(picked);
        }
      },
      child: InputDecorator(
        decoration: const InputDecoration(labelText: 'Time'),
        child: Text(displayText),
      ),
    );
  }
}
