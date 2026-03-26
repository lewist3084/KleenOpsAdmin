// widgets/tiles/account_item.dart

import 'package:flutter/material.dart';

class AccountItem extends StatefulWidget {
  final IconData? leadingicon;
  final VoidCallback? leadingiconAction;
  final String text;
  final String? secondText;
  final IconData? secondTextIcon;
  final Color? leadingiconColor;
  final double? textSize;
  final Color? textColor;
  final EdgeInsets? leadingPadding;
  final IconData? trailingIcon1;
  final VoidCallback? trailingAction1;
  final IconData? trailingIcon2;
  final VoidCallback? trailingAction2;
  final EdgeInsets? trailingPadding;
  final String? twoDigitText;
  final bool hasChildren;
  final List<Widget> children;
  final bool initiallyExpanded;

  const AccountItem({
    super.key,
    this.leadingicon,
    this.leadingiconAction,
    required this.text,
    this.secondText,
    this.secondTextIcon,
    this.leadingiconColor,
    this.textSize,
    this.textColor,
    this.leadingPadding,
    this.trailingIcon1,
    this.trailingAction1,
    this.trailingIcon2,
    this.trailingAction2,
    this.trailingPadding,
    this.twoDigitText,
    this.hasChildren = false,
    this.children = const [],
    this.initiallyExpanded = false,
  });

  @override
  State<AccountItem> createState() => _AccountItemState();
}

class _AccountItemState extends State<AccountItem> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  void didUpdateWidget(AccountItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_expanded == oldWidget.initiallyExpanded &&
        widget.initiallyExpanded != oldWidget.initiallyExpanded) {
      _expanded = widget.initiallyExpanded;
    }
  }

  @override
  Widget build(BuildContext context) {
    const double spacing = 8.0;
    final tile = ListTile(
      leading: SizedBox(
        width: 22.0,
        child: Center(
          child: widget.leadingicon != null
              ? IconButton(
                  icon: Icon(
                    widget.leadingicon,
                    size: 18.0,
                    color:
                        widget.leadingiconColor ?? Theme.of(context).primaryColor,
                  ),
                  onPressed: widget.leadingiconAction,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )
              : widget.twoDigitText != null
                  ? GestureDetector(
                      onTap: widget.leadingiconAction,
                      child: CircleAvatar(
                        backgroundColor:
                            widget.leadingiconColor?.withOpacity(0.2) ??
                                Theme.of(context).primaryColor.withOpacity(0.2),
                        radius: 13.0,
                        child: Text(
                          widget.twoDigitText!,
                          style: TextStyle(
                            fontSize: 12.0,
                            fontWeight: FontWeight.bold,
                            color: widget.textColor ??
                                Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                    )
                  : null,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              widget.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: widget.textSize ?? 14.0,
                color: widget.textColor ?? Colors.black,
              ),
            ),
          ),
          if (widget.secondTextIcon != null) ...[
            const SizedBox(width: spacing),
            Icon(
              widget.secondTextIcon,
              size: 16.0,
              color: Theme.of(context).primaryColor,
            ),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.trailingIcon1 != null)
            Padding(
              padding: widget.trailingPadding ?? EdgeInsets.zero,
              child: IconButton(
                icon: Icon(
                  widget.trailingIcon1,
                  size: 20.0,
                  color: widget.leadingiconColor ??
                      Theme.of(context).primaryColor,
                ),
                onPressed: widget.trailingAction1,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
          if (widget.trailingIcon2 != null && widget.trailingAction2 != null)
            Padding(
              padding: widget.trailingPadding ?? EdgeInsets.zero,
              child: IconButton(
                icon: Icon(
                  widget.trailingIcon2,
                  size: 20.0,
                  color: widget.leadingiconColor ??
                      Theme.of(context).primaryColor,
                ),
                onPressed: widget.trailingAction2,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
          if (widget.hasChildren)
            IconButton(
              icon: Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                size: 20.0,
                color: widget.leadingiconColor ??
                    Theme.of(context).primaryColor,
              ),
              onPressed: () => setState(() => _expanded = !_expanded),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          if (widget.secondText != null) ...[
            Padding(
              padding: const EdgeInsets.only(left: spacing),
              child: Text(
                widget.secondText!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: widget.textSize ?? 14.0,
                  color: widget.textColor ?? Colors.black,
                ),
              ),
            ),
          ],
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 0.0),
      tileColor: Colors.white,
      visualDensity: VisualDensity.compact,
    );

    if (!widget.hasChildren || widget.children.isEmpty) {
      return tile;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        tile,
        if (_expanded) ...widget.children,
      ],
    );
  }
}
