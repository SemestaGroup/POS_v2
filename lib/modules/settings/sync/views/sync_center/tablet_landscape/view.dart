import 'package:flinkpos_v2/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../../controllers/sync_settings_controller.dart';
import '../../../models/sync_settings_state.dart';

class SyncCenterView extends StatefulWidget {
  const SyncCenterView({super.key});

  @override
  State<SyncCenterView> createState() => _SyncCenterViewState();
}

class _SyncCenterViewState extends State<SyncCenterView> {
  final SyncCenterController _controller = SyncCenterController.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.shortestSide < 600;

    return ValueListenableBuilder<SyncCenterState>(
      valueListenable: _controller.stateNotifier,
      builder: (context, state, _) {
        final cards = [
          _card('Pending', '${state.pendingCount}'),
          _card('Failed', '${state.failedCount}'),
          _card('Processed', '${state.processedCount}'),
          _card('Errors', '${state.errorCount}'),
        ];

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context)!.syncCenterTitle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(AppLocalizations.of(context)!.syncCenterDesc, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
              const SizedBox(height: 14),
              isMobile
                  ? GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 2.3,
                      children: cards,
                    )
                  : Row(
                      children: [
                        Expanded(child: cards[0]),
                        const SizedBox(width: 10),
                        Expanded(child: cards[1]),
                        const SizedBox(width: 10),
                        Expanded(child: cards[2]),
                        const SizedBox(width: 10),
                        Expanded(child: cards[3]),
                      ],
                    ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: isMobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildStatusInfo(context, state),
                          const SizedBox(height: 16),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          _buildActionButtons(context, state),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: _buildStatusInfo(context, state)),
                          const SizedBox(width: 12),
                          _buildActionButtons(context, state),
                        ],
                      ),
              ),
              if (state.errorMessage != null) ...[
                const SizedBox(height: 10),
                Text(state.errorMessage!, style: TextStyle(fontSize: 11, color: Colors.red.shade600)),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusInfo(BuildContext context, SyncCenterState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppLocalizations.of(context)!.syncCurrentStatus, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(AppLocalizations.of(context)!.syncStage(state.status.stage), style: const TextStyle(fontSize: 11, color: Color(0xFF4B5563))),
        const SizedBox(height: 2),
        Text(AppLocalizations.of(context)!.syncBlocking(state.status.isBlocking ? AppLocalizations.of(context)!.yes : AppLocalizations.of(context)!.no), style: const TextStyle(fontSize: 11, color: Color(0xFF4B5563))),
        const SizedBox(height: 2),
        Text(AppLocalizations.of(context)!.syncProgress(state.status.progress != null ? (state.status.progress! * 100).toInt() : 0), style: const TextStyle(fontSize: 11, color: Color(0xFF4B5563))),
        if (state.status.errorMessage != null) ...[
          const SizedBox(height: 4),
          Text(state.status.errorMessage!, style: TextStyle(fontSize: 11, color: Colors.red.shade600, fontWeight: FontWeight.bold)),
        ],
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, SyncCenterState state) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.start,
      children: [
        OutlinedButton(
          onPressed: state.isLoading ? null : _controller.refresh,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(AppLocalizations.of(context)!.refresh, style: const TextStyle(fontSize: 11)),
        ),
        FilledButton.tonal(
          onPressed: state.isLoading ? null : _controller.flushQueue,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(AppLocalizations.of(context)!.syncFlushQueue, style: const TextStyle(fontSize: 11)),
        ),
        FilledButton(
          onPressed: state.isLoading ? null : _controller.refreshBootstrap,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(AppLocalizations.of(context)!.syncRefreshBootstrap, style: const TextStyle(fontSize: 11)),
        ),
      ],
    );
  }

  Widget _card(String label, String value) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
            const SizedBox(height: 3),
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          ],
        ),
      );
}
