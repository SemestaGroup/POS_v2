import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../../../app/role_access/role_manager.dart';
import '../../../../../../app/shell/controllers/main_shell_sync_controller.dart';
import '../../../../../../core/constants/app_constants.dart';
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

class GeneralSettingsSaveAction {
  static final triggerSave = ValueNotifier<int>(0);
  static final isSaving = ValueNotifier<bool>(false);
}

class _GeneralSettingsViewState extends State<GeneralSettingsView> {
  Map<String, dynamic> _options = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOptions();
    GeneralSettingsSaveAction.triggerSave.addListener(_onGlobalSaveTriggered);
  }

  @override
  void dispose() {
    GeneralSettingsSaveAction.triggerSave.removeListener(_onGlobalSaveTriggered);
    super.dispose();
  }

  void _onGlobalSaveTriggered() {
    _saveAll();
  }

  Future<void> _loadOptions() async {
    // Only load from SQLite (offline first), do not fetch API automatically on tab switch.
    final opts = await PosV2OptionsService.instance.getLocalOptions();
    if (mounted) {
      setState(() {
        _options = opts;
        _isLoading = false;
      });
    }
  }

  void _updateOption(String key, dynamic value) {
    setState(() {
      _options[key] = value;
    });
  }

  void _saveAll() async {
    GeneralSettingsSaveAction.isSaving.value = true;
    final success = await PosV2OptionsService.instance.updateMultipleOptions(_options);
    GeneralSettingsSaveAction.isSaving.value = false;
    if (mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? l10n.settingsSuccessSave : l10n.settingsFailSave)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── App Configuration ─────────────────────────────────────────────
          _buildFieldLabel(l10n.settingsAppConfig),
          const SizedBox(height: 10),
          _buildAppConfigTiles(l10n, primaryColor),

          const SizedBox(height: 28),

          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else ...[
            // ── Store & API Settings ─────────────────────────────────────────
            _buildFieldLabel(l10n.settingsStoreApi),
            const SizedBox(height: 10),
            _buildStoreApiTiles(primaryColor),

            const SizedBox(height: 28),

            // ── Display Configuration ────────────────────────────────────────
            _buildFieldLabel(l10n.settingsDisplayConfig),
            const SizedBox(height: 10),
            _buildDisplayConfiguration(primaryColor),
            
            const SizedBox(height: 28),

            // ── Self Order Settings ──────────────────────────────────────────
            _buildFieldLabel(l10n.settingsSelfOrder),
            const SizedBox(height: 10),
            _buildSelfOrderSettings(primaryColor),
          ],
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
              title: l10n.settingsActiveRole,
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
              title: l10n.settingsLanguage,
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
            final isPartial = status.stage == 'partial_synced';
            final isError = status.errorMessage != null;
            final isSyncing = status.isSyncing;

            final icon = isSyncing
                ? Icons.sync_rounded
                : isError
                    ? Icons.error_outline_rounded
                    : isPartial
                        ? Icons.cloud_download_rounded
                        : Icons.cloud_done_rounded;
                        
            final label = isSyncing
                ? l10n.settingsSyncing
                : isError
                    ? l10n.settingsSyncError
                    : isPartial
                        ? l10n.settingsPartialSynced
                        : l10n.settingsSynced;

            return _buildActionTile(
              icon: icon,
              iconColor: isPartial ? Colors.orange.shade700 : primaryColor,
              title: l10n.settingsSyncMasterData,
              subtitle: label,
              onTap: () {
                if (!isSyncing) {
                  // Trigger full master data sync
                  MainShellSyncController.instance.triggerManualMasterDataSync();
                }
              },
            );
          },
        ),
        const SizedBox(height: 8),
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
      ],
    );
  }

  Widget _buildStoreApiTiles(Color primaryColor) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        Builder(
          builder: (context) {
            Map<String, dynamic> opModeJson = {};
            try {
              final raw = _options['pos_operating_mode']?.toString() ?? '{}';
              opModeJson = jsonDecode(raw) as Map<String, dynamic>;
            } catch (_) {}

            final currentMode = opModeJson['mode']?.toString() ?? 'classic';
            final rawAvailable = opModeJson['available_modes'];
            final List<String> availableModes = (rawAvailable is List) 
                ? rawAvailable.map((e) => e.toString()).toList() 
                : ['classic', 'self_order_hybrid'];

            if (!availableModes.contains(currentMode)) {
              availableModes.add(currentMode);
            }

            void updateMode(String? newMode) {
              if (newMode == null) return;
              opModeJson['mode'] = newMode;
              opModeJson['changed_by'] = 'user';
              _updateOption('pos_operating_mode', jsonEncode(opModeJson));
            }

            return _buildDropdownTile<String>(
              icon: Icons.mode_rounded,
              iconColor: primaryColor,
              title: l10n.settingsOperatingMode,
              value: currentMode,
              items: availableModes,
              labelBuilder: (m) => m.replaceAll('_', ' ').toUpperCase(),
              onChanged: updateMode,
            );
          },
        ),
        const SizedBox(height: 8),
        _buildOptionTile(
          l10n.settingsOnlineStoreUrl,
          _options['pos_online_store_base_url']?.toString() ?? '',
          Icons.link_rounded,
          (val) => _updateOption('pos_online_store_base_url', val),
        ),
        const SizedBox(height: 8),
        _buildOptionTile(
          l10n.settingsWebhookUrl,
          _options['pos_transaction_webhook_url']?.toString() ?? '',
          Icons.webhook_rounded,
          (val) => _updateOption('pos_transaction_webhook_url', val),
        ),
      ],
    );
  }

  Widget _buildDisplayConfiguration(Color primaryColor) {
    final l10n = AppLocalizations.of(context)!;
    return Builder(
      builder: (context) {
        // Parse the JSON
        Map<String, dynamic> appSettings = {};
        try {
          final raw = _options['pos_app_settings']?.toString() ?? '{}';
          appSettings = jsonDecode(raw) as Map<String, dynamic>;
        } catch (_) {}

        final display = appSettings['display'] is Map<String, dynamic>
            ? appSettings['display'] as Map<String, dynamic>
            : <String, dynamic>{};

        display['show_image'] = display['show_image'] ?? true;
        display['show_name'] = display['show_name'] ?? true;
        display['show_stock'] = display['show_stock'] ?? true;
        display['show_price'] = display['show_price'] ?? true;

        final showName = display['show_name'];
        final showStock = display['show_stock'];
        final showPrice = display['show_price'];

        int activeCount = (display['show_image'] ? 1 : 0) +
            (showName ? 1 : 0) +
            (showStock ? 1 : 0) +
            (showPrice ? 1 : 0);

        void updateDisplay(String key, bool val) {
          if (!val && activeCount <= 2) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.settingsMinDisplayOptions)),
            );
            return;
          }
          
          display[key] = val;
          appSettings['display'] = display;
          _updateOption('pos_app_settings', jsonEncode(appSettings));
        }

        return Column(
          children: [
            _buildToggleTile(
              icon: Icons.image_rounded,
              iconColor: primaryColor,
              title: l10n.settingsShowImage,
              subtitle: l10n.settingsShowImageDesc,
              value: true, 
              onChanged: null,
            ),
            const SizedBox(height: 8),
            _buildToggleTile(
              icon: Icons.title_rounded,
              iconColor: primaryColor,
              title: l10n.settingsShowName,
              subtitle: l10n.settingsShowNameDesc,
              value: showName,
              onChanged: (val) => updateDisplay('show_name', val),
            ),
            const SizedBox(height: 8),
            _buildToggleTile(
              icon: Icons.inventory_2_rounded,
              iconColor: primaryColor,
              title: l10n.settingsShowStock,
              subtitle: l10n.settingsShowStockDesc,
              value: showStock,
              onChanged: (val) => updateDisplay('show_stock', val),
            ),
            const SizedBox(height: 8),
            _buildToggleTile(
              icon: Icons.payments_rounded,
              iconColor: primaryColor,
              title: l10n.settingsShowPrice,
              subtitle: l10n.settingsShowPriceDesc,
              value: showPrice,
              onChanged: (val) => updateDisplay('show_price', val),
            ),
          ],
        );
      }
    );
  }

  Widget _buildSelfOrderSettings(Color primaryColor) {
    final l10n = AppLocalizations.of(context)!;
    return Builder(
      builder: (context) {
        Map<String, dynamic> selfOrderSettings = {};
        try {
          final raw = _options['pos_self_order_settings']?.toString() ?? '{}';
          selfOrderSettings = jsonDecode(raw) as Map<String, dynamic>;
        } catch (_) {}

        final enableSelfOrder = selfOrderSettings['enable_self_order'] ?? false;
        final requireTableNumber = selfOrderSettings['require_table_number'] ?? false;
        final allowGuestCheckout = selfOrderSettings['allow_guest_checkout'] ?? true;

        void updateSetting(String key, bool val) {
          selfOrderSettings[key] = val;
          _updateOption('pos_self_order_settings', jsonEncode(selfOrderSettings));
        }

        return Column(
          children: [
            _buildToggleTile(
              icon: Icons.touch_app_rounded,
              iconColor: primaryColor,
              title: l10n.settingsEnableSelfOrder,
              subtitle: l10n.settingsEnableSelfOrderDesc,
              value: enableSelfOrder,
              onChanged: (val) => updateSetting('enable_self_order', val),
            ),
            const SizedBox(height: 8),
            _buildToggleTile(
              icon: Icons.table_bar_rounded,
              iconColor: primaryColor,
              title: l10n.settingsRequireTableNumber,
              subtitle: l10n.settingsRequireTableNumberDesc,
              value: requireTableNumber,
              onChanged: (val) => updateSetting('require_table_number', val),
            ),
            const SizedBox(height: 8),
            _buildToggleTile(
              icon: Icons.person_off_rounded,
              iconColor: primaryColor,
              title: l10n.settingsAllowGuestCheckout,
              subtitle: l10n.settingsAllowGuestCheckoutDesc,
              value: allowGuestCheckout,
              onChanged: (val) => updateSetting('allow_guest_checkout', val),
            ),
          ],
        );
      }
    );
  }

  Widget _buildOptionTile(
      String title, String value, IconData icon, Function(String) onSave) {
    final l10n = AppLocalizations.of(context)!;
    return InkWell(
      onTap: () async {
        final ctrl = TextEditingController(text: value);
        final newValue = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: Colors.white,
            title: Text(l10n.settingsEditTitle(title), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF1A1D2E))),
            content: TextField(
              controller: ctrl,
              maxLines: null,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF8F9FF),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n.settingsCancel, style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600))),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(ctx, ctrl.text),
                  child: Text(l10n.settingsSave, style: const TextStyle(fontWeight: FontWeight.w600))),
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
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: Theme.of(context).primaryColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A1D2E))),
                  Text(value.isEmpty ? l10n.settingsEmpty : value,
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
    required ValueChanged<bool>? onChanged,
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
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: value,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  void _showAppInfoDialog(BuildContext context) {
    final session = PosV2RuntimeSessionStore.instance.currentSession;
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Text(
          l10n.settingsAppInfoTitle,
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Color(0xFF1A1D2E)),
        ),
        content: Container(
          width: 400,
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow(l10n.settingsApp, 'FlinkPOS v2'),
              _infoRow(l10n.settingsVersion, AppConstants.appVersion),
              _infoRow(l10n.settingsTenant, session?.tenantName ?? '-'),
              _infoRow(l10n.settingsTenantCode, session?.tenantCode ?? '-'),
              _infoRow(l10n.settingsStaff, session?.staffFullName ?? '-'),
              _infoRow(l10n.settingsRole, session?.staffRoleCode ?? '-'),
              _infoRow(l10n.settingsLastBootstrap, session?.lastBootstrapAt ?? l10n.settingsNever),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.settingsClose, style: const TextStyle(fontWeight: FontWeight.w600)),
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
