import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../stores/report_read_stores.dart';

class ReportSummaryView extends StatefulWidget {
  const ReportSummaryView({super.key});

  @override
  State<ReportSummaryView> createState() => _ReportSummaryViewState();
}

class _ReportSummaryViewState extends State<ReportSummaryView> {
  final ReportSummaryStore _store = ReportSummaryStore.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _store.refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat('#,###', 'id_ID');
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return ValueListenableBuilder<ReportSummarySnapshot>(
      valueListenable: _store.snapshotNotifier,
      builder: (context, snapshot, _) {
        if (snapshot.isLoading && snapshot.topProducts.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.errorMessage != null && snapshot.topProducts.isEmpty) {
          return Center(
            child: Text(
              snapshot.errorMessage!,
              style: TextStyle(color: Colors.red.shade600),
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildPeriodCard(
                      title: 'Hari Ini',
                      sales: snapshot.todaySales,
                      transactions: snapshot.todayTransactions,
                      color: primaryColor,
                      icon: Icons.today_rounded,
                      currencyFmt: currencyFmt,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildPeriodCard(
                      title: '7 Hari Terakhir',
                      sales: snapshot.weekSales,
                      transactions: snapshot.weekTransactions,
                      color: const Color(0xFF8B5CF6),
                      icon: Icons.date_range_rounded,
                      currencyFmt: currencyFmt,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildPeriodCard(
                      title: 'Bulan Ini',
                      sales: snapshot.monthSales,
                      transactions: snapshot.monthTransactions,
                      color: const Color(0xFF10B981),
                      icon: Icons.calendar_month_rounded,
                      currencyFmt: currencyFmt,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildSmallStatCard(
                      label: 'Transaksi Hari Ini',
                      value: '${snapshot.todayTransactions}',
                      icon: Icons.receipt_rounded,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildSmallStatCard(
                      label: 'Diskon Hari Ini',
                      value: 'Rp ${currencyFmt.format(snapshot.todayDiscount)}',
                      icon: Icons.local_offer_rounded,
                      color: const Color(0xFFF59E0B),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildSmallStatCard(
                      label: 'Rata-rata per Transaksi',
                      value: snapshot.todayTransactions > 0
                          ? 'Rp ${currencyFmt.format(snapshot.todaySales ~/ snapshot.todayTransactions)}'
                          : 'Rp 0',
                      icon: Icons.analytics_rounded,
                      color: const Color(0xFF3B82F6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _buildTopProductsCard(primaryColor, currencyFmt, snapshot),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPeriodCard({
    required String title,
    required int sales,
    required int transactions,
    required Color color,
    required IconData icon,
    required NumberFormat currencyFmt,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.78)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white.withValues(alpha: 0.88), size: 15),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.88),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Rp ${currencyFmt.format(sales)}',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '$transactions transaksi',
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.78),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProductsCard(
    Color primaryColor,
    NumberFormat currencyFmt,
    ReportSummarySnapshot snapshot,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star_rounded, size: 17, color: primaryColor),
              const SizedBox(width: 8),
              const Text(
                'Top Products Bulan Ini',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (snapshot.topProducts.isEmpty)
            Text(
              'Belum ada data produk terlaris.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            )
          else
            ...snapshot.topProducts.asMap().entries.map((entry) {
              final index = entry.key;
              final product = entry.value;
              return Padding(
                padding: EdgeInsets.only(bottom: index == snapshot.topProducts.length - 1 ? 0 : 10),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${product.quantity} item',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Rp ${currencyFmt.format(product.revenue)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
