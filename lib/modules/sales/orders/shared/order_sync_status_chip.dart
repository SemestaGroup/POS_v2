import 'package:flutter/material.dart';

import '../../../../../../l10n/app_localizations.dart';
import '../../../../../../core/services/sync/pos_v2_sync_status_store.dart';

class OrderSyncStatusChip extends StatelessWidget {
  const OrderSyncStatusChip({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ValueListenableBuilder<PosV2SyncStatus>(
      valueListenable: PosV2SyncStatusStore.instance.statusNotifier,
      builder: (context, status, _) {
        final isHistoryStage =
            status.stage == 'history_on_demand' ||
            status.stage == 'history_ready' ||
            (status.errorMessage != null &&
                status.errorMessage!.toLowerCase().contains('history'));
        if (!isHistoryStage && !status.isSyncing) {
          return const SizedBox.shrink();
        }

        final label = status.isSyncing
            ? l10n.syncStatusSyncing
            : status.errorMessage != null
            ? l10n.syncStatusFailed
            : l10n.syncStatusUpToDate;
        final color = status.isSyncing
            ? Theme.of(context).colorScheme.primary
            : status.errorMessage != null
            ? const Color(0xFFD32F2F)
            : const Color(0xFF2E7D32);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                status.isSyncing
                    ? Icons.sync_rounded
                    : status.errorMessage != null
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                size: 14,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
