import 'package:flutter/material.dart';

import '../../../shared/widgets/master_data_screen_coordinator.dart';
import '../../../stores/master_data_read_stores.dart';
import 'mobile_portrait/view.dart';
import 'tablet_landscape/view.dart';

/// Coordinator dan device router untuk daftar brand.
class BrandsView extends StatelessWidget {
  const BrandsView({super.key});

  @override
  Widget build(BuildContext context) {
    final store = BrandListStore.instance;
    return MasterDataScreenCoordinator<BrandListRecord>(
      snapshotListenable: store.snapshotNotifier,
      onRefresh: store.refresh,
      onSearchChanged: store.setSearchQuery,
      mobileBuilder: (_, presentation) =>
          BrandsMobileView(presentation: presentation),
      tabletBuilder: (_, presentation) =>
          BrandsTabletLandscapeView(presentation: presentation),
    );
  }
}
