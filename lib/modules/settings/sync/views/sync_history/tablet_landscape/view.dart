import 'package:flutter/material.dart';

import '../../../controllers/sync_settings_controller.dart';
import '../../../models/sync_settings_state.dart';

class SyncHistoryView extends StatefulWidget {
  const SyncHistoryView({super.key});

  @override
  State<SyncHistoryView> createState() => _SyncHistoryViewState();
}

class _SyncHistoryViewState extends State<SyncHistoryView> {
  final SyncHistoryController _controller = SyncHistoryController.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SyncHistoryState>(
      valueListenable: _controller.stateNotifier,
      builder: (context, state, _) {
        if (state.isLoading && state.queueEntries.isEmpty && state.errorEntries.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sync History', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                        SizedBox(height: 3),
                        Text('Recent queue activity and local error logs.', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _controller.refresh,
                    icon: const Icon(Icons.refresh_rounded, size: 14),
                    label: const Text('Refresh', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _panel(
                title: 'Recent Queue Entries',
                child: state.queueEntries.isEmpty
                    ? const Text('No recent queue entries.', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)))
                    : Column(
                        children: state.queueEntries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text('${entry.entityType} • ${entry.operation}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(entry.endpoint, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(entry.status, style: const TextStyle(fontSize: 10)),
                                ),
                                Expanded(
                                  child: Text('x${entry.retryCount}', style: const TextStyle(fontSize: 10)),
                                ),
                              ],
                            ),
                          );
                        }).toList(growable: false),
                      ),
              ),
              const SizedBox(height: 12),
              _panel(
                title: 'Recent Error Logs',
                child: state.errorEntries.isEmpty
                    ? const Text('No recent error logs.', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)))
                    : Column(
                        children: state.errorEntries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Text(entry.category, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                ),
                                Expanded(
                                  flex: 5,
                                  child: Text(entry.message, style: const TextStyle(fontSize: 10, color: Color(0xFF374151))),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(entry.status, style: const TextStyle(fontSize: 10)),
                                ),
                              ],
                            ),
                          );
                        }).toList(growable: false),
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

  Widget _panel({required String title, required Widget child}) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      );
}
