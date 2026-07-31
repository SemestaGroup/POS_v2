import 'package:flutter/material.dart';

import '../../../../shared/widgets/master_data_screen_coordinator.dart';
import '../../../../stores/master_data_read_stores.dart';
import '../categories_content.dart';

class CategoriesTabletLandscapeView extends StatelessWidget {
  const CategoriesTabletLandscapeView({super.key, required this.presentation});

  final MasterDataScreenPresentation<CategoryListRecord> presentation;

  @override
  Widget build(BuildContext context) => CategoriesContent(
    presentation: presentation,
    crossAxisCount: 4,
    childAspectRatio: 1.45,
  );
}
