import 'package:flutter/material.dart';

import '../../../stores/overview_store.dart';
import '../customer_metrics_content.dart';

class CustomerMetricsMobileView extends StatelessWidget {
  const CustomerMetricsMobileView({
    super.key,
    required this.snapshot,
    required this.includeWalkIns,
    required this.onIncludeWalkInsChanged,
  });

  final OverviewSnapshot snapshot;
  final bool includeWalkIns;
  final ValueChanged<bool> onIncludeWalkInsChanged;

  @override
  Widget build(BuildContext context) => CustomerMetricsContent(
    snapshot: snapshot,
    compact: true,
    includeWalkIns: includeWalkIns,
    onIncludeWalkInsChanged: onIncludeWalkInsChanged,
  );
}
