// widgets/tiles/ledger_item.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class LedgerItem extends StatelessWidget {
  final IconData? leadingIcon;
  final VoidCallback? leadingIconAction;
  final DocumentReference<Map<String, dynamic>>? companyObjectId;
  final String? memo;
  final Color? leadingIconColor;
  final double? textSize;
  final Color? textColor;
  final EdgeInsets? leadingPadding;
  final IconData? trailingIcon1;
  final VoidCallback? trailingAction1;
  final IconData? trailingIcon2;
  final VoidCallback? trailingAction2;
  final EdgeInsets? trailingPadding;
  final String? twoDigitText;

  const LedgerItem({
    super.key,
    this.leadingIcon,
    this.leadingIconAction,
    this.companyObjectId,
    this.memo,
    this.leadingIconColor,
    this.textSize,
    this.textColor,
    this.leadingPadding,
    this.trailingIcon1,
    this.trailingAction1,
    this.trailingIcon2,
    this.trailingAction2,
    this.trailingPadding,
    this.twoDigitText,
  });

  @override
  Widget build(BuildContext context) {
    const double spacing = 8.0;

    Widget buildFirstRow(String localName) {
      return Row(
        children: [
          Expanded(
            child: Text(
              localName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: textSize ?? 14.0,
                color: textColor ?? Colors.black,
              ),
            ),
          ),
        ],
      );
    }

    final titleWidget = FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: companyObjectId?.get(),
      builder: (context, snapshot) {
        String localName = '';
        if (snapshot.hasData && snapshot.data!.exists) {
          localName = snapshot.data!.data()?['localName']?.toString() ?? '';
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildFirstRow(localName),
            if (memo != null)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      memo!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: textSize ?? 14.0,
                        color: textColor ?? Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        );
      },
    );

    return ListTile(
      leading: SizedBox(
        width: 22.0,
        child: Center(
          child: leadingIcon != null
              ? IconButton(
                  icon: Icon(
                    leadingIcon,
                    size: 18.0,
                    color: leadingIconColor ?? Theme.of(context).primaryColor,
                  ),
                  onPressed: leadingIconAction,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )
              : twoDigitText != null
                  ? GestureDetector(
                      onTap: leadingIconAction,
                      child: CircleAvatar(
                        backgroundColor: leadingIconColor?.withOpacity(0.2) ??
                            Theme.of(context).primaryColor.withOpacity(0.2),
                        radius: 13.0,
                        child: Text(
                          twoDigitText!,
                          style: TextStyle(
                            fontSize: 12.0,
                            fontWeight: FontWeight.bold,
                            color: textColor ?? Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                    )
                  : null,
        ),
      ),
      title: titleWidget,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingIcon1 != null)
            Padding(
              padding: trailingPadding ?? EdgeInsets.zero,
              child: IconButton(
                icon: Icon(
                  trailingIcon1,
                  size: 20.0,
                  color: leadingIconColor ?? Theme.of(context).primaryColor,
                ),
                onPressed: trailingAction1,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
          if (trailingIcon2 != null && trailingAction2 != null)
            Padding(
              padding: trailingPadding ?? EdgeInsets.zero,
              child: IconButton(
                icon: Icon(
                  trailingIcon2,
                  size: 20.0,
                  color: leadingIconColor ?? Theme.of(context).primaryColor,
                ),
                onPressed: trailingAction2,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 0.0),
      tileColor: Colors.white,
      visualDensity: VisualDensity.compact,
    );
  }
}
