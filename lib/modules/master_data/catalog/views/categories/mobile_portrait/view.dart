import 'package:flutter/material.dart';

import '../../../../shared/widgets/master_data_screen_coordinator.dart';
import '../../../../stores/master_data_read_stores.dart';
import '../categories_content.dart';

class CategoriesMobileView extends StatelessWidget {
  const CategoriesMobileView({super.key, required this.presentation});

  final MasterDataScreenPresentation<CategoryListRecord> presentation;

  @override
  Widget build(BuildContext context) => CategoriesContent(
    presentation: presentation,
    crossAxisCount: 2,
    childAspectRatio: 1.65,
  );
}
