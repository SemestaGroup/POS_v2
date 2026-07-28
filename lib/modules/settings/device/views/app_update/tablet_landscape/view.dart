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
    final isMobile = MediaQuery.of(context).size.shortestSide < 600;

    return ValueListenableBuilder<AppUpdateState>(
      valueListenable: _controller.stateNotifier,
      builder: (context, state, _) {
        if (state.isLoading && state.backendVersion == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.system_update_rounded, size: 36, color: primaryColor),
              ),
              const SizedBox(height: 16),
              const Text('FlinkPOS V2', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1F2937))),
              const SizedBox(height: 6),
              Text(
                'Backend version ${state.backendVersion ?? '-'}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: isMobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _meta('Base URL', state.baseUrl ?? '-', isMobile: true),
                          const Divider(height: 20, color: Color(0xFFF3F4F6)),
                          _meta('Location', state.locationId ?? '-', isMobile: true),
                          const Divider(height: 20, color: Color(0xFFF3F4F6)),
                          _meta('Register', state.registerId ?? '-', isMobile: true),
                          const Divider(height: 20, color: Color(0xFFF3F4F6)),
                          _meta('Last Bootstrap', state.lastBootstrapAt ?? '-', isMobile: true),
                        ],
                      )
                    : Wrap(
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
              const SizedBox(height: 24),
              SizedBox(
                width: isMobile ? double.infinity : 200,
                height: 46,
                child: FilledButton(
                  onPressed: state.isRefreshing ? null : _controller.refreshBootstrap,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: state.isRefreshing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Refresh Bootstrap', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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

  Widget _meta(String label, String value, {bool isMobile = false}) => SizedBox(
        width: isMobile ? double.infinity : 240,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
          ],
        ),
      );
}
