import 'package:flutter/material.dart';

import '../widgets/platform_catalog_body.dart';

/// The Sales → Products tab. In the overlord app this IS the platform-product
/// catalog (the products KleenOps sells to companies), so it renders the
/// shared [PlatformCatalogBody] (also used by Billing → Platform Products).
class SalesProductContent extends StatelessWidget {
  const SalesProductContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlatformCatalogBody();
  }
}
