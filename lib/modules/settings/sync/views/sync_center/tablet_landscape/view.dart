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
    return ValueListenableBuilder<SyncCenterState>(
      valueListenable: _controller.stateNotifier,
      builder: (context, state, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Sync Center', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              const Text('Observe queue health and trigger lightweight recovery actions.', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _card('Pending', '${state.pendingCount}')),
                  const SizedBox(width: 10),
                  Expanded(child: _card('Failed', '${state.failedCount}')),
                  const SizedBox(width: 10),
                  Expanded(child: _card('Processed', '${state.processedCount}')),
                  const SizedBox(width: 10),
                  Expanded(child: _card('Errors', '${state.errorCount}')),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Current Sync Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text('Stage: ${state.status.stage}', style: const TextStyle(fontSize: 11)),
                          Text('Blocking: ${state.status.isBlocking ? 'Yes' : 'No'}', style: const TextStyle(fontSize: 11)),
                          Text('Progress: ${state.status.progress != null ? (state.status.progress! * 100).toInt() : 0}%', style: const TextStyle(fontSize: 11)),
                          if (state.status.errorMessage != null)
                            Text(state.status.errorMessage!, style: TextStyle(fontSize: 11, color: Colors.red.shade600)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: state.isLoading ? null : _controller.refresh,
                          child: const Text('Refresh', style: TextStyle(fontSize: 11)),
                        ),
                        FilledButton.tonal(
                          onPressed: state.isLoading ? null : _controller.flushQueue,
                          child: const Text('Flush Queue', style: TextStyle(fontSize: 11)),
                        ),
                        FilledButton(
                          onPressed: state.isLoading ? null : _controller.refreshBootstrap,
                          child: const Text('Refresh Bootstrap', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
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
