import 'package:flutter/material.dart';

import '../../../../app/role_access/role_manager.dart';

class SettingsSubMenu {
  const SettingsSubMenu({required this.title, required this.view});

  final String title;
  final Widget view;
}

class SettingsMenuCategory {
  const SettingsMenuCategory({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.allowedRoles,
    required this.subMenus,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<AppRole> allowedRoles;
  final List<SettingsSubMenu> subMenus;
}
