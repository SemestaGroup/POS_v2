import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/responsive/responsive_context.dart';
import '../../../sales/orders/shared/orders_history_sync_service.dart';
import '../../stores/report_read_stores.dart';
import 'mobile_portrait/view.dart';
import 'tablet_landscape/view.dart';

class ReportSummaryView extends StatelessWidget {
  const ReportSummaryView({super.key});

  @override
  Widget build(BuildContext context) => context.isMobile
      ? const _ReportSummaryMobileContainer()
      : const ReportSummaryTabletLandscapeView();
}

class _ReportSummaryMobileContainer extends StatefulWidget {
  const _ReportSummaryMobileContainer();

  @override
  State<_ReportSummaryMobileContainer> createState() =>
      _ReportSummaryMobileContainerState();
}

class _ReportSummaryMobileContainerState
    extends State<_ReportSummaryMobileContainer> {
  final _store = ReportSummaryStore.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_syncHistoryAndRefresh());
    });
  }

  Future<void> _syncHistoryAndRefresh() async {
    await OrdersHistorySyncService.instance.ensureSynced();
    if (mounted) {
      await _store.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final currencyFmt = NumberFormat(
      '#,###',
      Localizations.localeOf(context).toString(),
    );
    return ValueListenableBuilder<ReportSummarySnapshot>(
      valueListenable: _store.snapshotNotifier,
      builder: (context, snapshot, _) {
        if (snapshot.isLoading && snapshot.topProducts.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.errorMessage != null && snapshot.topProducts.isEmpty) {
          return Center(
            child: Text(
              snapshot.errorMessage!,
              style: TextStyle(color: Colors.red.shade600),
            ),
          );
        }
        return ReportSummaryMobileView(
          snapshot: snapshot,
          primaryColor: primaryColor,
          currencyFmt: currencyFmt,
          onRefresh: _syncHistoryAndRefresh,
        );
      },
    );
  }
}
