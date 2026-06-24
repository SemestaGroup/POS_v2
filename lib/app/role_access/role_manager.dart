import 'package:flutter/foundation.dart';

enum AppRole { owner, supervisor, cashier, kitchen, programmer }

class RoleManager {
  // Singleton pattern for easy global access
  RoleManager._();
  static final RoleManager _instance = RoleManager._();
  static RoleManager get instance => _instance;

  // The active role, defaulted to cashier as requested
  static final ValueNotifier<AppRole> roleNotifier = ValueNotifier<AppRole>(
    AppRole.cashier,
  );

  static void changeRole(AppRole newRole) {
    if (roleNotifier.value != newRole) {
      roleNotifier.value = newRole;
    }
  }

  static AppRole fromCode(String? roleCode) {
    switch (roleCode?.trim().toLowerCase()) {
      case 'owner':
      case 'admin':
        return AppRole.owner;
      case 'supervisor':
      case 'spv':
        return AppRole.supervisor;
      case 'kitchen':
        return AppRole.kitchen;
      case 'programmer':
      case 'developer':
        return AppRole.programmer;
      case 'cashier':
      default:
        return AppRole.cashier;
    }
  }

  // Convenience getters
  static bool get isOwner => roleNotifier.value == AppRole.owner;
  static bool get isSupervisor => roleNotifier.value == AppRole.supervisor;
  static bool get isCashier => roleNotifier.value == AppRole.cashier;
  static bool get isKitchen => roleNotifier.value == AppRole.kitchen;
  static bool get isProgrammer => roleNotifier.value == AppRole.programmer;

  // Formatting helper
  static String roleToString(AppRole role) {
    switch (role) {
      case AppRole.owner:
        return 'Owner';
      case AppRole.supervisor:
        return 'Supervisor';
      case AppRole.cashier:
        return 'Cashier';
      case AppRole.kitchen:
        return 'Kitchen';
      case AppRole.programmer:
        return 'Programmer';
    }
  }
}
