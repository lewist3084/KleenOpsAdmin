// lib/widgets/fields/counter_field.dart

import 'package:flutter/material.dart';
import 'package:shared_widgets/info_icon_visibility_scope.dart';
import 'package:kleenops_admin/widgets/dialogs/field_info_dialog.dart';
import 'package:kleenops_admin/l10n/localized_text_resolver.dart';

/// A simple counter widget with plus and minus buttons that allows the user
/// to adjust an integer value. It calls [onChanged] when the value changes.
/// Now also takes a [label] which is rendered inline to the left of the counter,
/// and uses the app’s primaryColor for the ± icons.
class CounterField extends StatefulWidget {
  /// Text to show to the left of the counter controls.
  final String? label;
  final LocalizedStringResolver? labelResolver;
  final String? infoKey;

  /// The counter’s starting value.
  final double initialValue;

  /// Called whenever the counter changes.
  final ValueChanged<double> onChanged;

  /// Optional callback fired when the info icon is tapped.
  final VoidCallback? onInfoPressed;

  const CounterField({
    super.key,
    this.label,
    this.labelResolver,
    this.infoKey,
    required this.initialValue,
    required this.onChanged,
    this.onInfoPressed,
  }) : assert(
          label != null || labelResolver != null,
          'Provide either a label string or a labelResolver.',
        );

  @override
  State<CounterField> createState() => _CounterFieldState();
}

class _CounterFieldState extends State<CounterField> {
  late double currentValue;
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    currentValue = widget.initialValue;
    _controller.text = currentValue.toString();
  }

  @override
  void didUpdateWidget(covariant CounterField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue) {
      currentValue = widget.initialValue;
      _controller.text = currentValue.toString();
    }
  }

  void _handleValueChanged(double newValue) {
    if (newValue < 0) return; // Enforce non-negative values.
    setState(() {
      currentValue = newValue;
      _controller.text = newValue.toString();
    });
    widget.onChanged(newValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use the theme’s primary color for the icons
    final primaryColor = Theme.of(context).primaryColor;

    // Match HeaderInfoIconValue header style
    final labelStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.normal,
        );
    final infoIconColor = primaryColor;
    final baseIcon = Icon(Icons.info, size: 16, color: infoIconColor);
    VoidCallback? infoHandler = widget.onInfoPressed;
    if (infoHandler == null && widget.infoKey != null) {
      infoHandler = () => FieldInfoDialog.show(
            context,
            infoKey: widget.infoKey!,
          );
    }
    if (!InfoIconVisibilityScope.shouldShow(context)) {
      infoHandler = null;
    }
    final labelText = resolveLocalizedText(
      context,
      text: widget.label,
      resolver: widget.labelResolver,
    );
    final spans = <InlineSpan>[
      TextSpan(text: labelText),
    ];
    if (infoHandler != null) {
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.only(left: 6),
            child: GestureDetector(
              onTap: infoHandler,
              behavior: HitTestBehavior.opaque,
              child: baseIcon,
            ),
          ),
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Styled label that wraps when space is limited.
        Expanded(
          child: Text.rich(
            TextSpan(
              style: labelStyle,
              children: spans,
            ),
            softWrap: true,
          ),
        ),
        const SizedBox(width: 12),
        // Decrement button
        IconButton(
          icon: const Icon(Icons.remove),
          color: primaryColor,
          onPressed: () {
            FocusScope.of(context).unfocus();
            _handleValueChanged(currentValue - 1.0);
          },
        ),
        // Value input
        SizedBox(
          width: 80,
          height: 36,
          child: TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            onChanged: (val) {
              final parsed = double.tryParse(val);
              if (parsed != null) {
                setState(() {
                  currentValue = parsed;
                });
                widget.onChanged(parsed);
              }
            },
            onSubmitted: (val) {
              final parsed = double.tryParse(val);
              if (parsed != null) {
                _handleValueChanged(parsed);
              }
            },
            decoration: const InputDecoration(
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        // Increment button
        IconButton(
          icon: const Icon(Icons.add),
          color: primaryColor,
          onPressed: () {
            FocusScope.of(context).unfocus();
            _handleValueChanged(currentValue + 1.0);
          },
        ),
      ],
    );
  }
}


