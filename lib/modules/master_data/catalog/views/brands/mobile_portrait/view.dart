import 'package:flutter/material.dart';

import '../../../../shared/widgets/master_data_screen_coordinator.dart';
import '../../../../stores/master_data_read_stores.dart';
import '../brands_content.dart';

/// Mobile presentation untuk daftar brand.
class BrandsMobileView extends StatelessWidget {
  const BrandsMobileView({super.key, required this.presentation});

  final MasterDataScreenPresentation<BrandListRecord> presentation;

  @override
  Widget build(BuildContext context) => BrandsContent(
    presentation: presentation,
    crossAxisCount: 2,
    childAspectRatio: 1.65,
  );
}
