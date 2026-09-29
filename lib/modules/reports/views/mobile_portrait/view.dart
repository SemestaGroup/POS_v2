import 'package:flutter/material.dart';

import '../../../../core/widgets/navigation/mobile_section_menu_page.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../app/role_access/role_manager.dart';
import '../cashier_report_lite/cashier_report_lite_view.dart';
import '../product_report/tablet_landscape/view.dart';
import '../promo_sales_report/promo_sales_report_view.dart';
import '../top_customers_report/top_customers_report_view.dart';
import '../report_summary/report_summary_view.dart';
import '../sales_report/tablet_landscape/view.dart';
import '../staff_report/tablet_landscape/view.dart';

class ReportsMobileShellView extends StatelessWidget {
  const ReportsMobileShellView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ValueListenableBuilder<AppRole>(
      valueListenable: RoleManager.roleNotifier,
      builder: (context, role, _) {
        final items = <MobileMenuItem>[
          MobileMenuItem(
            title: l10n.reportSummaryMenu,
            subtitle: 'Ikhtisar performa penjualan toko',
            icon: Icons.summarize_rounded,
            iconBackground: const Color(0xFFEEF2FF),
            iconColor: const Color(0xFF4F46E5),
            view: const ReportSummaryView(),
          ),
          MobileMenuItem(
            title: l10n.salesReportMenu,
            subtitle: 'Analisis omzet & grafik harian',
            icon: Icons.trending_up_rounded,
            iconBackground: const Color(0xFFECFDF5),
            iconColor: const Color(0xFF059669),
            view: const SalesReportView(),
          ),
          MobileMenuItem(
            title: l10n.productReportMenu,
            subtitle: 'Performa & kontribusi produk terlaris',
            icon: Icons.inventory_2_rounded,
            iconBackground: const Color(0xFFFFFBEB),
            iconColor: const Color(0xFFD97706),
            view: const ProductReportView(),
          ),
          if (role == AppRole.owner || role == AppRole.supervisor) ...[
            const MobileMenuItem(
              title: 'Pelanggan Teratas',
              subtitle: 'Peringkat pelanggan berdasarkan total belanja',
              icon: Icons.emoji_events_rounded,
              iconBackground: Color(0xFFFEF3C7),
              iconColor: Color(0xFFB45309),
              view: TopCustomersReportView(),
            ),
            const MobileMenuItem(
              title: 'Penjualan Promo',
              subtitle: 'Performa promo, potongan, dan omset',
              icon: Icons.local_offer_rounded,
              iconBackground: Color(0xFFFCE7F3),
              iconColor: Color(0xFFBE185D),
              view: PromoSalesReportView(),
            ),
          ],
          if (role == AppRole.owner)
            MobileMenuItem(
              title: l10n.staffReportMenu,
              subtitle: 'Performa staf & riwayat transaksi',
              icon: Icons.people_outline_rounded,
              iconBackground: const Color(0xFFF5F3FF),
              iconColor: const Color(0xFF7C3AED),
              view: const StaffReportView(),
            ),
          MobileMenuItem(
            title: l10n.cashierReportLiteMenu,
            subtitle: 'Laporan per kasir & setoran uang',
            icon: Icons.point_of_sale_rounded,
            iconBackground: const Color(0xFFF0FDFA),
            iconColor: const Color(0xFF0D9488),
            view: const CashierReportLiteView(),
          ),
        ];
        return ReportsMobileView(items: items);
      },
    );
  }
}

class ReportsMobileView extends StatelessWidget {
  const ReportsMobileView({super.key, required this.items});

  final List<MobileMenuItem> items;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return MobileMenuListPage(
      title: l10n.reports,
      groups: [
        MobileMenuGroup(
          label: l10n.mobileSectionReportsAndAnalytics,
          items: items,
        ),
      ],
    );
  }
}
