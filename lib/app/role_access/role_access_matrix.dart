import 'app_role.dart';
import 'app_section.dart';

const roleAccessMatrix = <AppRole, Set<AppSection>>{
  AppRole.owner: {
    AppSection.overview,
    AppSection.sales,
    AppSection.operations,
    AppSection.reports,
    AppSection.masterData,
    AppSection.settings,
  },
  AppRole.supervisor: {
    AppSection.overview,
    AppSection.sales,
    AppSection.operations,
    AppSection.reports,
    AppSection.masterData,
  },
  AppRole.cashier: {
    AppSection.sales,
    AppSection.operations,
    AppSection.reports,
  },
  AppRole.kitchen: {AppSection.operations},
  AppRole.programmer: {AppSection.programmer},
};

const roleInitialSection = <AppRole, AppSection>{
  AppRole.owner: AppSection.overview,
  AppRole.supervisor: AppSection.overview,
  AppRole.cashier: AppSection.sales,
  AppRole.kitchen: AppSection.operations,
  AppRole.programmer: AppSection.programmer,
};
