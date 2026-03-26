//  purchase_order_item_tile.dart

import 'package:flutter/material.dart';

/// Controls the vertical padding inside the percentage text field.
const double kPercentFieldVerticalPadding = 4.0;

class PurchaseOrderItemTile extends StatefulWidget {
  final String imageUrl;
  final String title;
  final double currentPrice;
  final String subTitle;
  final IconData? subTitleIcon;
  final int initialPercentage;
  final ValueChanged<int>? onPercentageChanged;
  final bool? checkboxValue;
  final ValueChanged<bool?>? onCheckboxChanged;
  final VoidCallback? onImageTap;
  final VoidCallback? onTap;
  final BoxFit fit;
  final int minValue;
  final int? maxValue;
  final int step;
  final String suffixText;
  final IconData? titleIcon;
  final String? secondaryText;
  final IconData? secondaryIcon;
  final bool showPriceRow;
  final bool showTotalPrice;

  const PurchaseOrderItemTile({
    super.key,
    required this.imageUrl,
    required this.title,
    this.currentPrice = 0.0,
    this.subTitle = 'Usage',
    this.subTitleIcon,
    this.initialPercentage = 1,
    this.onPercentageChanged,
    this.checkboxValue,
    this.onCheckboxChanged,
    this.onImageTap,
    this.onTap,
    this.fit = BoxFit.cover,
    this.minValue = 1,
    this.maxValue = 100,
    this.step = 5,
    this.suffixText = '%',
    this.titleIcon = Icons.category_outlined,
    this.secondaryText,
    this.secondaryIcon,
    this.showPriceRow = true,
    this.showTotalPrice = true,
  });

  @override
  _PurchaseOrderItemState createState() => _PurchaseOrderItemState();
}

class _PurchaseOrderItemState extends State<PurchaseOrderItemTile> {
  late int _percentage;
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _percentage = _clampValue(widget.initialPercentage);
    _controller.text = _percentage.toString();
  }

  @override
  void didUpdateWidget(covariant PurchaseOrderItemTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPercentage != oldWidget.initialPercentage) {
      _percentage = _clampValue(widget.initialPercentage);
      _controller.text = _percentage.toString();
    }
  }

  int _clampValue(int value) {
    if (value < widget.minValue) return widget.minValue;
    if (widget.maxValue != null && value > widget.maxValue!) return widget.maxValue!;
    return value;
  }

  void _updatePercentage(int newPercentage) {
    setState(() {
      _percentage = _clampValue(newPercentage);
      _controller.text = _percentage.toString();
    });
    if (widget.onPercentageChanged != null) {
      widget.onPercentageChanged!(_percentage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final hasSecondaryText =
        widget.secondaryText != null &&
        widget.secondaryText!.trim().isNotEmpty;
    Widget tile = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left image container (if imageUrl is provided).
        if (widget.imageUrl.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: GestureDetector(
              onTap: widget.onImageTap,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8.0),
                    image: DecorationImage(
                      image: NetworkImage(widget.imageUrl),
                      fit: widget.fit,
                    ),
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(width: 8),
        // Right text and percentage control area.
        Expanded(
          child: SizedBox(
            height: 80, // Matches the image height.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row with optional category icon.
                Row(
                  children: [
                    if (widget.titleIcon != null) ...[
                      Icon(widget.titleIcon, color: primaryColor, size: 15),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(
                        widget.title,
                        style: Theme.of(context).textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (hasSecondaryText)
                  // Secondary text row (e.g., location).
                  Row(
                    children: [
                      if (widget.secondaryIcon != null) ...[
                        Icon(
                          widget.secondaryIcon,
                          color: Colors.grey.shade600,
                          size: 15,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          widget.secondaryText!,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey.shade600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                if (widget.showPriceRow)
                  // Current price row with dollar icon.
                  Row(
                    children: [
                      Icon(Icons.attach_money, color: primaryColor, size: 15),
                      const SizedBox(width: 4),
                      Text(
                        widget.currentPrice.toStringAsFixed(2),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                // Row with minus button, quantity field, plus button and total.
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove, color: primaryColor),
                        onPressed: () => _updatePercentage(_percentage - widget.step),
                      ),
                      SizedBox(
                        width: 60,
                        child: TextFormField(
                          controller: _controller,
                          decoration: InputDecoration(
                            suffixText: widget.suffixText,
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: kPercentFieldVerticalPadding,
                                horizontal: 8),
                            isDense: true,
                            border: const OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          onChanged: (value) {
                            final parsed = int.tryParse(value);
                            if (parsed != null && parsed != _percentage) {
                              _updatePercentage(parsed);
                            }
                          },
                          onFieldSubmitted: (value) {
                            final parsed = int.tryParse(value);
                            if (parsed != null) {
                              _updatePercentage(parsed);
                            }
                          },
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.add, color: primaryColor),
                        onPressed: () => _updatePercentage(_percentage + widget.step),
                      ),
                      if (widget.showTotalPrice) ...[
                        const Spacer(),
                        Text(
                          '\$${(_percentage * widget.currentPrice).toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    Widget content = tile;

    if (widget.onCheckboxChanged != null && widget.checkboxValue != null) {
      content = Stack(
        clipBehavior: Clip.none,
        children: [
          tile,
          Positioned(
            top: 0,
            bottom: 0,
            right: -4,
            child: Center(
              child: GestureDetector(
                onTap: () =>
                    widget.onCheckboxChanged!(!widget.checkboxValue!),
                child: Icon(
                  widget.checkboxValue!
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  color:
                      widget.checkboxValue! ? primaryColor : Colors.black,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return InkWell(
      onTap: widget.onTap,
      child: content,
    );
  }
}

