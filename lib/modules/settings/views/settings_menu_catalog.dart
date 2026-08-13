import 'package:flutter/material.dart';

import '../../../app/role_access/role_manager.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/device/views/app_update/app_update_view.dart';
import '../../settings/device/views/device_status/device_status_view.dart';
import '../../settings/general/views/general_settings/general_settings_view.dart';
import '../../settings/general/views/profile_settings/profile_settings_view.dart';
import '../../settings/printers/views/printer_list/printer_list_view.dart';
import '../../settings/printers/views/printer_mapping/printer_mapping_view.dart';
import '../../settings/printers/views/printer_test/tablet_landscape/view.dart';
import '../../settings/store/views/shift_config/shift_config_view.dart';
import '../../settings/store/views/store_profile/store_profile_view.dart';
import '../../settings/store/views/wa_report_request/wa_report_request_view.dart';
import '../../settings/sync/views/sync_center/sync_center_view.dart';
import '../../settings/sync/views/sync_history/sync_history_view.dart';
import 'models/settings_menu.dart';

List<SettingsMenuCategory> buildSettingsMenuCategories(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  const ownerOnly = [AppRole.owner];
  const ownerAndSupervisor = [AppRole.owner, AppRole.supervisor];

  return [
    SettingsMenuCategory(
      title: l10n.settingsGeneralTitle,
      subtitle: l10n.settingsGeneralSubtitle,
      icon: Icons.settings_rounded,
      allowedRoles: ownerAndSupervisor,
      subMenus: [
        SettingsSubMenu(
          title: l10n.generalSettingsMenu,
          view: const GeneralSettingsView(),
        ),
        SettingsSubMenu(
          title: l10n.profileSettingsMenu,
          view: const ProfileSettingsView(),
        ),
      ],
    ),
    SettingsMenuCategory(
      title: l10n.settingsStoreTitle,
      subtitle: l10n.settingsStoreSubtitle,
      icon: Icons.storefront_rounded,
      allowedRoles: ownerAndSupervisor,
      subMenus: [
        SettingsSubMenu(
          title: l10n.storeProfileMenu,
          view: const StoreProfileView(),
        ),
        SettingsSubMenu(
          title: l10n.shiftConfigMenu,
          view: const ShiftConfigView(),
        ),
        const SettingsSubMenu(
          title: 'Request Laporan WA',
          view: WaReportRequestView(),
        ),
      ],
    ),
    SettingsMenuCategory(
      title: l10n.settingsPrinterTitle,
      subtitle: l10n.settingsPrinterSubtitle,
      icon: Icons.print_rounded,
      allowedRoles: ownerAndSupervisor,
      subMenus: [
        SettingsSubMenu(
          title: l10n.printerListMenu,
          view: const PrinterListView(),
        ),
        SettingsSubMenu(
          title: l10n.printerMappingMenu,
          view: const PrinterMappingView(),
        ),
        SettingsSubMenu(
          title: l10n.printerTestMenu,
          view: const PrinterTestView(),
        ),
      ],
    ),
    SettingsMenuCategory(
      title: l10n.settingsSyncTitle,
      subtitle: l10n.settingsSyncSubtitle,
      icon: Icons.sync_rounded,
      allowedRoles: ownerOnly,
      subMenus: [
        SettingsSubMenu(
          title: l10n.syncCenterMenu,
          view: const SyncCenterView(),
        ),
        SettingsSubMenu(
          title: l10n.syncHistoryMenu,
          view: const SyncHistoryView(),
        ),
      ],
    ),
    SettingsMenuCategory(
      title: l10n.settingsDeviceTitle,
      subtitle: l10n.settingsDeviceSubtitle,
      icon: Icons.devices_rounded,
      allowedRoles: ownerOnly,
      subMenus: [
        SettingsSubMenu(title: l10n.appUpdateMenu, view: const AppUpdateView()),
        SettingsSubMenu(
          title: l10n.deviceStatusMenu,
          view: const DeviceStatusView(),
        ),
      ],
    ),
  ];
}
