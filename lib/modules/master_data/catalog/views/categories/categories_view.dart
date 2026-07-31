import 'package:flutter/material.dart';

import '../../../shared/widgets/master_data_screen_coordinator.dart';
import '../../../stores/master_data_read_stores.dart';
import 'mobile_portrait/view.dart';
import 'tablet_landscape/view.dart';

/// Coordinator dan device router untuk daftar kategori.
class CategoriesView extends StatelessWidget {
  const CategoriesView({super.key});

  @override
  Widget build(BuildContext context) {
    final store = CategoryListStore.instance;
    return MasterDataScreenCoordinator<CategoryListRecord>(
      snapshotListenable: store.snapshotNotifier,
      onRefresh: store.refresh,
      onSearchChanged: store.setSearchQuery,
      mobileBuilder: (_, presentation) =>
          CategoriesMobileView(presentation: presentation),
      tabletBuilder: (_, presentation) =>
          CategoriesTabletLandscapeView(presentation: presentation),
    );
  }
}
