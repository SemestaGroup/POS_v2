import 'dart:convert';
import 'package:flutter/material.dart';

import '../../../../../../l10n/app_localizations.dart';
import '../../../../../../core/services/sync/pos_v2_options_service.dart';
import '../../../controllers/store_settings_controller.dart';
import '../../../models/store_settings_state.dart';

class StoreProfileView extends StatefulWidget {
  const StoreProfileView({super.key});

  @override
  State<StoreProfileView> createState() => _StoreProfileViewState();
}

class _StoreProfileViewState extends State<StoreProfileView> {
  final StoreProfileController _controller = StoreProfileController.instance;
  bool _allowSellOutOfStock = false;
  Map<String, dynamic> _appSettings = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.refresh();
      _loadLocalOptions();
    });
  }

  Future<void> _loadLocalOptions() async {
    final opts = await PosV2OptionsService.instance.getLocalOptions();
    if (mounted) {
      setState(() {
        try {
          final raw = opts['pos_app_settings']?.toString() ?? '{}';
          _appSettings = jsonDecode(raw) as Map<String, dynamic>;
        } catch (_) {}

        final inventory = _appSettings['inventory'] is Map<String, dynamic>
            ? _appSettings['inventory'] as Map<String, dynamic>
            : <String, dynamic>{};
        _allowSellOutOfStock = inventory['allow_sell_out_of_stock'] == true;
      });
    }
  }

  Future<void> _toggleAllowSellOutOfStock(bool val) async {
    setState(() {
      _allowSellOutOfStock = val;
    });

    final inventory = _appSettings['inventory'] is Map<String, dynamic>
        ? _appSettings['inventory'] as Map<String, dynamic>
        : <String, dynamic>{};
    
    inventory['allow_sell_out_of_stock'] = val;
    _appSettings['inventory'] = inventory;

    await PosV2OptionsService.instance.updateOption('pos_app_settings', jsonEncode(_appSettings));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final primaryColor = Theme.of(context).colorScheme.primary;

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
              Wrap(
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
              const SizedBox(height: 32),
              
              // Inventory settings section
              const Text('Inventory Settings', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.production_quantity_limits_rounded, color: primaryColor),
                title: Text(l10n.settingsAllowSellOutOfStockTitle, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: Text(l10n.settingsAllowSellOutOfStockSubtitle, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                trailing: Switch(
                  value: _allowSellOutOfStock,
                  onChanged: _toggleAllowSellOutOfStock,
                  activeTrackColor: primaryColor.withValues(alpha: 0.5),
                  activeThumbColor: primaryColor,
                ),
              ),
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
            Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
          ],
        ),
      );
}
