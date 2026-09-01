import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../stores/master_data_read_stores.dart';
import 'customer_list/edit_customer_dialog.dart';

class CustomerDetailPage extends StatefulWidget {
  const CustomerDetailPage({required this.customer, super.key});

  final CustomerListRecord customer;

  static Future<void> push(
    BuildContext context, {
    required CustomerListRecord customer,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CustomerDetailPage(customer: customer),
      ),
    );
  }

  @override
  State<CustomerDetailPage> createState() => _CustomerDetailPageState();
}

class _CustomerDetailPageState extends State<CustomerDetailPage> {
  late CustomerListRecord _customer;
  late Future<(CustomerStatsRecord, List<CustomerOrderHistoryRecord>)> _dataFuture;

  @override
  void initState() {
    super.initState();
    _customer = widget.customer;
    _loadData();
  }

  void _loadData() {
    _dataFuture = Future.wait([
      CustomerListStore.instance.loadCustomerStats(
        _customer.id,
        customerRemoteId: _customer.remoteId,
      ),
      CustomerListStore.instance.loadCustomerOrders(
        _customer.id,
        customerRemoteId: _customer.remoteId,
        limit: 20,
      ),
    ]).then((results) => (
          results[0] as CustomerStatsRecord,
          results[1] as List<CustomerOrderHistoryRecord>,
        ));
  }

  Future<void> _handleEdit() async {
    final updated = await EditCustomerDialog.show(context, customer: _customer);
    if (updated != null && mounted) {
      setState(() {
        _customer = updated;
        _loadData();
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: const Color(0x14000000),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: Color(0xFF374151),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Detail Pelanggan',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
            letterSpacing: -0.2,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: _handleEdit,
              icon: Icon(Icons.edit_outlined, size: 14, color: primary),
              label: Text(
                'Edit Profil',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: primary,
                ),
              ),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                      color: primary.withValues(alpha: 0.3), width: 1),
                ),
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<(CustomerStatsRecord, List<CustomerOrderHistoryRecord>)>(
        future: _dataFuture,
        builder: (context, snapshot) {
          final loading =
              snapshot.connectionState == ConnectionState.waiting;
          final stats = snapshot.data?.$1 ?? CustomerStatsRecord.empty;
          final orders = snapshot.data?.$2 ?? [];

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ProfileCard(
                        customer: _customer, primaryColor: primary),
                    const SizedBox(height: 10),
                    _StatsRow(
                      loading: loading,
                      orderCount: stats.totalOrders,
                      totalSpend: stats.totalSpend,
                      points: _customer.pointsBalance,
                      primaryColor: primary,
                    ),
                    const SizedBox(height: 16),
                    _HistorySection(
                      loading: loading,
                      error: snapshot.hasError
                          ? snapshot.error.toString()
                          : null,
                      orders: orders,
                      primaryColor: primary,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Profile card ─────────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.customer,
    required this.primaryColor,
  });

  final CustomerListRecord customer;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    final initial = customer.displayName.isNotEmpty
        ? customer.displayName[0].toUpperCase()
        : '?';

    final address = (customer.address ?? '').trim().isNotEmpty
        ? customer.address!.trim()
        : (customer.city ?? '').trim().isNotEmpty
            ? customer.city!.trim()
            : null;

    final hasContacts =
        (customer.phoneNumber ?? '').trim().isNotEmpty ||
        (customer.email ?? '').trim().isNotEmpty ||
        address != null;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Identity zone — tinted header ──────────────────────────────
          Container(
            color: primaryColor.withValues(alpha: 0.05),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primaryColor.withValues(alpha: 0.12),
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: primaryColor,
                        height: 1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 13),
                // Name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.displayName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                          letterSpacing: -0.2,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if ((customer.remoteId ?? '').isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'ID ${customer.remoteId}',
                          style: TextStyle(
                            fontSize: 10,
                            color: primaryColor.withValues(alpha: 0.5),
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Contact zone — white ────────────────────────────────────────
          if (hasContacts) ...[
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                children: [
                  if ((customer.phoneNumber ?? '').trim().isNotEmpty)
                    _ContactRow(
                      icon: Icons.phone_outlined,
                      label: 'Telepon',
                      value: customer.phoneNumber!.trim(),
                    ),
                  if ((customer.email ?? '').trim().isNotEmpty)
                    _ContactRow(
                      icon: Icons.alternate_email_rounded,
                      label: 'Email',
                      value: customer.email!.trim(),
                    ),
                  if (address != null)
                    _ContactRow(
                      icon: Icons.location_on_outlined,
                      label: 'Alamat',
                      value: address,
                      isLast: true,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 13, color: const Color(0xFFB0B8C4)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFB0B8C4),
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF374151),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stats row ────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.loading,
    required this.orderCount,
    required this.totalSpend,
    required this.points,
    required this.primaryColor,
  });

  final bool loading;
  final int orderCount;
  final double totalSpend;
  final int points;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final numFmt = NumberFormat('#,###', 'id_ID');

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _StatTile(
              icon: Icons.receipt_long_outlined,
              label: 'Total Transaksi',
              value: loading ? '-' : numFmt.format(orderCount),
              unit: loading || orderCount == 0 ? null : 'pesanan',
              color: const Color(0xFF2563EB),
              bg: const Color(0xFFEFF6FF),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatTile(
              icon: Icons.payments_outlined,
              label: 'Total Belanja',
              value: loading ? '-' : currencyFmt.format(totalSpend),
              color: const Color(0xFF059669),
              bg: const Color(0xFFECFDF5),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatTile(
              icon: Icons.stars_outlined,
              label: 'Saldo Poin',
              value: loading ? '-' : numFmt.format(points),
              unit: loading || points == 0 ? null : 'poin',
              color: const Color(0xFF7C3AED),
              bg: const Color(0xFFF5F3FF),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.bg,
    this.unit,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color bg;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: color.withValues(alpha: 0.85),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: -0.3,
                  ),
                ),
                if (unit != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    unit!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: color.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── History section ──────────────────────────────────────────────────────────

class _HistorySection extends StatelessWidget {
  const _HistorySection({
    required this.loading,
    required this.orders,
    required this.primaryColor,
    this.error,
  });

  final bool loading;
  final List<CustomerOrderHistoryRecord> orders;
  final Color primaryColor;
  final String? error;

  static const _statusStyle = {
    1: (Color(0xFF1D4ED8), Color(0xFFEFF6FF)),  // Aktif
    2: (Color(0xFF15803D), Color(0xFFF0FDF4)),  // Selesai
    3: (Color(0xFFD97706), Color(0xFFFFFBEB)),  // Sebagian
    4: (Color(0xFFEA580C), Color(0xFFFFF7ED)),  // Jatuh Tempo
    5: (Color(0xFF6B7280), Color(0xFFF3F4F6)),  // Dibatalkan
    6: (Color(0xFF7C3AED), Color(0xFFFAF5FF)),  // Diparkir
  };

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final dateFmt = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Row(
            children: [
              const Text(
                'Riwayat Transaksi',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF374151),
                  letterSpacing: -0.1,
                ),
              ),
              if (!loading && orders.isNotEmpty) ...[
                const SizedBox(width: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${orders.length}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: primaryColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Card container
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: _buildContent(currencyFmt, dateFmt),
        ),
      ],
    );
  }

  Widget _buildContent(NumberFormat currencyFmt, DateFormat dateFmt) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          'Gagal memuat riwayat transaksi.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
      );
    }
    if (orders.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.receipt_long_outlined,
                  size: 28, color: Colors.grey.shade300),
              const SizedBox(height: 8),
              Text(
                'Belum ada transaksi',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: orders.length,
      separatorBuilder: (_, _) => const Divider(
        height: 1,
        thickness: 1,
        indent: 16,
        endIndent: 0,
        color: Color(0xFFF3F4F6),
      ),
      itemBuilder: (context, i) {
        final o = orders[i];
        final (Color fg, Color bg) =
            _statusStyle[o.statusCode] ?? _statusStyle[2]!;
        return _HistoryRow(
          order: o,
          fg: fg,
          bg: bg,
          currencyFmt: currencyFmt,
          dateFmt: dateFmt,
        );
      },
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.order,
    required this.fg,
    required this.bg,
    required this.currencyFmt,
    required this.dateFmt,
  });

  final CustomerOrderHistoryRecord order;
  final Color fg;
  final Color bg;
  final NumberFormat currencyFmt;
  final DateFormat dateFmt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: number + items
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.formattedNumber,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(Icons.schedule_rounded,
                        size: 10, color: Colors.grey.shade400),
                    const SizedBox(width: 3),
                    Text(
                      order.orderDate != null
                          ? dateFmt.format(order.orderDate!)
                          : '-',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                if (order.itemsSummary != '-') ...[
                  const SizedBox(height: 2),
                  Text(
                    order.itemsSummary,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Right: total + status
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                currencyFmt.format(order.totalAmount),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  order.statusLabel,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
