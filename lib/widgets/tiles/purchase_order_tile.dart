// widgets/tiles/purchase_order_tile.dart

import 'package:flutter/material.dart';
import 'package:shared_widgets/tiles/standard_tile_large.dart';

/// Compact tile used to display a purchase order record.
///
/// The tile shows the vendor on the first row and the team on the second
/// row. The purchase order number is displayed on the third row while the
/// total cost of the purchase order appears on the bottom right.
class PurchaseOrderTile extends StatelessWidget {
  final IconData icon;
  final String vendorName;
  final String teamName;
  final String poNumber;
  /// Grand total for the purchase order.
  final String purchaseOrderTotal;
  final String imageUrl;
  final bool showImage;
  final BoxFit fit;
  final VoidCallback? onTap;

  const PurchaseOrderTile({
    super.key,
    this.icon = Icons.receipt_long_outlined,
    required this.vendorName,
    required this.teamName,
    required this.poNumber,
    required this.purchaseOrderTotal,
    this.imageUrl = '',
    this.showImage = false,
    this.fit = BoxFit.contain,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: StandardTileLargeDart(
        imageUrl: imageUrl,
        showImage: showImage,
        fit: fit,
        firstLine: vendorName,
        secondLine: teamName,
        thirdLine: poNumber.isNotEmpty ? 'PO# $poNumber' : null,
        thirdLineIcon:
            poNumber.isNotEmpty ? Icons.confirmation_number_outlined : null,
        bottomRightText: purchaseOrderTotal,
        firstLineIcon: icon,
      ),
    );
  }
}


