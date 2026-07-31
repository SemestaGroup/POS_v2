import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../../../../core/widgets/responsive/responsive_context.dart';

import '../../../../../../l10n/app_localizations.dart';
import '../../../../../../core/services/sync/pos_v2_options_service.dart';
import '../../../../../../core/services/sync/pos_v2_sync_status_store.dart';
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
    PosV2SyncStatusStore.instance.statusNotifier.addListener(_onSyncStatusChanged);
  }

  @override
  void dispose() {
    PosV2SyncStatusStore.instance.statusNotifier.removeListener(_onSyncStatusChanged);
    super.dispose();
  }

  void _onSyncStatusChanged() {
    final status = PosV2SyncStatusStore.instance.statusNotifier.value;
    if (!status.isSyncing) {
      _loadLocalOptions();
    }
  }

  Future<void> _loadLocalOptions() async {
    final opts = await PosV2OptionsService.instance.getLocalOptions();
    if (mounted) {
      setState(() {
        try {
          final raw = opts['pos_app_settings'];
          if (raw is Map) {
            _appSettings = Map<String, dynamic>.from(raw);
          } else if (raw is String && raw.isNotEmpty) {
            _appSettings = jsonDecode(raw) as Map<String, dynamic>;
          }
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

  Widget _buildGroupedCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildMobileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isMobile = context.isMobile;

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

        final metaList = [
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
        ];

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.all(isMobile ? 14 : 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppLocalizations.of(context)!.storeProfileTitle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 3),
                        Text(AppLocalizations.of(context)!.storeProfileDesc, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _controller.refresh,
                    icon: const Icon(Icons.refresh_rounded, size: 14),
                    label: Text(AppLocalizations.of(context)!.refresh, style: const TextStyle(fontSize: 11)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              isMobile
                  ? _buildGroupedCard(
                      child: Column(
                        children: [
                          _buildMobileRow('Tenant Name', state.tenantName ?? '-'),
                          const Divider(height: 1, color: Color(0xFFF3F4F6)),
                          _buildMobileRow('Tenant Code', state.tenantCode ?? '-'),
                          const Divider(height: 1, color: Color(0xFFF3F4F6)),
                          _buildMobileRow('Base URL', state.baseUrl ?? '-'),
                          const Divider(height: 1, color: Color(0xFFF3F4F6)),
                          _buildMobileRow('Location', state.locationId ?? '-'),
                          const Divider(height: 1, color: Color(0xFFF3F4F6)),
                          _buildMobileRow('Device', state.deviceId ?? '-'),
                          const Divider(height: 1, color: Color(0xFFF3F4F6)),
                          _buildMobileRow('Register', state.registerId ?? '-'),
                          const Divider(height: 1, color: Color(0xFFF3F4F6)),
                          _buildMobileRow('Backend Version', state.version ?? '-'),
                          const Divider(height: 1, color: Color(0xFFF3F4F6)),
                          _buildMobileRow('Last Bootstrap', state.lastBootstrapAt ?? '-'),
                          const Divider(height: 1, color: Color(0xFFF3F4F6)),
                          _buildMobileRow('Feedback URL', state.feedbackUrl ?? '-'),
                          const Divider(height: 1, color: Color(0xFFF3F4F6)),
                          _buildMobileRow('Online Store URL', state.onlineStoreBaseUrl ?? '-'),
                        ],
                      ),
                    )
                  : Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: metaList,
                    ),
              const SizedBox(height: 28),
              
              // Inventory settings section
              Text(AppLocalizations.of(context)!.storeProfileInventorySettings, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              isMobile
                  ? _buildGroupedCard(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Row(
                          children: [
                            Icon(Icons.production_quantity_limits_rounded, color: primaryColor, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(l10n.settingsAllowSellOutOfStockTitle, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text(l10n.settingsAllowSellOutOfStockSubtitle, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Transform.scale(
                              scale: 0.8,
                              child: Switch(
                                value: _allowSellOutOfStock,
                                onChanged: _toggleAllowSellOutOfStock,
                                activeTrackColor: primaryColor.withValues(alpha: 0.5),
                                activeThumbColor: primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListTile(
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
