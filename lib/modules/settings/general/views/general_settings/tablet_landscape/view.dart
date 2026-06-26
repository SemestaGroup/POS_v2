import 'package:flutter/material.dart';

import '../../../../../../app/role_access/role_manager.dart';
import '../../../../../../core/localization/locale_manager.dart';
import '../../../../../../core/services/sync/pos_v2_options_service.dart';
import '../../../../../../core/services/sync/pos_v2_runtime_session_store.dart';
import '../../../../../../core/services/sync/pos_v2_sync_status_store.dart';
import '../../../../../../l10n/app_localizations.dart';

class GeneralSettingsView extends StatefulWidget {
  const GeneralSettingsView({super.key});

  @override
  State<GeneralSettingsView> createState() => _GeneralSettingsViewState();
}

class _GeneralSettingsViewState extends State<GeneralSettingsView> {
  bool _allowSellOutOfStock = false;
  Map<String, dynamic> _options = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    // Attempt fetch to sync latest, don't wait for it to show cached
    PosV2OptionsService.instance.fetchAndSaveOptions().then((_) async {
      final opts = await PosV2OptionsService.instance.getLocalOptions();
      if (mounted) {
        setState(() {
          _options = opts;
        });
      }
    });

    final opts = await PosV2OptionsService.instance.getLocalOptions();
    if (mounted) {
      setState(() {
        _options = opts;
        _isLoading = false;
      });
    }
  }

  Future<void> _updateOption(String key, dynamic value) async {
    final success = await PosV2OptionsService.instance.updateOption(key, value);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Update successful')),
      );
      _loadOptions();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final session = PosV2RuntimeSessionStore.instance.currentSession;
    final l10n = AppLocalizations.of(context)!;

    final companyName = session?.tenantName ?? '-';
    final locationId = session?.locationId ?? '-';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── App Configuration ─────────────────────────────────────────────
          _buildFieldLabel('App Configuration'),
          const SizedBox(height: 10),
          _buildAppConfigTiles(l10n, primaryColor),

          const SizedBox(height: 28),

          // ── POS Options ───────────────────────────────────────────────
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else ...[
            _buildFieldLabel('POS Options API'),
            const SizedBox(height: 10),
            _buildOptionTile(
              'Online Store Base URL',
              _options['pos_online_store_base_url']?.toString() ?? '',
              Icons.link_rounded,
              (val) => _updateOption('pos_online_store_base_url', val),
            ),
            const SizedBox(height: 8),
            _buildOptionTile(
              'Operating Mode',
              _options['pos_operating_mode']?.toString() ?? '',
              Icons.mode_rounded,
              (val) => _updateOption('pos_operating_mode', val),
            ),
            const SizedBox(height: 8),
            _buildOptionTile(
              'App Settings (JSON)',
              _options['pos_app_settings']?.toString() ?? '',
              Icons.settings_applications_rounded,
              (val) => _updateOption('pos_app_settings', val),
            ),
            const SizedBox(height: 8),
            _buildOptionTile(
              'Self Order Settings (JSON)',
              _options['pos_self_order_settings']?.toString() ?? '',
              Icons.touch_app_rounded,
              (val) => _updateOption('pos_self_order_settings', val),
            ),
          ],

          const SizedBox(height: 28),

          // ── Info Fields ─────────────────────────────────────────────────
          _buildFieldLabel(l10n.settingsCompanyNameLabel),
          const SizedBox(height: 6),
          _buildFieldDisplay(
            icon: Icons.business_rounded,
            value: companyName,
          ),

          const SizedBox(height: 16),
          _buildFieldLabel(l10n.settingsLocationIdLabel),
          const SizedBox(height: 6),
          _buildFieldDisplay(
            icon: Icons.location_on_rounded,
            value: locationId,
          ),

          const SizedBox(height: 16),
          _buildFieldLabel(l10n.settingsServerUrlLabel),
          const SizedBox(height: 6),
          _buildFieldDisplay(
            icon: Icons.dns_rounded,
            value: session?.baseUrl ?? '-',
          ),

          const SizedBox(height: 16),
          _buildFieldLabel(l10n.settingsDeviceIdLabel),
          const SizedBox(height: 6),
          _buildFieldDisplay(
            icon: Icons.devices_rounded,
            value: session?.deviceId ?? '-',
          ),

          const SizedBox(height: 28),

          // ── Action Tiles ─────────────────────────────────────────────────
          _buildActionTile(
            icon: Icons.info_rounded,
            iconColor: primaryColor,
            title: l10n.settingsAppInfoTitle,
            subtitle: l10n.settingsAppInfoSubtitle,
            onTap: () {
              _showAppInfoDialog(context);
            },
          ),

          const SizedBox(height: 8),

          _buildActionTile(
            icon: Icons.cloud_sync_rounded,
            iconColor: primaryColor,
            title: l10n.settingsCheckUpdatesTitle,
            subtitle: l10n.settingsCheckUpdatesSubtitle,
            onTap: () {},
          ),

          const SizedBox(height: 8),

          _buildToggleTile(
            icon: Icons.production_quantity_limits_rounded,
            iconColor: primaryColor,
            title: l10n.settingsAllowSellOutOfStockTitle,
            subtitle: l10n.settingsAllowSellOutOfStockSubtitle,
            value: _allowSellOutOfStock,
            onChanged: (v) {
              setState(() {
                _allowSellOutOfStock = v;
              });
            },
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _buildAppConfigTiles(AppLocalizations l10n, Color primaryColor) {
    return Column(
      children: [
        ValueListenableBuilder<AppRole>(
          valueListenable: RoleManager.roleNotifier,
          builder: (context, role, _) {
            return _buildDropdownTile<AppRole>(
              icon: Icons.shield_rounded,
              iconColor: primaryColor,
              title: 'Active Role',
              value: role,
              items: AppRole.values
                  .where((r) => r != AppRole.programmer)
                  .toList(),
              labelBuilder: (r) => r.name.toUpperCase(),
              onChanged: (newRole) {
                if (newRole != null) RoleManager.changeRole(newRole);
              },
            );
          },
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<Locale>(
          valueListenable: LocaleManager.localeNotifier,
          builder: (context, locale, _) {
            final isId = locale.languageCode == 'id';
            return _buildDropdownTile<String>(
              icon: Icons.language_rounded,
              iconColor: primaryColor,
              title: 'Language',
              value: isId ? 'ID' : 'EN',
              items: const ['ID', 'EN'],
              labelBuilder: (l) => l,
              onChanged: (newLang) {
                if (newLang != null) {
                  LocaleManager.changeLocale(Locale(newLang.toLowerCase()));
                }
              },
            );
          },
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<PosV2SyncStatus>(
          valueListenable: PosV2SyncStatusStore.instance.statusNotifier,
          builder: (context, status, _) {
            final icon = status.isSyncing
                ? Icons.sync_rounded
                : status.errorMessage != null
                    ? Icons.error_outline_rounded
                    : Icons.cloud_done_rounded;
            final label = status.isSyncing
                ? 'Syncing...'
                : status.errorMessage != null
                    ? 'Sync Error'
                    : 'Synced';
            return _buildActionTile(
              icon: icon,
              iconColor: primaryColor,
              title: 'Sync Status',
              subtitle: label,
              onTap: () {},
            );
          },
        ),
      ],
    );
  }

  Widget _buildOptionTile(
      String title, String value, IconData icon, Function(String) onSave) {
    return InkWell(
      onTap: () async {
        final ctrl = TextEditingController(text: value);
        final newValue = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Edit $title'),
            content: TextField(
              controller: ctrl,
              maxLines: null,
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, ctrl.text),
                  child: const Text('Save')),
            ],
          ),
        );
        if (newValue != null && newValue != value) {
          onSave(newValue);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFEEEFF8), width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Theme.of(context).primaryColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(value.isEmpty ? '(Empty)' : value,
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ),
            Icon(Icons.edit, size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownTile<T>({
    required IconData icon,
    required Color iconColor,
    required String title,
    required T value,
    required List<T> items,
    required String Function(T) labelBuilder,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEEEFF8), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1D2E),
              ),
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              style: const TextStyle(fontSize: 13, color: Color(0xFF1A1D2E), fontWeight: FontWeight.w500),
              items: items
                  .map((e) =>
                      DropdownMenuItem(value: e, child: Text(labelBuilder(e))))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade600,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildFieldDisplay({
    required IconData icon,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2FF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF6C6F9E)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1A1D2E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFEEEFF8), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1D2E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEEEFF8), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1D2E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  void _showAppInfoDialog(BuildContext context) {
    final session = PosV2RuntimeSessionStore.instance.currentSession;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'App Info',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('App', 'FlinkPOS v2'),
            _infoRow('Tenant', session?.tenantName ?? '-'),
            _infoRow('Tenant Code', session?.tenantCode ?? '-'),
            _infoRow('Staff', session?.staffFullName ?? '-'),
            _infoRow('Role', session?.staffRoleCode ?? '-'),
            _infoRow('Last Bootstrap', session?.lastBootstrapAt ?? 'Never'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1D2E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
