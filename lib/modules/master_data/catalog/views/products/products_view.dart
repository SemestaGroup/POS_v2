import 'package:flutter/material.dart';

import '../../../../../core/widgets/responsive/responsive_context.dart';
import 'mobile_portrait/view.dart';
import 'tablet_landscape/view.dart';

class ProductsView extends StatelessWidget {
  const ProductsView({super.key});

  @override
  Widget build(BuildContext context) => context.isMobile
      ? const ProductsMobileView()
      : const ProductsTabletLandscapeView();
}
