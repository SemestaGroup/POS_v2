import '../role_access/app_role.dart';
import 'app_routes.dart';

const roleEntryRoutes = <AppRole, String>{
  AppRole.owner: AppRoutes.ownerShell,
  AppRole.supervisor: AppRoutes.supervisorShell,
  AppRole.cashier: AppRoutes.cashierShell,
  AppRole.kitchen: AppRoutes.kitchenShell,
  AppRole.programmer: AppRoutes.developerHub,
};
