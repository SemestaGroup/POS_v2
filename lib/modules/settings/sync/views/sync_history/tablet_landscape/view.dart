import 'package:flinkpos_v2/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import '../../../../../../../core/widgets/responsive/responsive_context.dart';

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
    final isMobile = context.isMobile;

    return ValueListenableBuilder<SyncHistoryState>(
      valueListenable: _controller.stateNotifier,
      builder: (context, state, _) {
        if (state.isLoading && state.queueEntries.isEmpty && state.errorEntries.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.all(isMobile ? 12 : 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppLocalizations.of(context)!.syncHistoryTitle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 3),
                        Text(AppLocalizations.of(context)!.syncHistoryDesc, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _controller.refresh,
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _panel(
                title: 'Recent Queue Entries',
                isMobile: isMobile,
                child: state.queueEntries.isEmpty
                    ? Text(AppLocalizations.of(context)!.syncHistoryNoQueue, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)))
                    : Column(
                        children: state.queueEntries.map((entry) {
                          if (isMobile) {
                            return _buildMobileQueueItem(entry);
                          }
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
                isMobile: isMobile,
                child: state.errorEntries.isEmpty
                    ? Text(AppLocalizations.of(context)!.syncHistoryNoErrors, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)))
                    : Column(
                        children: state.errorEntries.map((entry) {
                          if (isMobile) {
                            return _buildMobileErrorItem(entry);
                          }
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

  Widget _buildMobileQueueItem(dynamic entry) {
    Color statusColor = const Color(0xFF6B7280);
    Color statusBg = const Color(0xFFF1F3F4);
    IconData icon = Icons.pending_actions_rounded;

    if (entry.status.toString().toLowerCase() == 'processed') {
      statusColor = const Color(0xFF10B981);
      statusBg = const Color(0xFFE6F4EA);
      icon = Icons.check_circle_rounded;
    } else if (entry.status.toString().toLowerCase() == 'failed') {
      statusColor = const Color(0xFFEF4444);
      statusBg = const Color(0xFFFCE8E6);
      icon = Icons.cancel_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: statusBg, shape: BoxShape.circle),
            child: Icon(icon, color: statusColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.entityType} • ${entry.operation}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.endpoint,
                  style: const TextStyle(fontSize: 9, color: Color(0xFF9CA3AF)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  entry.status,
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Retries: x${entry.retryCount}',
                style: const TextStyle(fontSize: 9, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileErrorItem(dynamic entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFEF3C7)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: Color(0xFFFEF3C7), shape: BoxShape.circle),
            child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.category,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.message,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF78350F)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            entry.status,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
          ),
        ],
      ),
    );
  }

  Widget _panel({required String title, required Widget child, bool isMobile = false}) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10, top: 6),
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF8E8E93),
                letterSpacing: 1.0,
              ),
            ),
          ),
          child,
        ],
      );
    }
    return Container(
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
}
