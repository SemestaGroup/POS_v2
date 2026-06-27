import 'package:flutter/material.dart';

import '../../../controllers/app_update_controller.dart';
import '../../../models/app_update_state.dart';

class AppUpdateView extends StatefulWidget {
  const AppUpdateView({super.key});

  @override
  State<AppUpdateView> createState() => _AppUpdateViewState();
}

class _AppUpdateViewState extends State<AppUpdateView> {
  final AppUpdateController _controller = AppUpdateController.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return ValueListenableBuilder<AppUpdateState>(
      valueListenable: _controller.stateNotifier,
      builder: (context, state, _) {
        if (state.isLoading && state.backendVersion == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(Icons.system_update_rounded, size: 40, color: primaryColor),
              ),
              const SizedBox(height: 20),
              const Text('FlinkPOS V2', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                'Backend version ${state.backendVersion ?? '-'}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    _meta('Base URL', state.baseUrl ?? '-'),
                    _meta('Location', state.locationId ?? '-'),
                    _meta('Register', state.registerId ?? '-'),
                    _meta('Last Bootstrap', state.lastBootstrapAt ?? '-'),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: state.isRefreshing ? null : _controller.refreshBootstrap,
                child: state.isRefreshing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Refresh Bootstrap', style: TextStyle(fontWeight: FontWeight.w700)),
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

  Widget _meta(String label, String value) => SizedBox(
        width: 240,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
            const SizedBox(height: 3),
            Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}
