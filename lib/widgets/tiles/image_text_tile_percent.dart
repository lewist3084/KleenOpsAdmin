//  image_text_tile_percent.dart

import 'package:flutter/material.dart';

/// Controls the vertical padding inside the percentage text field.
const double kPercentFieldVerticalPadding = 4.0;

class ImageTextTilePercent extends StatefulWidget {
  final String imageUrl;
  final String title;
  final String subTitle;
  final IconData? subTitleIcon;
  final int initialPercentage;
  final ValueChanged<int>? onPercentageChanged;
  final bool? checkboxValue;
  final ValueChanged<bool?>? onCheckboxChanged;
  final VoidCallback? onImageTap;
  final BoxFit fit;
  final int minValue;
  final int? maxValue;
  final int step;
  final String suffixText;

  const ImageTextTilePercent({
    super.key,
    required this.imageUrl,
    required this.title,
    this.subTitle = 'Usage',
    this.subTitleIcon,
    this.initialPercentage = 1,
    this.onPercentageChanged,
    this.checkboxValue,
    this.onCheckboxChanged,
    this.onImageTap,
    this.fit = BoxFit.cover,
    this.minValue = 1,
    this.maxValue = 100,
    this.step = 5,
    this.suffixText = '%',
  });

  @override
  _ImageTextTilePercentState createState() => _ImageTextTilePercentState();
}

class _ImageTextTilePercentState extends State<ImageTextTilePercent> {
  late int _percentage;
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _percentage = _clampValue(widget.initialPercentage);
    _controller.text = _percentage.toString();
  }

  @override
  void didUpdateWidget(covariant ImageTextTilePercent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPercentage != oldWidget.initialPercentage) {
      _percentage = _clampValue(widget.initialPercentage);
      _controller.text = _percentage.toString();
    }
  }

  int _clampValue(int value) {
    if (value < widget.minValue) return widget.minValue;
    if (widget.maxValue != null && value > widget.maxValue!)
      return widget.maxValue!;
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
                // Title row.
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // Subtitle row with optional icon.
                Row(
                  children: [
                    if (widget.subTitleIcon != null)
                      Icon(widget.subTitleIcon, color: primaryColor, size: 15),
                    if (widget.subTitleIcon != null) const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.subTitle,
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                // Row with minus button, percentage text field, and plus button.
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove, color: primaryColor),
                        onPressed: () =>
                            _updatePercentage(_percentage - widget.step),
                      ),
                      SizedBox(
                        width: 60,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _controller,
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: kPercentFieldVerticalPadding,
                                    horizontal: 4,
                                  ),
                                  isDense: true,
                                  border: OutlineInputBorder(),
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
                            if (widget.suffixText.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(left: 2),
                                child: Text(
                                  widget.suffixText,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(fontSize: 14),
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.add, color: primaryColor),
                        onPressed: () =>
                            _updatePercentage(_percentage + widget.step),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    if (widget.onCheckboxChanged != null && widget.checkboxValue != null) {
      tile = Stack(
        clipBehavior: Clip.none,
        children: [
          tile,
          Positioned(
            top: 0,
            bottom: 0,
            right: -4,
            child: Center(
              child: GestureDetector(
                onTap: () => widget.onCheckboxChanged!(!widget.checkboxValue!),
                child: Icon(
                  widget.checkboxValue!
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  color: widget.checkboxValue! ? primaryColor : Colors.black,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return tile;
  }
}
