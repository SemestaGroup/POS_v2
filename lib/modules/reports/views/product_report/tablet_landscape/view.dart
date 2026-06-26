import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../stores/report_read_stores.dart';

class ProductReportView extends StatefulWidget {
  const ProductReportView({super.key});

  @override
  State<ProductReportView> createState() => _ProductReportViewState();
}

class _ProductReportViewState extends State<ProductReportView> {
  final ProductReportStore _store = ProductReportStore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _store.refresh(period: _store.snapshotNotifier.value.period);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat('#,###', 'id_ID');
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return ValueListenableBuilder<ProductReportSnapshot>(
      valueListenable: _store.snapshotNotifier,
      builder: (context, snapshot, _) {
        final filtered = snapshot.stats.where((stat) {
          if (_searchQuery.isEmpty) return true;
          return stat.name.toLowerCase().contains(_searchQuery.toLowerCase());
        }).toList(growable: false);
        final totalQty = filtered.fold(0, (sum, item) => sum + item.totalQuantity);
        final totalRevenue =
            filtered.fold(0, (sum, item) => sum + item.totalRevenue);

        if (snapshot.isLoading && snapshot.stats.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.errorMessage != null && snapshot.stats.isEmpty) {
          return Center(
            child: Text(
              snapshot.errorMessage!,
              style: TextStyle(color: Colors.red.shade600),
            ),
          );
        }

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              color: Colors.white,
              child: Row(
                children: [
                  _buildPeriodChip('Hari Ini', 'today', primaryColor, snapshot),
                  const SizedBox(width: 6),
                  _buildPeriodChip('7 Hari', 'week', primaryColor, snapshot),
                  const SizedBox(width: 6),
                  _buildPeriodChip('Bulan Ini', 'month', primaryColor, snapshot),
                  const SizedBox(width: 14),
                  Expanded(
                    child: SizedBox(
                      height: 34,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) => setState(() => _searchQuery = value),
                        decoration: InputDecoration(
                          hintText: 'Cari produk...',
                          hintStyle: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade400,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            size: 16,
                            color: Colors.grey.shade400,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(color: primaryColor),
                          ),
                        ),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed: () => _store.refresh(period: snapshot.period),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    color: primaryColor,
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.grey.shade100),
            Container(
              color: primaryColor.withValues(alpha: 0.04),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  _buildStrip('Produk', '${filtered.length}', primaryColor),
                  _buildDivider(),
                  _buildStrip('Total Terjual', '$totalQty item', const Color(0xFF8B5CF6)),
                  _buildDivider(),
                  _buildStrip('Total Pendapatan', 'Rp ${currencyFmt.format(totalRevenue)}', const Color(0xFF10B981)),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.grey.shade100),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFF9FAFB),
              child: const Row(
                children: [
                  _ProductHeader('#', 1),
                  _ProductHeader('Produk', 5),
                  _ProductHeader('Qty', 2),
                  _ProductHeader('Avg Harga', 2),
                  _ProductHeader('Pendapatan', 2),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.grey.shade100),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'Tidak ada data produk.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => Divider(height: 1, color: Colors.grey.shade100),
                      itemBuilder: (context, index) {
                        final stat = filtered[index];
                        return Container(
                          color: index.isOdd ? Colors.transparent : const Color(0xFFFAFAFB),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(
                            children: [
                              _ProductCell('${index + 1}', 1, muted: true),
                              _ProductCell(stat.name, 5, bold: true),
                              _ProductCell('${stat.totalQuantity} item', 2),
                              _ProductCell('Rp ${currencyFmt.format(stat.averagePrice)}', 2),
                              _ProductCell('Rp ${currencyFmt.format(stat.totalRevenue)}', 2, bold: true),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPeriodChip(String label, String value, Color primaryColor, ProductReportSnapshot snapshot) {
    final isActive = snapshot.period == value;
    return InkWell(
      onTap: () => _store.refresh(period: value),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? primaryColor : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: isActive ? primaryColor : Colors.grey.shade200),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isActive ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildStrip(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() => Container(
        width: 1,
        height: 28,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        color: const Color(0xFFE5E7EB),
      );
}

class _ProductHeader extends StatelessWidget {
  const _ProductHeader(this.label, this.flex);

  final String label;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)),
      ),
    );
  }
}

class _ProductCell extends StatelessWidget {
  const _ProductCell(this.value, this.flex, {this.bold = false, this.muted = false});

  final String value;
  final int flex;
  final bool bold;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        value,
        style: TextStyle(
          fontSize: 11,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          color: muted ? Colors.grey.shade400 : const Color(0xFF374151),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
