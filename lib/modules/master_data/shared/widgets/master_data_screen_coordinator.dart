import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/widgets/responsive/responsive_context.dart';
import '../../stores/master_data_read_stores.dart';

/// Data dan callback bersama yang diteruskan coordinator ke presentation view.
class MasterDataScreenPresentation<T> {
  const MasterDataScreenPresentation({
    required this.snapshot,
    required this.searchController,
    required this.onSearchChanged,
    required this.onRefresh,
    required this.rebuild,
  });

  final MasterDataListSnapshot<T> snapshot;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onRefresh;
  final VoidCallback rebuild;
}

typedef MasterDataPresentationBuilder<T> =
    Widget Function(
      BuildContext context,
      MasterDataScreenPresentation<T> presentation,
    );

/// Owns shared state and selects a pure device presentation view.
class MasterDataScreenCoordinator<T> extends StatefulWidget {
  const MasterDataScreenCoordinator({
    super.key,
    required this.snapshotListenable,
    required this.onRefresh,
    required this.onSearchChanged,
    required this.mobileBuilder,
    required this.tabletBuilder,
  });

  final ValueListenable<MasterDataListSnapshot<T>> snapshotListenable;
  final VoidCallback onRefresh;
  final ValueChanged<String> onSearchChanged;
  final MasterDataPresentationBuilder<T> mobileBuilder;
  final MasterDataPresentationBuilder<T> tabletBuilder;

  @override
  State<MasterDataScreenCoordinator<T>> createState() =>
      _MasterDataScreenCoordinatorState<T>();
}

class _MasterDataScreenCoordinatorState<T>
    extends State<MasterDataScreenCoordinator<T>> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onRefresh());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MasterDataListSnapshot<T>>(
      valueListenable: widget.snapshotListenable,
      builder: (context, snapshot, _) {
        final presentation = MasterDataScreenPresentation<T>(
          snapshot: snapshot,
          searchController: _searchController,
          onSearchChanged: widget.onSearchChanged,
          onRefresh: widget.onRefresh,
          rebuild: () => setState(() {}),
        );
        return context.isMobile
            ? widget.mobileBuilder(context, presentation)
            : widget.tabletBuilder(context, presentation);
      },
    );
  }
}
