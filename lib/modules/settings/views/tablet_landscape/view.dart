import 'package:flutter/material.dart';

import '../../../../app/role_access/role_manager.dart';
import '../../../../l10n/app_localizations.dart';
import '../../device/views/app_update/tablet_landscape/view.dart';
import '../../device/views/device_status/tablet_landscape/view.dart';
import '../../general/views/general_settings/tablet_landscape/view.dart';
import '../../general/views/profile_settings/tablet_landscape/view.dart';
import '../../printers/views/printer_list/tablet_landscape/view.dart';
import '../../printers/views/printer_mapping/tablet_landscape/view.dart';
import '../../printers/views/printer_test/tablet_landscape/view.dart';
import '../../store/views/shift_config/tablet_landscape/view.dart';
import '../../store/views/store_profile/tablet_landscape/view.dart';
import '../../sync/views/sync_center/tablet_landscape/view.dart';
import '../../sync/views/sync_history/tablet_landscape/view.dart';

class _SubMenuDefinition {
  final String title;
  final Widget view;

  _SubMenuDefinition({required this.title, required this.view});
}

class _MenuCategory {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<AppRole> allowedRoles;
  final List<_SubMenuDefinition> subMenus;

  _MenuCategory({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.allowedRoles,
    required this.subMenus,
  });
}

class SettingsShellView extends StatefulWidget {
  const SettingsShellView({super.key});

  @override
  State<SettingsShellView> createState() => _SettingsShellViewState();
}

class _SettingsShellViewState extends State<SettingsShellView> {
  int _selectedCategoryIndex = 0;

  List<_MenuCategory> get _allCategories {
    final l10n = AppLocalizations.of(context)!;
    return [
      _MenuCategory(
        title: l10n.settingsGeneralTitle,
        subtitle: l10n.settingsGeneralSubtitle,
        icon: Icons.settings_rounded,
        allowedRoles: [AppRole.owner],
        subMenus: [
          _SubMenuDefinition(
            title: l10n.generalSettingsMenu,
            view: const GeneralSettingsView(),
          ),
          _SubMenuDefinition(
            title: l10n.profileSettingsMenu,
            view: const ProfileSettingsView(),
          ),
        ],
      ),
      _MenuCategory(
        title: l10n.settingsStoreTitle,
        subtitle: l10n.settingsStoreSubtitle,
        icon: Icons.storefront_rounded,
        allowedRoles: [AppRole.owner],
        subMenus: [
          _SubMenuDefinition(
            title: l10n.storeProfileMenu,
            view: const StoreProfileView(),
          ),
          _SubMenuDefinition(
            title: l10n.shiftConfigMenu,
            view: const ShiftConfigView(),
          ),
        ],
      ),
      _MenuCategory(
        title: l10n.settingsPrinterTitle,
        subtitle: l10n.settingsPrinterSubtitle,
        icon: Icons.print_rounded,
        allowedRoles: [AppRole.owner],
        subMenus: [
          _SubMenuDefinition(
            title: l10n.printerListMenu,
            view: const PrinterListView(),
          ),
          _SubMenuDefinition(
            title: l10n.printerMappingMenu,
            view: const PrinterMappingView(),
          ),
          _SubMenuDefinition(
            title: l10n.printerTestMenu,
            view: const PrinterTestView(),
          ),
        ],
      ),
      _MenuCategory(
        title: l10n.settingsSyncTitle,
        subtitle: l10n.settingsSyncSubtitle,
        icon: Icons.sync_rounded,
        allowedRoles: [AppRole.owner],
        subMenus: [
          _SubMenuDefinition(
            title: l10n.syncCenterMenu,
            view: const SyncCenterView(),
          ),
          _SubMenuDefinition(
            title: l10n.syncHistoryMenu,
            view: const SyncHistoryView(),
          ),
        ],
      ),
      _MenuCategory(
        title: l10n.settingsDeviceTitle,
        subtitle: l10n.settingsDeviceSubtitle,
        icon: Icons.devices_rounded,
        allowedRoles: [AppRole.owner],
        subMenus: [
          _SubMenuDefinition(
            title: l10n.appUpdateMenu,
            view: const AppUpdateView(),
          ),
          _SubMenuDefinition(
            title: l10n.deviceStatusMenu,
            view: const DeviceStatusView(),
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.white,
      body: ValueListenableBuilder<AppRole>(
        valueListenable: RoleManager.roleNotifier,
        builder: (context, activeRole, _) {
          final filteredCategories = _allCategories
              .where((menu) => menu.allowedRoles.contains(activeRole))
              .toList();

          if (filteredCategories.isEmpty) {
            return Center(child: Text(l10n.settingsUnavailableMessage));
          }

          if (_selectedCategoryIndex >= filteredCategories.length) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _selectedCategoryIndex = 0;
                });
              }
            });
          }
          final safeIndex = _selectedCategoryIndex < filteredCategories.length
              ? _selectedCategoryIndex
              : 0;

          final selectedCategory = filteredCategories[safeIndex];

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Page Header (outside card) ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(bottom: 16, left: 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.settings_rounded,
                          color: primaryColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.settings,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1A1D2E),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.settingsSubtitle,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Main Card (sidebar + content) ────────────────────────────
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF0F2FF), // Soft greyish blue
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ── Sidebar ─────────────────────────────────────────
                            _buildSidebar(
                              theme,
                              primaryColor,
                              filteredCategories,
                              safeIndex,
                            ),

                            // ── Divider ─────────────────────────────────────────
                            VerticalDivider(
                              width: 1,
                              thickness: 1,
                              color: Colors.grey.shade100,
                            ),

                            // ── Content ─────────────────────────────────────────
                            Expanded(
                              child: DefaultTabController(
                                key: ValueKey('tab_${selectedCategory.title}'),
                                length: selectedCategory.subMenus.length,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // Active Order Style Header for Content
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        20,
                                        20,
                                        20,
                                        16,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: primaryColor.withValues(
                                                alpha: 0.1,
                                              ),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              selectedCategory.icon,
                                              color: primaryColor,
                                              size: 18,
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  selectedCategory.title,
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  selectedCategory.subtitle,
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.black54,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Divider(
                                      height: 1,
                                      thickness: 1,
                                      color: Colors.grey.shade100,
                                    ),
                                    // TabBar if multiple sub-menus
                                    if (selectedCategory.subMenus.length > 1)
                                      Container(
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: Colors.grey.shade100,
                                              width: 1.5,
                                            ),
                                          ),
                                        ),
                                        child: TabBar(
                                          isScrollable: true,
                                          tabAlignment: TabAlignment.start,
                                          labelColor: primaryColor,
                                          unselectedLabelColor:
                                              Colors.grey.shade500,
                                          indicatorColor: primaryColor,
                                          indicatorWeight: 3,
                                          dividerColor: Colors.transparent,
                                          labelStyle: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                          unselectedLabelStyle: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 12,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                          ),
                                          labelPadding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                          tabs: selectedCategory.subMenus
                                              .map(
                                                (sub) => Tab(text: sub.title),
                                              )
                                              .toList(),
                                        ),
                                      ),
                                    Expanded(
                                      child: TabBarView(
                                        children: selectedCategory.subMenus
                                            .map((sub) => sub.view)
                                            .toList(),
                                      ),
                                    ),
                                  ],
                                ), // Column
                              ), // DefaultTabController
                            ), // Expanded (Content)
                          ], // Row children
                        ), // Row
                      ), // ClipRRect
                    ), // Container (White)
                  ), // Container (Green)
                ), // Expanded (Main Card)
              ], // Column children
            ), // Column
          ); // Padding
        },
      ),
    );
  }

  Widget _buildSidebar(
    ThemeData theme,
    Color primaryColor,
    List<_MenuCategory> filteredCategories,
    int safeIndex,
  ) {
    return SizedBox(
      width: 220,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        child: ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: filteredCategories.length,
          itemBuilder: (context, index) {
            final isSelected = safeIndex == index;
            final category = filteredCategories[index];

            return InkWell(
              onTap: () {
                setState(() {
                  _selectedCategoryIndex = index;
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? primaryColor.withValues(alpha: 0.10)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      category.icon,
                      size: 18,
                      color: isSelected ? primaryColor : Colors.grey.shade500,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        category.title,
                        style: TextStyle(
                          fontSize: 13,
                          color: isSelected
                              ? primaryColor
                              : Colors.grey.shade600,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: primaryColor,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
