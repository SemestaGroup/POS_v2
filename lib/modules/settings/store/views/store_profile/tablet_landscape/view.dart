import 'package:flutter/material.dart';

import '../../../controllers/store_settings_controller.dart';
import '../../../models/store_settings_state.dart';

class StoreProfileView extends StatefulWidget {
  const StoreProfileView({super.key});

  @override
  State<StoreProfileView> createState() => _StoreProfileViewState();
}

class _StoreProfileViewState extends State<StoreProfileView> {
  final StoreProfileController _controller = StoreProfileController.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<StoreProfileState>(
      valueListenable: _controller.stateNotifier,
      builder: (context, state, _) {
        if (state.isLoading && state.tenantName == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.errorMessage != null && state.tenantName == null) {
          return Center(
            child: Text(
              state.errorMessage!,
              style: TextStyle(color: Colors.red.shade600),
            ),
          );
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
                        Text('Store Profile', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                        SizedBox(height: 3),
                        Text('Current tenant identity and public POS/store links', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
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
              _card(
                child: Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    _meta('Tenant Name', state.tenantName ?? '-'),
                    _meta('Tenant Code', state.tenantCode ?? '-'),
                    _meta('Base URL', state.baseUrl ?? '-'),
                    _meta('Location', state.locationId ?? '-'),
                    _meta('Device', state.deviceId ?? '-'),
                    _meta('Register', state.registerId ?? '-'),
                    _meta('Backend Version', state.version ?? '-'),
                    _meta('Last Bootstrap', state.lastBootstrapAt ?? '-'),
                    _meta('Feedback URL', state.feedbackUrl ?? '-'),
                    _meta('Online Store URL', state.onlineStoreBaseUrl ?? '-'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: child,
      );

  Widget _meta(String label, String value) => SizedBox(
        width: 240,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
            const SizedBox(height: 3),
            Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
          ],
        ),
      );
}
