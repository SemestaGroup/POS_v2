import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../../../../l10n/app_localizations.dart';
import '../../../../../../core/services/sync/pos_v2_customer_service.dart';
import '../../../../../../core/services/sync/pos_v2_runtime_session_store.dart';
import '../../../../../../core/services/sync/pos_v2_sync_orchestrator.dart';
import '../../../../../../core/services/local/database_service.dart';
import '../../../../../operations/shift/models/active_shift_store.dart';
import '../../../../shared/models/pos_catalog_store.dart';
import '../../../../shared/models/pos_promotion_service.dart';
import '../../../../shared/models/sales_order_store.dart';
import '../../../../shared/models/pos_tax_selection_resolver.dart';
import '../../../../shared/widgets/customer_picker_dialog.dart';
import '../../../../../../core/printing/models/printer_render_models.dart';
import '../../../../../../core/printing/services/printer_rendering_service.dart';
import '../../../../../../core/printing/services/printer_transport_service.dart';
import '../../../../../settings/printers/controllers/printer_settings_controller.dart';
import '../../../../../operations/shift/services/expense_service.dart';
import '../../../../../operations/shift/widgets/kas_keluar_dialog.dart';
import '../../../../../operations/shift/widgets/kas_masuk_dialog.dart';
import '../../../../../../core/services/sync/pos_v2_options_service.dart';
import '../../../widgets/pos_settings_dialog.dart';

enum _MobilePosStage { catalog, cart, payment }

enum _MobilePosQuickAction {
  discount,
  clearOrder,
  cancelOrder,
  cashIn,
  cashOut,
  syncData,
  closeOutlet,
  settings,
}

class _MobilePosQuickActionItem {
  const _MobilePosQuickActionItem({
    required this.value,
    required this.icon,
    required this.label,
    this.isDestructive = false,
  });

  final _MobilePosQuickAction value;
  final IconData icon;
  final String label;
  final bool isDestructive;
}

class _PosCartItem {
  const _PosCartItem({
    required this.id,
    required this.name,
    required this.displayName,
    required this.imageUrl,
    required this.regularUnitPrice,
    required this.quantity,
    this.productRemoteId,
    this.brandName,
    this.discountedUnitPrice,
    this.promoLabel,
    this.isDiscountEnabled = false,
    this.orderType,
    this.note,
    this.appliedPromoId,
    this.appliedPromoName,
    this.overriddenUnitPrice,
  });

  final String id;
  final String name;
  final String displayName;
  final String imageUrl;
  final int regularUnitPrice;
  final int quantity;
  final String? productRemoteId;
  final String? brandName;
  final int? discountedUnitPrice;
  final String? promoLabel;
  final bool isDiscountEnabled;
  final String? orderType;
  final String? note;
  final String? appliedPromoId;
  final String? appliedPromoName;
  final int? overriddenUnitPrice;

  int get activeUnitPrice {
    if (overriddenUnitPrice != null) {
      return overriddenUnitPrice!;
    }
    return isDiscountEnabled && discountedUnitPrice != null
        ? discountedUnitPrice!
        : regularUnitPrice;
  }

  _PosCartItem copyWith({
    String? id,
    String? name,
    String? displayName,
    String? imageUrl,
    int? regularUnitPrice,
    int? quantity,
    String? productRemoteId,
    String? brandName,
    int? discountedUnitPrice,
    String? promoLabel,
    bool? isDiscountEnabled,
    String? orderType,
    String? note,
    bool clearNote = false,
    String? appliedPromoId,
    bool clearAppliedPromoId = false,
    String? appliedPromoName,
    bool clearAppliedPromoName = false,
    int? overriddenUnitPrice,
    bool clearOverriddenUnitPrice = false,
    bool clearDiscountedUnitPrice = false,
    bool clearPromoLabel = false,
  }) {
    return _PosCartItem(
      id: id ?? this.id,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      imageUrl: imageUrl ?? this.imageUrl,
      regularUnitPrice: regularUnitPrice ?? this.regularUnitPrice,
      quantity: quantity ?? this.quantity,
      productRemoteId: productRemoteId ?? this.productRemoteId,
      brandName: brandName ?? this.brandName,
      promoLabel: clearPromoLabel ? null : (promoLabel ?? this.promoLabel),
      isDiscountEnabled: isDiscountEnabled ?? this.isDiscountEnabled,
      orderType: orderType ?? this.orderType,
      note: clearNote ? null : (note ?? this.note),
      appliedPromoId: clearAppliedPromoId
          ? null
          : (appliedPromoId ?? this.appliedPromoId),
      appliedPromoName: clearAppliedPromoName
          ? null
          : (appliedPromoName ?? this.appliedPromoName),
      overriddenUnitPrice: clearOverriddenUnitPrice
          ? null
          : (overriddenUnitPrice ?? this.overriddenUnitPrice),
      discountedUnitPrice: clearDiscountedUnitPrice
          ? null
          : (discountedUnitPrice ?? this.discountedUnitPrice),
    );
  }
}

class _MobileOrdersPage extends StatefulWidget {
  const _MobileOrdersPage();

  @override
  State<_MobileOrdersPage> createState() => _MobileOrdersPageState();
}

class _MobileOrdersPageState extends State<_MobileOrdersPage> {
  int _selectedTab = 0;

  List<SalesOrderRecord> _ordersForTab(List<SalesOrderRecord> orders) {
    final result = orders
        .where((order) {
          switch (_selectedTab) {
            case 1:
              return order.statusCode == 6;
            case 2:
              return order.statusCode != 1 && order.statusCode != 6;
            case 0:
            default:
              return order.statusCode == 1;
          }
        })
        .toList(growable: false);
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  int _countForTab(List<SalesOrderRecord> orders, int index) {
    return orders.where((order) {
      switch (index) {
        case 1:
          return order.statusCode == 6;
        case 2:
          return order.statusCode != 1 && order.statusCode != 6;
        case 0:
        default:
          return order.statusCode == 1;
      }
    }).length;
  }

  String _formatCurrency(int amount) => NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  ).format(amount);

  String _formatOrderType(String orderType) {
    switch (orderType) {
      case 'take_away':
        return 'Bawa pulang';
      case 'shopee_food':
        return 'ShopeeFood';
      case 'go_food':
        return 'GoFood';
      case 'grab_food':
        return 'GrabFood';
      case 'dine_in':
      default:
        return 'Makan di tempat';
    }
  }

  (String, Color, IconData) _statusMeta(
    SalesOrderRecord order,
    Color primaryColor,
  ) {
    switch (order.statusCode) {
      case 6:
        return ('Ditahan', const Color(0xFFB45309), Icons.pause_rounded);
      case 2:
        return ('Selesai', const Color(0xFF15803D), Icons.check_rounded);
      case 4:
        return (
          'Bermasalah',
          const Color(0xFFB45309),
          Icons.error_outline_rounded,
        );
      case 5:
        return ('Dibatalkan', const Color(0xFFB91C1C), Icons.close_rounded);
      case 1:
        return ('Aktif', primaryColor, Icons.receipt_long_outlined);
      default:
        return ('Tercatat', const Color(0xFF475569), Icons.history_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        scrolledUnderElevation: 0,
        title: const Text(
          'Pesanan',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Muat ulang pesanan',
            onPressed: () async {
              await SalesOrderStore.instance.refreshFromPersistence();
            },
            icon: const Icon(
              Icons.refresh_rounded,
              color: Color(0xFF475569),
              size: 20,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ValueListenableBuilder<List<SalesOrderRecord>>(
        valueListenable: SalesOrderStore.instance.recordsNotifier,
        builder: (context, orders, _) {
          final visibleOrders = _ordersForTab(orders);
          return Column(
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    _buildTabButton(
                      label: 'Aktif',
                      count: _countForTab(orders, 0),
                      index: 0,
                      primaryColor: primaryColor,
                    ),
                    const SizedBox(width: 7),
                    _buildTabButton(
                      label: 'Lanjutkan',
                      count: _countForTab(orders, 1),
                      index: 1,
                      primaryColor: primaryColor,
                    ),
                    const SizedBox(width: 7),
                    _buildTabButton(
                      label: 'Riwayat',
                      count: _countForTab(orders, 2),
                      index: 2,
                      primaryColor: primaryColor,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: visibleOrders.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                        itemCount: visibleOrders.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) => _buildOrderRow(
                          context,
                          order: visibleOrders[index],
                          primaryColor: primaryColor,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required int count,
    required int index,
    required Color primaryColor,
  }) {
    final selected = _selectedTab == index;
    return Expanded(
      child: Material(
        color: selected ? primaryColor.withValues(alpha: 0.10) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () => setState(() => _selectedTab = index),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(
                color: selected ? primaryColor : const Color(0xFFE2E8F0),
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? primaryColor : const Color(0xFF475569),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  '$count',
                  style: TextStyle(
                    color: selected ? primaryColor : const Color(0xFF94A3B8),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final (title, subtitle, icon) = switch (_selectedTab) {
      1 => (
        'Belum ada pesanan untuk dilanjutkan',
        'Pesanan yang ditahan akan tampil di sini.',
        Icons.pause_circle_outline_rounded,
      ),
      2 => (
        'Belum ada riwayat hari ini',
        'Pesanan selesai atau dibatalkan akan tampil di sini.',
        Icons.history_rounded,
      ),
      _ => (
        'Belum ada pesanan aktif',
        'Pesanan yang sedang diproses akan tampil di sini.',
        Icons.receipt_long_outlined,
      ),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF94A3B8), size: 36),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF334155),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderRow(
    BuildContext context, {
    required SalesOrderRecord order,
    required Color primaryColor,
  }) {
    final (statusLabel, statusColor, statusIcon) = _statusMeta(
      order,
      primaryColor,
    );
    final canResume = order.statusCode == 1 || order.statusCode == 6;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: canResume
            ? () {
                SalesOrderStore.instance.resumeOrder(order);
                Navigator.pop(context);
              }
            : () => _showHistoryDetails(context, order, primaryColor),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE5EAF2)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(statusIcon, color: statusColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            order.customerName.isEmpty
                                ? 'Walk-in'
                                : order.customerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF1E293B),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatCurrency(order.totalAmount),
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${order.token} · ${order.totalQuantity} item · ${_formatOrderType(order.orderType)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          DateFormat(
                            'dd MMM · HH:mm',
                            'id_ID',
                          ).format(order.createdAt),
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (canResume) ...[
                const SizedBox(width: 7),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF94A3B8),
                  size: 20,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showHistoryDetails(
    BuildContext context,
    SalesOrderRecord order,
    Color primaryColor,
  ) {
    final (statusLabel, statusColor, _) = _statusMeta(order, primaryColor);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: FractionallySizedBox(
          heightFactor: 0.82,
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFFFAFCFF),
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.receipt_long_outlined,
                          color: statusColor,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.customerName.isEmpty
                                  ? 'Walk-in'
                                  : order.customerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF1E293B),
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${order.token} · ${DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(order.createdAt)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                Expanded(
                  child: order.items.isEmpty
                      ? const Center(
                          child: Text(
                            'Detail item belum tersedia untuk pesanan ini.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 11,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                          itemCount: order.items.length,
                          separatorBuilder: (_, _) => const Divider(
                            height: 16,
                            color: Color(0xFFEEF2F7),
                          ),
                          itemBuilder: (context, index) {
                            final item = order.items[index];
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  constraints: const BoxConstraints(
                                    minWidth: 28,
                                    minHeight: 28,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF4FF),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${item.quantity}×',
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: const TextStyle(
                                          color: Color(0xFF334155),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if (item.note?.isNotEmpty == true) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          item.note!,
                                          style: const TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 10,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formatCurrency(item.totalPrice),
                                  style: const TextStyle(
                                    color: Color(0xFF334155),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Column(
                    children: [
                      _buildDetailTotalRow(
                        'Subtotal',
                        _formatCurrency(order.subtotalAmount),
                      ),
                      if (order.orderLevelDiscountAmount > 0) ...[
                        const SizedBox(height: 7),
                        _buildDetailTotalRow(
                          'Diskon',
                          '- ${_formatCurrency(order.orderLevelDiscountAmount)}',
                          valueColor: const Color(0xFFB91C1C),
                        ),
                      ],
                      if (order.taxAmount > 0) ...[
                        const SizedBox(height: 7),
                        _buildDetailTotalRow(
                          order.taxName ?? 'Pajak',
                          _formatCurrency(order.taxAmount),
                        ),
                      ],
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(height: 1, color: Color(0xFFEEF2F7)),
                      ),
                      _buildDetailTotalRow(
                        'Total pembayaran',
                        _formatCurrency(order.totalAmount),
                        bold: true,
                        valueColor: primaryColor,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: FilledButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          style: FilledButton.styleFrom(
                            backgroundColor: primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Tutup'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailTotalRow(
    String label,
    String value, {
    bool bold = false,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: const Color(0xFF64748B),
            fontSize: bold ? 12 : 11,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? const Color(0xFF334155),
            fontSize: bold ? 13 : 11,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class PosWorkspaceMobileView extends StatefulWidget {
  const PosWorkspaceMobileView({super.key, this.isReadOnly = false});

  final bool isReadOnly;

  @override
  State<PosWorkspaceMobileView> createState() => _PosWorkspaceMobileViewState();
}

class _PosWorkspaceMobileViewState extends State<PosWorkspaceMobileView> {
  _MobilePosStage _currentStage = _MobilePosStage.catalog;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _manualTenderController = TextEditingController();

  List<_PosCartItem> _cartItems = [];
  int _lineSequence = 1;
  int _orderLevelDiscountAmount = 0;
  String _selectedOrderType = 'dine_in';
  String _orderNote = '';
  List<PosPromotionResult> _selectedPromotions = [];

  String? _editingOrderId;
  String? _editingOrderToken;
  DateTime? _editingOrderCreatedAt;

  String? _selectedBrandName;
  String? _selectedCategoryName;
  PosCustomerRecord? _selectedCustomer;
  PosCatalogSnapshot _catalogSnapshot = const PosCatalogSnapshot();

  // Payment stage specific states
  SalesPaymentModeOption? _selectedPaymentOption;
  List<SalesPaymentModeOption> _paymentOptions = const [];
  int _tenderAmount = 0;
  String? _paymentErrorMessage;
  bool _isCommitting = false;
  bool _isPromoFilterActive = false;
  bool _isSyncingQuickData = false;

  bool _isTaxSettingsLoading = true;
  bool _autoTax = false;
  double _taxPercentage = 0.0;
  String? _taxName;

  Future<void> _loadTaxSettings() async {
    if (mounted && !_isTaxSettingsLoading) {
      setState(() => _isTaxSettingsLoading = true);
    }

    var autoTax = false;
    var taxPercentage = 0.0;
    String? taxName;

    try {
      final options = await PosV2OptionsService.instance.getLocalOptions();
      final raw = options['pos_app_settings'];
      Map<String, dynamic> appSettings = {};
      try {
        if (raw is Map) {
          appSettings = Map<String, dynamic>.from(raw);
        } else if (raw is String && raw.isNotEmpty) {
          appSettings = jsonDecode(raw) as Map<String, dynamic>;
        }
      } catch (_) {}

      final taxSetting = appSettings['tax'] is Map<String, dynamic>
          ? appSettings['tax'] as Map<String, dynamic>
          : <String, dynamic>{};

      autoTax = taxSetting['auto_tax'] ?? false;
      final selectedTaxId = taxSetting['tax_id']?.toString();

      if (autoTax) {
        final taxSelection = await PosTaxSelectionResolver.resolve(
          autoTax: autoTax,
          selectedTaxId: selectedTaxId,
        );
        autoTax = taxSelection.isEnabled;
        taxName = taxSelection.name;
        taxPercentage = taxSelection.percentage;
        if (taxSelection.issue != null) {
          debugPrint('[POS_TAX_LOG] ${taxSelection.issue}');
        }
      }
    } catch (error) {
      debugPrint('[POS_TAX_LOG] Failed to load tax settings: $error');
    }

    if (mounted) {
      setState(() {
        _isTaxSettingsLoading = false;
        _autoTax = autoTax;
        _taxPercentage = taxPercentage;
        _taxName = taxName;
      });
      debugPrint(
        '[POS_TAX_LOG] Loaded Tax Settings (Mobile): autoTax=$_autoTax, taxName=$_taxName, taxRate=$_taxPercentage%',
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _catalogSnapshot = PosCatalogStore.instance.snapshotNotifier.value;
    PosCatalogStore.instance.snapshotNotifier.addListener(
      _handleCatalogChanged,
    );
    SalesOrderStore.instance.resumeOrderNotifier.addListener(
      _handlePendingResumeOrder,
    );
    _handlePendingResumeOrder();
    _ensureDefaultCustomerSelected();
    _loadTaxSettings();
  }

  @override
  void dispose() {
    PosCatalogStore.instance.snapshotNotifier.removeListener(
      _handleCatalogChanged,
    );
    SalesOrderStore.instance.resumeOrderNotifier.removeListener(
      _handlePendingResumeOrder,
    );
    _searchController.dispose();
    _manualTenderController.dispose();
    super.dispose();
  }

  void _handleCatalogChanged() {
    if (mounted) {
      setState(() {
        _catalogSnapshot = PosCatalogStore.instance.snapshotNotifier.value;
      });
    }
  }

  void _handlePendingResumeOrder() {
    final pendingOrder = SalesOrderStore.instance.resumeOrderNotifier.value;
    if (pendingOrder == null) return;

    final productIndex = <String, Map<String, dynamic>>{};
    for (final product in _catalogSnapshot.products) {
      final remoteId = product['remoteId']?.toString();
      if (remoteId != null && remoteId.isNotEmpty) {
        productIndex[remoteId] = product;
      }
    }

    final matchItems = pendingOrder.items
        .where(
          (item) =>
              item.productRemoteId != null && item.productRemoteId!.isNotEmpty,
        )
        .map((item) {
          final metadata =
              productIndex[item.productRemoteId!] ?? const <String, dynamic>{};
          final categoryId = metadata['categoryRemoteId']?.toString();
          final brandId = metadata['brandRemoteId']?.toString();
          final parsedDiscounted = item.discountedUnitPrice;

          return PosPromotionMatchItem(
            refId: item.id,
            productRemoteId: item.productRemoteId!,
            productName: item.name,
            categoryRemoteId: categoryId,
            brandRemoteId: brandId,
            activeUnitPrice: parsedDiscounted ?? item.regularUnitPrice,
            quantity: item.quantity,
          );
        })
        .toList();

    PosPromotionService.instance
        .getApplicablePromotions(
          items: matchItems,
          orderTypeCode: _toBackendOrderTypeCode(pendingOrder.orderType),
        )
        .then((applicablePromos) {
          PosPromotionResult? actualPromo;
          if (pendingOrder.appliedPromotionRemoteId != null &&
              pendingOrder.appliedPromotionRemoteId!.isNotEmpty) {
            try {
              actualPromo = applicablePromos.firstWhere(
                (p) => p.remoteId == pendingOrder.appliedPromotionRemoteId,
              );
            } catch (_) {}
          }

          if (mounted) {
            setState(() {
              _cartItems = pendingOrder.items
                  .map(
                    (item) => _PosCartItem(
                      id: item.id,
                      name: item.name,
                      displayName: item.name,
                      imageUrl: item.imageUrl,
                      regularUnitPrice: item.regularUnitPrice,
                      quantity: item.quantity,
                      productRemoteId: item.productRemoteId,
                      discountedUnitPrice: item.discountedUnitPrice,
                      promoLabel: item.promoLabel,
                      isDiscountEnabled: item.isDiscountEnabled,
                      orderType: item.orderType,
                      note: item.note,
                    ),
                  )
                  .toList();

              _selectedOrderType = pendingOrder.orderType;
              _orderNote = pendingOrder.note ?? '';
              _editingOrderId = pendingOrder.id;
              _editingOrderToken = pendingOrder.token;
              _editingOrderCreatedAt = pendingOrder.createdAt;
              _orderLevelDiscountAmount = pendingOrder.orderLevelDiscountAmount;
              _selectedPromotions = actualPromo == null ? [] : [actualPromo];
              _currentStage = _MobilePosStage.cart;

              if (pendingOrder.customerName.isNotEmpty &&
                  pendingOrder.customerName != '-') {
                _selectedCustomer = PosCustomerRecord(
                  localId: pendingOrder.customerLocalId,
                  remoteId: pendingOrder.customerRemoteId,
                  name: pendingOrder.customerName,
                  phone: pendingOrder.customerPhone,
                  address: pendingOrder.customerAddress,
                  isDefaultWalkIn:
                      pendingOrder.customerName ==
                      PosV2CustomerService.defaultWalkInName,
                );
              }
            });
            _recalculateCartPromotions();
            SalesOrderStore.instance.clearPendingResumeOrder();
          }
        });
  }

  Future<void> _ensureDefaultCustomerSelected() async {
    if (_selectedCustomer != null) return;
    try {
      final defaultCustomer = await PosV2CustomerService.instance
          .ensureDefaultWalkInCustomer();
      if (mounted) {
        setState(() {
          _selectedCustomer = defaultCustomer;
        });
      }
    } catch (_) {}
  }

  String _newLineId() => 'line-${_lineSequence++}';

  int get _subtotalAmount => _cartItems.fold(
    0,
    (sum, item) => sum + (item.activeUnitPrice * item.quantity),
  );
  int get _taxAmount {
    if (!_autoTax || _taxPercentage <= 0) return 0;
    final base = (_subtotalAmount - _orderLevelDiscountAmount).clamp(
      0,
      1 << 31,
    );
    return (base * (_taxPercentage / 100)).round();
  }

  int get _totalPay =>
      ((_subtotalAmount - _orderLevelDiscountAmount).clamp(0, 1 << 31)) +
      _taxAmount;

  String _formatCurrency(int amount) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  String _toBackendOrderTypeCode(String localOrderType) {
    switch (localOrderType) {
      case 'take_away':
        return 'takeaway';
      case 'shopee_food':
        return 'shopeefood';
      case 'go_food':
        return 'gofood';
      case 'grab_food':
        return 'grabfood';
      case 'dine_in':
      default:
        return 'dinein';
    }
  }

  int _parsePriceValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(
          value?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '',
        ) ??
        0;
  }

  Map<String, dynamic> _applySelectedOrderTypePricing(
    Map<String, dynamic> product,
  ) => _applyOrderTypePricing(product, _selectedOrderType);

  Map<String, dynamic> _applyOrderTypePricing(
    Map<String, dynamic> product,
    String orderType,
  ) {
    final mapped = Map<String, dynamic>.from(product);
    final rawOrderTypePrices = mapped['orderTypePrices'];
    final selectedPrice = rawOrderTypePrices is Map
        ? _parsePriceValue(
            rawOrderTypePrices[_toBackendOrderTypeCode(orderType)],
          )
        : 0;
    if (selectedPrice <= 0) return mapped;

    final originalRegularPrice = _parsePriceValue(
      mapped['regularPrice'] ?? mapped['price'],
    );
    final currentDiscountedPrice = _parsePriceValue(mapped['discountedPrice']);
    final hasCatalogDiscount =
        currentDiscountedPrice > 0 &&
        originalRegularPrice > currentDiscountedPrice;
    final adjustedDiscountedPrice = hasCatalogDiscount
        ? (selectedPrice - (originalRegularPrice - currentDiscountedPrice))
              .clamp(0, selectedPrice)
        : null;

    mapped['regularPrice'] = selectedPrice;
    mapped['discountedPrice'] = adjustedDiscountedPrice;
    mapped['price'] = adjustedDiscountedPrice ?? selectedPrice;
    return mapped;
  }

  void _addProductToCart(Map<String, dynamic> product) {
    FocusManager.instance.primaryFocus?.unfocus();
    final pricedProduct = _applySelectedOrderTypePricing(product);
    final name = pricedProduct['name'] as String;
    final regularUnitPrice = _parsePriceValue(
      pricedProduct['regularPrice'] ?? pricedProduct['price'],
    );
    final discountedPrice = _parsePriceValue(pricedProduct['discountedPrice']);
    final discountedUnitPrice = discountedPrice > 0 ? discountedPrice : null;

    final currentIndex = _cartItems.indexWhere(
      (item) =>
          item.name == name &&
          item.orderType == _selectedOrderType &&
          item.appliedPromoId == null,
    );

    setState(() {
      if (currentIndex >= 0) {
        final currentItem = _cartItems[currentIndex];
        _cartItems[currentIndex] = currentItem.copyWith(
          quantity: currentItem.quantity + 1,
        );
      } else {
        _cartItems.insert(
          0,
          _PosCartItem(
            id: _newLineId(),
            name: name,
            displayName:
                pricedProduct['description']?.toString().trim().isNotEmpty ==
                    true
                ? pricedProduct['description'].toString().trim()
                : name,
            imageUrl:
                pricedProduct['image'] as String? ??
                pricedProduct['imageUrl'] as String? ??
                '',
            regularUnitPrice: regularUnitPrice,
            quantity: 1,
            productRemoteId: pricedProduct['remoteId'] as String?,
            brandName: pricedProduct['brandName']?.toString(),
            discountedUnitPrice: discountedUnitPrice,
            promoLabel: pricedProduct['promo'] as String?,
            isDiscountEnabled: discountedUnitPrice != null,
            orderType: _selectedOrderType,
          ),
        );
      }
    });
    _recalculateCartPromotions();
  }

  void _onChangeQuantity(String itemId, int qty) {
    if (qty <= 0) {
      setState(() {
        _cartItems.removeWhere((item) => item.id == itemId);
      });
      _recalculateCartPromotions();
      return;
    }
    final index = _cartItems.indexWhere((item) => item.id == itemId);
    if (index >= 0) {
      setState(() {
        _cartItems[index] = _cartItems[index].copyWith(quantity: qty);
      });
      _recalculateCartPromotions();
    }
  }

  void _replaceCartItem(String itemId, _PosCartItem item) {
    final index = _cartItems.indexWhere((entry) => entry.id == itemId);
    if (index < 0) return;

    setState(() => _cartItems[index] = item);
    _recalculateCartPromotions();
  }

  void _splitCartItem(
    String itemId, {
    required int totalQuantity,
    required int splitQuantity,
    required String orderType,
    required String? note,
    required bool isDiscountEnabled,
  }) {
    final index = _cartItems.indexWhere((entry) => entry.id == itemId);
    if (index < 0 || totalQuantity < 2) {
      _showFeedback('Jumlah item minimal 2 untuk dipisahkan.');
      return;
    }

    final currentItem = _cartItems[index];
    final safeSplitQuantity = splitQuantity.clamp(1, totalQuantity - 1);
    final remainingQuantity = totalQuantity - safeSplitQuantity;

    setState(() {
      _cartItems[index] = currentItem.copyWith(
        quantity: remainingQuantity,
        orderType: orderType,
        note: note,
        clearNote: note == null || note.isEmpty,
        isDiscountEnabled: isDiscountEnabled,
      );
      _cartItems.insert(
        index + 1,
        currentItem.copyWith(
          id: _newLineId(),
          quantity: safeSplitQuantity,
          orderType: orderType,
          note: note,
          clearNote: note == null || note.isEmpty,
          isDiscountEnabled: isDiscountEnabled,
        ),
      );
    });
    _recalculateCartPromotions();
  }

  void _recalculateCartPromotions() {
    setState(() {
      final productIndex = <String, Map<String, dynamic>>{};
      for (final product in _catalogSnapshot.products) {
        final remoteId = product['remoteId']?.toString();
        if (remoteId != null && remoteId.isNotEmpty) {
          productIndex[remoteId] = product;
        }
      }

      final rawItems = <_PosCartItem>[];
      for (final item in _cartItems) {
        final catalogProduct = item.productRemoteId != null
            ? productIndex[item.productRemoteId!]
            : null;
        final pricedProduct = catalogProduct == null
            ? null
            : _applyOrderTypePricing(
                catalogProduct,
                item.orderType ?? _selectedOrderType,
              );
        final catalogRegularPrice = _parsePriceValue(
          pricedProduct?['regularPrice'] ?? pricedProduct?['price'],
        );
        final catalogDiscountedPrice = _parsePriceValue(
          pricedProduct?['discountedPrice'],
        );
        final originalDiscountedPrice = catalogDiscountedPrice > 0
            ? catalogDiscountedPrice
            : null;
        final originalPromoLabel = pricedProduct?['promo'] as String?;

        final cleanItem = item.copyWith(
          regularUnitPrice: catalogRegularPrice > 0
              ? catalogRegularPrice
              : item.regularUnitPrice,
          clearAppliedPromoId: true,
          clearAppliedPromoName: true,
          clearOverriddenUnitPrice: true,
          clearDiscountedUnitPrice: originalDiscountedPrice == null,
          clearPromoLabel: originalPromoLabel == null,
          discountedUnitPrice: originalDiscountedPrice,
          promoLabel: originalPromoLabel,
          isDiscountEnabled: originalDiscountedPrice != null,
        );

        final index = rawItems.indexWhere(
          (r) =>
              r.name == cleanItem.name &&
              r.productRemoteId == cleanItem.productRemoteId &&
              r.orderType == cleanItem.orderType &&
              r.note == cleanItem.note &&
              r.isDiscountEnabled == cleanItem.isDiscountEnabled,
        );
        if (index >= 0) {
          rawItems[index] = rawItems[index].copyWith(
            quantity: rawItems[index].quantity + cleanItem.quantity,
          );
        } else {
          rawItems.add(cleanItem);
        }
      }

      final matchItems = rawItems
          .where(
            (item) =>
                item.productRemoteId != null &&
                item.productRemoteId!.isNotEmpty,
          )
          .map((item) {
            final metadata =
                productIndex[item.productRemoteId!] ??
                const <String, dynamic>{};
            return PosPromotionMatchItem(
              refId: item.id,
              productRemoteId: item.productRemoteId!,
              productName: item.name,
              categoryRemoteId: metadata['categoryRemoteId']?.toString(),
              brandRemoteId: metadata['brandRemoteId']?.toString(),
              activeUnitPrice: item.activeUnitPrice,
              quantity: item.quantity,
            );
          })
          .toList();

      final allocation = PosPromotionService.instance.allocatePromotions(
        items: matchItems,
        selectedPromotions: _selectedPromotions,
      );

      final nextCartItems = <_PosCartItem>[];
      for (final allocated in allocation.allocatedItems) {
        final rawItem = rawItems.firstWhere((r) => r.id == allocated.refId);
        nextCartItems.add(
          rawItem.copyWith(
            id: _newLineId(),
            quantity: allocated.quantity,
            appliedPromoId: allocated.appliedPromoId,
            appliedPromoName: allocated.appliedPromoName,
            overriddenUnitPrice: allocated.overriddenUnitPrice,
          ),
        );
      }

      for (final item in rawItems.where(
        (i) => i.productRemoteId == null || i.productRemoteId!.isEmpty,
      )) {
        nextCartItems.add(item.copyWith(id: _newLineId()));
      }

      final withPromo = nextCartItems
          .where((i) => i.appliedPromoId != null)
          .toList();
      final withoutPromo = nextCartItems
          .where((i) => i.appliedPromoId == null)
          .toList();
      _cartItems = [...withPromo, ...withoutPromo];
      _orderLevelDiscountAmount = allocation.totalDiscountAmount;
    });
  }

  List<PosPromotionMatchItem> _buildPromotionMatchItems() {
    final productIndex = <String, Map<String, dynamic>>{
      for (final product in _catalogSnapshot.products)
        if (product['remoteId']?.toString().isNotEmpty == true)
          product['remoteId'].toString(): product,
    };

    return _cartItems
        .where(
          (item) =>
              item.productRemoteId != null && item.productRemoteId!.isNotEmpty,
        )
        .map((item) {
          final product =
              productIndex[item.productRemoteId!] ?? const <String, dynamic>{};
          return PosPromotionMatchItem(
            refId: item.id,
            productRemoteId: item.productRemoteId!,
            productName: item.name,
            categoryRemoteId: product['categoryRemoteId']?.toString(),
            brandRemoteId: product['brandRemoteId']?.toString(),
            activeUnitPrice: item.activeUnitPrice,
            quantity: item.quantity,
          );
        })
        .toList(growable: false);
  }

  Future<void> _showPromotionPicker() async {
    final l10n = AppLocalizations.of(context)!;
    final promotions = await PosPromotionService.instance
        .getApplicablePromotions(
          items: _buildPromotionMatchItems(),
          orderTypeCode: _toBackendOrderTypeCode(_selectedOrderType),
        );
    if (!mounted) return;

    final nextSelection = await showModalBottomSheet<List<PosPromotionResult>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final draft = List<PosPromotionResult>.from(_selectedPromotions);
        final primaryColor = Theme.of(context).colorScheme.primary;

        return StatefulBuilder(
          builder: (context, sheetSetState) => SafeArea(
            top: false,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.78,
              ),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              decoration: const BoxDecoration(
                color: Color(0xFFFAFCFF),
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    l10n.choosePromo,
                    style: TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    l10n.choosePromoSubtitle,
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                  ),
                  const SizedBox(height: 13),
                  Expanded(
                    child: promotions.isEmpty
                        ? Center(
                            child: Text(
                              l10n.noApplicablePromotionsMessage,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 11.5,
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: promotions.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final promo = promotions[index];
                              final selected = draft.any(
                                (item) => item.remoteId == promo.remoteId,
                              );
                              return _buildPromotionOption(
                                promo: promo,
                                selected: selected,
                                primaryColor: primaryColor,
                                onTap: () {
                                  sheetSetState(() {
                                    if (selected) {
                                      draft.removeWhere(
                                        (item) =>
                                            item.remoteId == promo.remoteId,
                                      );
                                      return;
                                    }
                                    if (draft.isNotEmpty &&
                                        (!promo.isStackable ||
                                            draft.any(
                                              (item) => !item.isStackable,
                                            ))) {
                                      _showFeedback(
                                        'Promo ini tidak dapat digabungkan dengan promo yang dipilih.',
                                      );
                                      return;
                                    }
                                    draft.add(promo);
                                  });
                                },
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (draft.isNotEmpty)
                        TextButton(
                          onPressed: () => sheetSetState(draft.clear),
                          child: const Text('Hapus promo'),
                        ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () => Navigator.pop(sheetContext, draft),
                        style: FilledButton.styleFrom(
                          backgroundColor: primaryColor,
                          minimumSize: const Size(126, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Terapkan'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (!mounted || nextSelection == null) return;
    setState(() => _selectedPromotions = nextSelection);
    _recalculateCartPromotions();
  }

  Widget _buildPromotionOption({
    required PosPromotionResult promo,
    required bool selected,
    required Color primaryColor,
    required VoidCallback onTap,
  }) {
    final value = promo.promoType == 'bundling'
        ? 'Paket ${_formatCurrency(promo.totalBundlePrice ?? 0)}'
        : '- ${_formatCurrency(promo.discountAmount)}';
    return Material(
      color: selected ? primaryColor.withValues(alpha: 0.08) : Colors.white,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? primaryColor : const Color(0xFFE2E8F0),
              width: selected ? 1.2 : 1,
            ),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.local_offer_outlined,
                color: selected ? primaryColor : const Color(0xFF64748B),
                size: 19,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      promo.name,
                      style: const TextStyle(
                        color: Color(0xFF1E293B),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (promo.summary.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        promo.summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 10.5,
                          height: 1.3,
                        ),
                      ),
                    ],
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: [
                        _buildPromotionMetaChip(
                          label: promo.promoType == 'bundling'
                              ? 'Bundling'
                              : 'Discount',
                          backgroundColor: promo.promoType == 'bundling'
                              ? const Color(0xFFEFF6FF)
                              : const Color(0xFFFFF7ED),
                          foregroundColor: promo.promoType == 'bundling'
                              ? const Color(0xFF1D4ED8)
                              : const Color(0xFF9A3412),
                        ),
                        if (promo.isMultiplied)
                          _buildPromotionMetaChip(
                            label: 'Kelipatan',
                            backgroundColor: const Color(0xFFECFDF5),
                            foregroundColor: const Color(0xFF047857),
                          ),
                        if (promo.isStackable)
                          _buildPromotionMetaChip(
                            label: 'Dapat digabungkan',
                            backgroundColor: const Color(0xFFFAF5FF),
                            foregroundColor: const Color(0xFF7E22CE),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      color: Color(0xFF047857),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    color: selected ? primaryColor : const Color(0xFF94A3B8),
                    size: 19,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromotionMetaChip({
    required String label,
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foregroundColor,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  void _resetCurrentOrder() {
    setState(() {
      _cartItems.clear();
      _orderLevelDiscountAmount = 0;
      _selectedPromotions.clear();
      _editingOrderId = null;
      _editingOrderToken = null;
      _editingOrderCreatedAt = null;
      _orderNote = '';
      _selectedOrderType = 'dine_in';
      _currentStage = _MobilePosStage.catalog;
      _tenderAmount = 0;
      _paymentErrorMessage = null;
      _paymentOptions = const [];
    });
    _ensureDefaultCustomerSelected();
  }

  List<String> _availableBrands(List<Map<String, dynamic>> products) {
    final set = <String>{};
    for (final p in products) {
      final b = p['brandName']?.toString();
      if (b != null && b.trim().isNotEmpty) {
        set.add(b.trim());
      }
    }
    return set.toList()..sort();
  }

  List<String> _availableCategoriesForBrand(
    List<Map<String, dynamic>> products,
    String? brandName,
  ) {
    final set = <String>{};
    for (final p in products) {
      final b = p['brandName']?.toString();
      final c = p['categoryName']?.toString();
      if (brandName != null && b != brandName) continue;
      if (c != null && c.trim().isNotEmpty) {
        set.add(c.trim());
      }
    }
    return set.toList()..sort();
  }

  // Aksi Checkout & Confirm
  Future<void> _proceedToPaymentStage() async {
    final l10n = AppLocalizations.of(context)!;
    if (_cartItems.isEmpty) return;
    if (_isTaxSettingsLoading) {
      _showFeedback('Memuat pengaturan pajak. Tunggu sebentar.');
      return;
    }

    setState(() => _isCommitting = true);
    try {
      await ActiveShiftStore.instance.refresh().timeout(
        const Duration(seconds: 10),
      );
      final activeShift = ActiveShiftStore.instance.activeShiftNotifier.value;
      final session = PosV2RuntimeSessionStore.instance.currentSession;

      if (session?.staffId?.isNotEmpty == true && activeShift == null) {
        _showFeedback(l10n.shiftRequiredBeforeOrderMessage);
        return;
      }

      await _ensureDefaultCustomerSelected();
      if (_selectedCustomer == null ||
          _selectedCustomer!.remoteId.trim().isEmpty) {
        _showFeedback(l10n.customerSelectionRequiredMessage);
        return;
      }

      final allowedOrderTypes = _cartItems
          .map(
            (item) =>
                _toBackendOrderTypeCode(item.orderType ?? _selectedOrderType),
          )
          .toSet()
          .toList();
      final paymentSnapshot = await SalesOrderStore.instance
          .loadPaymentModeSnapshot(orderTypes: allowedOrderTypes);

      if (paymentSnapshot.options.isEmpty) {
        _showFeedback(l10n.paymentModeUnavailableMessage);
        return;
      }

      if (!mounted) return;

      setState(() {
        _paymentOptions = paymentSnapshot.options;
        _selectedPaymentOption = paymentSnapshot.options.firstWhere(
          (opt) => opt.remoteId == paymentSnapshot.preselectedRemoteId,
          orElse: () => paymentSnapshot.options.first,
        );
        _tenderAmount = _totalPay;
        _manualTenderController.text = _tenderAmount.toString();
        _currentStage = _MobilePosStage.payment;
      });
    } catch (e) {
      _showFeedback(e.toString());
    } finally {
      setState(() => _isCommitting = false);
    }
  }

  void _showFeedback(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  List<SalesOrderLineItem> _buildOrderLines() {
    return _cartItems.map((item) {
      return SalesOrderLineItem(
        id: item.id,
        name: item.name,
        imageUrl: item.imageUrl,
        regularUnitPrice: item.regularUnitPrice,
        quantity: item.quantity,
        productRemoteId: item.productRemoteId,
        discountedUnitPrice: item.discountedUnitPrice,
        promoLabel: item.promoLabel,
        isDiscountEnabled: item.isDiscountEnabled,
        orderType: item.orderType ?? _selectedOrderType,
        note: item.note,
      );
    }).toList();
  }

  Future<void> _confirmAndCommitOrder() async {
    if (_isTaxSettingsLoading) {
      _showFeedback('Memuat pengaturan pajak. Tunggu sebentar.');
      return;
    }
    if (_selectedPaymentOption == null) return;
    if (_tenderAmount < _totalPay) {
      setState(() {
        _paymentErrorMessage =
            'Nominal diterima tidak boleh kurang dari total pembayaran.';
      });
      return;
    }

    final itemsForReceipt = List<_PosCartItem>.from(_cartItems);
    final selectedPaymentOption = _selectedPaymentOption!;
    final createdRecord = await _commitCartOrder(
      statusCode: 2,
      paymentMode: selectedPaymentOption,
      clearCart: false,
      processQueueNow: true,
    );

    if (createdRecord == null || !mounted) return;

    await _showPaymentSuccessDialog(
      record: createdRecord,
      items: itemsForReceipt,
      paymentName: selectedPaymentOption.name,
      tenderAmount: _tenderAmount,
    );

    if (mounted) _resetCurrentOrder();
  }

  Future<SalesOrderRecord?> _commitCartOrder({
    required int statusCode,
    SalesPaymentModeOption? paymentMode,
    bool clearCart = true,
    bool processQueueNow = false,
  }) async {
    if (_isCommitting || _cartItems.isEmpty) return null;
    if (_isTaxSettingsLoading) {
      _showFeedback('Memuat pengaturan pajak. Tunggu sebentar.');
      return null;
    }

    final l10n = AppLocalizations.of(context)!;
    setState(() => _isCommitting = true);
    try {
      await ActiveShiftStore.instance.refresh().timeout(
        const Duration(seconds: 10),
      );
      final activeShift = ActiveShiftStore.instance.activeShiftNotifier.value;
      final session = PosV2RuntimeSessionStore.instance.currentSession;
      if (session?.staffId?.isNotEmpty == true && activeShift == null) {
        _showFeedback(l10n.shiftRequiredBeforeOrderMessage);
        return null;
      }

      await _ensureDefaultCustomerSelected();
      final customer = _selectedCustomer;
      if (customer == null || customer.remoteId.trim().isEmpty) {
        _showFeedback(l10n.customerSelectionRequiredMessage);
        return null;
      }

      final createdRecord = await SalesOrderStore.instance.createOrder(
        statusCode: statusCode,
        items: _buildOrderLines(),
        customerName: customer.isDefaultWalkIn
            ? PosV2CustomerService.defaultWalkInName
            : customer.name,
        customerRemoteId: customer.remoteId,
        customerLocalId: customer.localId,
        customerPhone: customer.phone,
        customerAddress: customer.address,
        appliedPromotionRemoteId: _selectedPromotions.isNotEmpty
            ? _selectedPromotions.map((p) => p.remoteId).join(',')
            : null,
        appliedPromotionName: _selectedPromotions.isNotEmpty
            ? _selectedPromotions.map((p) => p.name).join(',')
            : null,
        appliedPromotionType: _selectedPromotions.isNotEmpty
            ? _selectedPromotions.map((p) => p.promoType).join(',')
            : null,
        appliedPromotionSummary: _selectedPromotions.isNotEmpty
            ? _selectedPromotions.map((p) => p.summary).join('; ')
            : null,
        existingOrderId: _editingOrderId,
        existingOrderToken: _editingOrderToken,
        existingCreatedAt: _editingOrderCreatedAt,
        orderType: _selectedOrderType,
        note: _orderNote,
        taxAmount: _taxAmount,
        taxName: _taxName,
        taxPercentage: _taxPercentage,
        shiftSessionId: activeShift?.id,
        orderLevelDiscountAmount: _orderLevelDiscountAmount,
        paymentModeRemoteId: paymentMode?.remoteId,
        paymentModeName: paymentMode?.name,
        processQueueNow: processQueueNow,
      );

      if (!mounted) return createdRecord;

      if (createdRecord == null) {
        _showFeedback('Failed to create order locally');
        return null;
      }

      if (clearCart) {
        _resetCurrentOrder();
      }

      if (statusCode == 1) {
        _showFeedback(l10n.activeOrderCreatedMessage);
      }
      return createdRecord;
    } catch (e) {
      _showFeedback(e.toString());
      return null;
    } finally {
      if (mounted) setState(() => _isCommitting = false);
    }
  }

  Future<void> _saveActiveOrder() async {
    await _commitCartOrder(statusCode: 1);
  }

  String _orderTypeLabel() {
    return _orderTypeOptions
        .firstWhere(
          (option) => option.$1 == _selectedOrderType,
          orElse: () => _orderTypeOptions.first,
        )
        .$2;
  }

  String _shortReceiptNumber(SalesOrderRecord record) {
    final value = record.id.trim();
    return value.length > 8 ? value.substring(value.length - 8) : value;
  }

  Future<void> _sendToKitchen() async {
    if (_cartItems.isEmpty || _isCommitting) return;
    if (_isTaxSettingsLoading) {
      _showFeedback('Memuat pengaturan pajak. Tunggu sebentar.');
      return;
    }

    await PrinterSettingsController.instance.refresh(silent: true);
    final printerState = PrinterSettingsController.instance.stateNotifier.value;
    final activePrinters = printerState.printers
        .where((printer) => printer.isActive)
        .toList(growable: false);
    final kitchenPrinters = activePrinters
        .where((printer) => printer.roles.contains('kitchen'))
        .toList(growable: false);

    if (kitchenPrinters.isEmpty) {
      if (!mounted) return;
      final saveWithoutPrinting = await _showKitchenPrinterUnavailableDialog();
      if (saveWithoutPrinting == true && mounted) {
        await _saveActiveOrder();
      }
      return;
    }

    final itemsForTicket = List<_PosCartItem>.from(_cartItems);
    final createdRecord = await _commitCartOrder(
      statusCode: 1,
      clearCart: false,
    );
    if (createdRecord == null || !mounted) return;

    await _printKitchenTickets(
      record: createdRecord,
      items: itemsForTicket,
      kitchenPrinters: kitchenPrinters,
    );
    if (mounted) _resetCurrentOrder();
  }

  Future<bool?> _showKitchenPrinterUnavailableDialog() {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.print_disabled_outlined, color: Color(0xFFB45309)),
            SizedBox(width: 8),
            Expanded(child: Text('Printer dapur belum diatur')),
          ],
        ),
        content: const Text(
          'Tidak ada printer dengan peran Dapur. Pesanan tetap dapat disimpan tanpa mencetak tiket.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Simpan tanpa cetak'),
          ),
        ],
      ),
    );
  }

  Future<void> _printKitchenTickets({
    required SalesOrderRecord record,
    required List<_PosCartItem> items,
    required List<dynamic> kitchenPrinters,
  }) async {
    final receiptNo = _shortReceiptNumber(record);
    var printedCount = 0;
    final failures = <String>[];

    for (final printer in kitchenPrinters) {
      final allowedBrands = printer.roleBrandFilters['kitchen'] ?? <String>[];
      final printerItems = items
          .where((item) {
            return allowedBrands.isEmpty ||
                item.brandName == null ||
                item.brandName!.isEmpty ||
                allowedBrands.contains(item.brandName);
          })
          .toList(growable: false);
      if (printerItems.isEmpty) continue;

      try {
        final document = PrinterDocumentData(
          type: PrinterDocumentType.kitchenTicket,
          title: 'TIKET DAPUR (${printer.displayName})',
          subtitle: 'Pesanan Dapur',
          infoRows: [
            PrinterInfoRow(label: 'No. Struk', value: receiptNo),
            PrinterInfoRow(label: 'Tipe Order', value: _orderTypeLabel()),
            PrinterInfoRow(
              label: 'Pelanggan',
              value: _selectedCustomer?.name ?? 'Walk-in',
            ),
            if (_orderNote.trim().isNotEmpty)
              PrinterInfoRow(label: 'Catatan', value: _orderNote.trim()),
          ],
          items: printerItems
              .map(
                (item) => PrinterLineItem(
                  label: item.displayName,
                  quantity: item.quantity,
                  note: item.note,
                ),
              )
              .toList(growable: false),
          footerLines: const ['Sinkronisasi Dapur FlinkPOS'],
        );
        final rendered = await PrinterRenderingService.instance.render(
          printer,
          document,
        );
        final result = await PrinterTransportService.instance.dispatch(
          printer,
          rendered,
        );
        if (result.success) {
          printedCount++;
        } else {
          failures.add('${printer.displayName}: ${result.message ?? 'Gagal'}');
        }
      } catch (error) {
        failures.add('${printer.displayName}: $error');
      }
    }

    if (!mounted) return;
    if (printedCount > 0) {
      _showFeedback('Pesanan dikirim ke dapur ($printedCount printer).');
    } else if (failures.isNotEmpty) {
      _showFeedback('Pesanan tersimpan, tetapi tiket dapur gagal dicetak.');
    } else {
      _showFeedback('Pesanan tersimpan, tetapi tidak ada tiket yang sesuai.');
    }
  }

  Future<void> _showPaymentSuccessDialog({
    required SalesOrderRecord record,
    required List<_PosCartItem> items,
    required String paymentName,
    required int tenderAmount,
  }) async {
    final changeAmount = (tenderAmount - _totalPay).clamp(0, 1 << 31);
    final primaryColor = Theme.of(context).colorScheme.primary;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
            decoration: BoxDecoration(
              color: const Color(0xFFFEFEFF),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(19),
                      ),
                      child: Icon(
                        Icons.receipt_long_outlined,
                        color: primaryColor,
                        size: 31,
                      ),
                    ),
                    Positioned(
                      right: -5,
                      bottom: -5,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFFEFEFF),
                            width: 3,
                          ),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 17),
                const Text(
                  'Pembayaran berhasil',
                  style: TextStyle(
                    color: Color(0xFF172554),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatCurrency(_totalPay),
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildPaymentDialogMetric(
                              icon: Icons.account_balance_wallet_outlined,
                              label: 'Metode',
                              value: paymentName,
                              primaryColor: primaryColor,
                            ),
                          ),
                          const SizedBox(
                            height: 31,
                            child: VerticalDivider(
                              color: Color(0xFFE2E8F0),
                              width: 1,
                            ),
                          ),
                          Expanded(
                            child: _buildPaymentDialogMetric(
                              icon: Icons.receipt_outlined,
                              label: 'Total',
                              value: _formatCurrency(_totalPay),
                              primaryColor: primaryColor,
                              alignEnd: true,
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _buildPaymentDialogMetric(
                              icon: Icons.payments_outlined,
                              label: 'Diterima',
                              value: _formatCurrency(tenderAmount),
                              primaryColor: primaryColor,
                            ),
                          ),
                          const SizedBox(
                            height: 31,
                            child: VerticalDivider(
                              color: Color(0xFFE2E8F0),
                              width: 1,
                            ),
                          ),
                          Expanded(
                            child: _buildPaymentDialogMetric(
                              icon: Icons.keyboard_return_rounded,
                              label: 'Kembalian',
                              value: _formatCurrency(changeAmount),
                              primaryColor: primaryColor,
                              alignEnd: true,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _printLabel(record: record, items: items),
                          icon: const Icon(
                            Icons.local_offer_outlined,
                            size: 17,
                          ),
                          label: const Text('Cetak label'),
                          style: _paymentPrintButtonStyle(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: OutlinedButton.icon(
                          onPressed: () => _printReceipt(
                            record: record,
                            items: items,
                            paymentName: paymentName,
                            tenderAmount: tenderAmount,
                          ),
                          icon: const Icon(Icons.print_outlined, size: 17),
                          label: const Text('Cetak struk'),
                          style: _paymentPrintButtonStyle(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 18,
                    ),
                    label: const Text('Selesai'),
                    style: FilledButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentDialogMetric({
    required IconData icon,
    required String label,
    required String value,
    required Color primaryColor,
    bool alignEnd = false,
  }) {
    final alignment = alignEnd
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignment,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: primaryColor, size: 13),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  ButtonStyle _paymentPrintButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFF475569),
      side: const BorderSide(color: Color(0xFFCBD5E1)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  Future<void> _printReceipt({
    required SalesOrderRecord record,
    required List<_PosCartItem> items,
    required String paymentName,
    required int tenderAmount,
  }) async {
    await PrinterSettingsController.instance.refresh(silent: true);
    final printers = PrinterSettingsController
        .instance
        .stateNotifier
        .value
        .printers
        .where(
          (printer) => printer.isActive && printer.roles.contains('cashier'),
        )
        .toList(growable: false);
    if (printers.isEmpty) {
      if (mounted) {
        _showFeedback('Printer nota belum diatur di Pengaturan > Printer.');
      }
      return;
    }

    final changeAmount = (tenderAmount - _totalPay).clamp(0, 1 << 31);
    var printedCount = 0;
    for (final printer in printers) {
      try {
        final document = PrinterDocumentData(
          type: PrinterDocumentType.receipt,
          title: 'NOTA PENJUALAN',
          subtitle: 'Bukti Pembayaran',
          infoRows: [
            PrinterInfoRow(
              label: 'No. Struk',
              value: _shortReceiptNumber(record),
            ),
            PrinterInfoRow(label: 'Tipe Order', value: _orderTypeLabel()),
            PrinterInfoRow(
              label: 'Pelanggan',
              value: _selectedCustomer?.name ?? 'Walk-in',
            ),
            PrinterInfoRow(label: 'Pembayaran', value: paymentName),
          ],
          items: items
              .map(
                (item) => PrinterLineItem(
                  label: item.displayName,
                  quantity: item.quantity,
                  amount: item.activeUnitPrice * item.quantity,
                  note: item.note,
                ),
              )
              .toList(growable: false),
          summaryRows: [
            PrinterSummaryRow(
              label: 'Subtotal',
              value: _formatCurrency(_subtotalAmount),
            ),
            if (_orderLevelDiscountAmount > 0)
              PrinterSummaryRow(
                label: 'Diskon',
                value: '-${_formatCurrency(_orderLevelDiscountAmount)}',
              ),
            if (_taxAmount > 0)
              PrinterSummaryRow(
                label: _taxName ?? 'Pajak',
                value: _formatCurrency(_taxAmount),
              ),
            PrinterSummaryRow(
              label: 'Total',
              value: _formatCurrency(_totalPay),
              highlighted: true,
            ),
            PrinterSummaryRow(
              label: 'Diterima',
              value: _formatCurrency(tenderAmount),
            ),
            PrinterSummaryRow(
              label: 'Kembalian',
              value: _formatCurrency(changeAmount),
            ),
          ],
          footerLines: const ['Terima kasih atas kunjungan Anda.'],
        );
        final rendered = await PrinterRenderingService.instance.render(
          printer,
          document,
        );
        final result = await PrinterTransportService.instance.dispatch(
          printer,
          rendered,
        );
        if (result.success) printedCount++;
      } catch (_) {}
    }

    if (mounted) {
      _showFeedback(
        printedCount > 0
            ? 'Struk pembayaran berhasil dicetak.'
            : 'Gagal mencetak struk ke printer nota.',
      );
    }
  }

  Future<void> _printLabel({
    required SalesOrderRecord record,
    required List<_PosCartItem> items,
  }) async {
    await PrinterSettingsController.instance.refresh(silent: true);
    final printers = PrinterSettingsController
        .instance
        .stateNotifier
        .value
        .printers
        .where((printer) => printer.isActive && printer.roles.contains('label'))
        .toList(growable: false);
    if (printers.isEmpty) {
      if (mounted) {
        _showFeedback('Printer label belum diatur di Pengaturan > Printer.');
      }
      return;
    }

    var printedCount = 0;
    for (final printer in printers) {
      try {
        final document = PrinterDocumentData(
          type: PrinterDocumentType.label,
          title: 'LABEL STIKER',
          subtitle:
              '${_orderTypeLabel()} | ${_selectedCustomer?.name ?? 'Walk-in'}',
          infoRows: [
            PrinterInfoRow(
              label: 'No. Struk',
              value: _shortReceiptNumber(record),
            ),
          ],
          items: items
              .map(
                (item) => PrinterLineItem(
                  label: item.displayName,
                  quantity: item.quantity,
                  note: item.note,
                ),
              )
              .toList(growable: false),
        );
        final rendered = await PrinterRenderingService.instance.render(
          printer,
          document,
        );
        final result = await PrinterTransportService.instance.dispatch(
          printer,
          rendered,
        );
        if (result.success) printedCount++;
      } catch (_) {}
    }

    if (mounted) {
      _showFeedback(
        printedCount > 0
            ? 'Label stiker berhasil dicetak.'
            : 'Gagal mencetak label ke printer yang dipilih.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    switch (_currentStage) {
      case _MobilePosStage.cart:
        return _buildCartScreen(theme, primaryColor);
      case _MobilePosStage.payment:
        return _buildPaymentScreen(theme, primaryColor);
      case _MobilePosStage.catalog:
        return _buildCatalogScreen(theme, primaryColor);
    }
  }

  // Stage 1: catalog is intentionally optimized for fast, one-handed product entry.
  Widget _buildCatalogScreen(ThemeData theme, Color primaryColor) {
    final l10n = AppLocalizations.of(context)!;
    final products = _catalogSnapshot.products
        .map(_applySelectedOrderTypePricing)
        .toList();
    final brands = _availableBrands(products);
    final categories = _availableCategoriesForBrand(
      products,
      _selectedBrandName,
    );
    final query = _searchController.text.trim().toLowerCase();
    final visibleProducts = products.where((product) {
      if (_selectedBrandName != null &&
          product['brandName']?.toString() != _selectedBrandName) {
        return false;
      }
      if (_selectedCategoryName != null &&
          product['categoryName']?.toString() != _selectedCategoryName) {
        return false;
      }
      if (query.isEmpty) return true;
      final name = product['name']?.toString().toLowerCase() ?? '';
      final description =
          product['description']?.toString().toLowerCase() ?? '';
      return name.contains(query) || description.contains(query);
    }).toList();
    visibleProducts.sort((a, b) {
      if (_selectedPromotions.isNotEmpty) {
        final aIsSelected = _isProductInSelectedPromotion(a);
        final bIsSelected = _isProductInSelectedPromotion(b);
        if (aIsSelected && !bIsSelected) return -1;
        if (!aIsSelected && bIsSelected) return 1;
      }
      if (_isPromoFilterActive) {
        final aHasPromo = a['promo'] != null;
        final bHasPromo = b['promo'] != null;
        if (aHasPromo && !bHasPromo) return -1;
        if (!aHasPromo && bHasPromo) return 1;
      }
      return (a['name']?.toString() ?? '').compareTo(
        b['name']?.toString() ?? '',
      );
    });
    final itemCount = _cartItems.fold(0, (sum, item) => sum + item.quantity);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      resizeToAvoidBottomInset: false,
      body: Builder(
        builder: (builderContext) => MediaQuery.removeViewInsets(
          context: builderContext,
          removeBottom: true,
          child: RepaintBoundary(
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Penjualan',
                                style: TextStyle(
                                  color: Color(0xFF172554),
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Pilih produk untuk pesanan baru',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            onTap: () async {
                              final customer = await showCustomerPickerDialog(
                                context,
                                initiallySelected: _selectedCustomer,
                              );
                              if (customer != null && mounted) {
                                setState(() => _selectedCustomer = customer);
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              height: 44,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _selectedCustomer?.isDefaultWalkIn == false
                                        ? Icons.person_rounded
                                        : Icons.person_outline_rounded,
                                    size: 18,
                                    color: primaryColor,
                                  ),
                                  const SizedBox(width: 6),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 74,
                                    ),
                                    child: Text(
                                      _selectedCustomer?.isDefaultWalkIn ==
                                              false
                                          ? _selectedCustomer!.name
                                          : 'Walk-in',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFF334155),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildCatalogActionsButton(primaryColor),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: _buildCatalogTransactionBar(primaryColor),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      height: 46,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: l10n.searchProduct,
                          hintStyle: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 20,
                          ),
                          suffixIcon: query.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Hapus pencarian',
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                ),
                          contentPadding: EdgeInsets.zero,
                          fillColor: Colors.white,
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(13),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(13),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (brands.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildFilterRail(
                      labels: ['Semua', ...brands],
                      selectedLabel: _selectedBrandName ?? 'Semua',
                      onSelected: (label) => setState(() {
                        _selectedBrandName = label == 'Semua' ? null : label;
                        _selectedCategoryName = null;
                      }),
                      primaryColor: primaryColor,
                    ),
                  ],
                  if (categories.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    _buildFilterRail(
                      labels: ['Semua kategori', ...categories],
                      selectedLabel: _selectedCategoryName ?? 'Semua kategori',
                      onSelected: (label) => setState(
                        () => _selectedCategoryName = label == 'Semua kategori'
                            ? null
                            : label,
                      ),
                      primaryColor: primaryColor,
                      subtle: true,
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 9),
                    child: Row(
                      children: [
                        const Text(
                          'Produk',
                          style: TextStyle(
                            color: Color(0xFF1E293B),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${visibleProducts.length} tersedia',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: visibleProducts.isEmpty
                        ? _buildCatalogEmptyState(l10n.catalogEmptySubtitle)
                        : GridView.builder(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 188,
                                  mainAxisExtent: 222,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                ),
                            itemCount: visibleProducts.length,
                            itemBuilder: (context, index) => _buildProductTile(
                              product: visibleProducts[index],
                              primaryColor: primaryColor,
                            ),
                          ),
                  ),
                  if (_cartItems.isNotEmpty)
                    SafeArea(
                      top: false,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            top: BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  '$itemCount',
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Total sementara',
                                    style: TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatCurrency(_totalPay),
                                    style: const TextStyle(
                                      color: Color(0xFF172554),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: () {
                                FocusManager.instance.primaryFocus?.unfocus();
                                setState(
                                  () => _currentStage = _MobilePosStage.cart,
                                );
                              },
                              icon: const Icon(
                                Icons.shopping_bag_outlined,
                                size: 18,
                              ),
                              label: const Text('Keranjang'),
                              style: FilledButton.styleFrom(
                                backgroundColor: primaryColor,
                                minimumSize: const Size(128, 48),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCatalogTransactionBar(Color primaryColor) {
    final option = _orderTypeOptions.firstWhere(
      (option) => option.$1 == _selectedOrderType,
      orElse: () => _orderTypeOptions.first,
    );

    return Row(
      children: [
        Expanded(
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(13),
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: InkWell(
                      onTap: _showOrderTypePicker,
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(13),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            Icon(option.$3, color: primaryColor, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Tipe pesanan',
                                    style: TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    option.$2,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF1E293B),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Color(0xFF64748B),
                              size: 19,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 24,
                    child: VerticalDivider(color: Color(0xFFE2E8F0), width: 1),
                  ),
                  Expanded(
                    flex: 2,
                    child: ValueListenableBuilder<List<SalesOrderRecord>>(
                      valueListenable: SalesOrderStore.instance.recordsNotifier,
                      builder: (context, orders, _) {
                        final count = orders
                            .where(
                              (order) =>
                                  order.statusCode == 1 ||
                                  order.statusCode == 6,
                            )
                            .length;
                        final countLabel = count > 99 ? '99+' : '$count';
                        return Semantics(
                          button: true,
                          label: count == 0
                              ? 'Buka daftar pesanan, belum ada pesanan aktif'
                              : 'Buka daftar pesanan, $count pesanan aktif atau ditahan',
                          child: InkWell(
                            onTap: _openMobileOrders,
                            borderRadius: const BorderRadius.horizontal(
                              right: Radius.circular(13),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.receipt_long_outlined,
                                    color: primaryColor,
                                    size: 19,
                                  ),
                                  const SizedBox(width: 7),
                                  const Expanded(
                                    child: Text(
                                      'Pesanan',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Color(0xFF334155),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 160),
                                    switchInCurve: Curves.easeOutCubic,
                                    switchOutCurve: Curves.easeOutCubic,
                                    child: count == 0
                                        ? const SizedBox(
                                            key: ValueKey('orders-empty'),
                                          )
                                        : Container(
                                            key: ValueKey(count),
                                            constraints: const BoxConstraints(
                                              minWidth: 20,
                                            ),
                                            height: 20,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 5,
                                            ),
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: primaryColor,
                                              borderRadius:
                                                  BorderRadius.circular(99),
                                            ),
                                            child: Text(
                                              countLabel,
                                              maxLines: 1,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _buildPromotionQuickAction(primaryColor),
      ],
    );
  }

  Widget _buildCatalogActionsButton(Color primaryColor) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Tooltip(
          message: l10n.posQuickActions,
          child: InkWell(
            onTap: widget.isReadOnly ? null : _showQuickActionsSheet,
            borderRadius: BorderRadius.circular(12),
            child: Icon(
              Icons.more_horiz_rounded,
              color: primaryColor,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showQuickActionsSheet() async {
    final hadFocusedInput =
        FocusManager.instance.primaryFocus?.hasFocus ?? false;
    FocusManager.instance.primaryFocus?.unfocus();
    if (hadFocusedInput) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
    }

    final l10n = AppLocalizations.of(context)!;
    final orderActions = [
      _MobilePosQuickActionItem(
        value: _MobilePosQuickAction.discount,
        icon: Icons.discount_outlined,
        label: l10n.discount,
      ),
      _MobilePosQuickActionItem(
        value: _MobilePosQuickAction.clearOrder,
        icon: Icons.layers_clear_outlined,
        label: l10n.clearOrderAction,
      ),
      _MobilePosQuickActionItem(
        value: _MobilePosQuickAction.cancelOrder,
        icon: Icons.cancel_outlined,
        label: l10n.cancelOrderAction,
        isDestructive: true,
      ),
    ];
    final cashActions = [
      _MobilePosQuickActionItem(
        value: _MobilePosQuickAction.cashIn,
        icon: Icons.arrow_circle_down_outlined,
        label: l10n.cashIn,
      ),
      _MobilePosQuickActionItem(
        value: _MobilePosQuickAction.cashOut,
        icon: Icons.arrow_circle_up_outlined,
        label: l10n.cashOut,
      ),
    ];
    final systemActions = [
      _MobilePosQuickActionItem(
        value: _MobilePosQuickAction.syncData,
        icon: Icons.sync_outlined,
        label: l10n.syncDataAction,
      ),
      _MobilePosQuickActionItem(
        value: _MobilePosQuickAction.closeOutlet,
        icon: Icons.store_mall_directory_outlined,
        label: l10n.closeOutletAction,
      ),
      _MobilePosQuickActionItem(
        value: _MobilePosQuickAction.settings,
        icon: Icons.settings_outlined,
        label: l10n.settings,
      ),
    ];
    final selectedAction = await showModalBottomSheet<_MobilePosQuickAction>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      sheetAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 180),
        reverseDuration: Duration(milliseconds: 140),
      ),
      builder: (sheetContext) => RepaintBoundary(
        child: SafeArea(
          top: false,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.76,
            ),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: const BoxDecoration(
              color: Color(0xFFFAFCFF),
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.posQuickActions,
                    style: const TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildQuickActionsSectionLabel(
                    l10n.posQuickActionsOrdersSection,
                  ),
                  _buildQuickActionsGroup(sheetContext, orderActions),
                  const SizedBox(height: 14),
                  _buildQuickActionsSectionLabel(
                    l10n.posQuickActionsCashSection,
                  ),
                  _buildQuickActionsGroup(sheetContext, cashActions),
                  const SizedBox(height: 14),
                  _buildQuickActionsSectionLabel(
                    l10n.posQuickActionsSystemSection,
                  ),
                  _buildQuickActionsGroup(sheetContext, systemActions),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Wait until the quick-actions sheet has fully reversed before opening
    // another route. Stacking the sheet, dialog, and IME animations causes
    // visible frame drops on lower-powered Android devices.
    if (!mounted || selectedAction == null) return;
    _handleMobileQuickAction(selectedAction);
  }

  Widget _buildQuickActionsSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildQuickActionsGroup(
    BuildContext context,
    List<_MobilePosQuickActionItem> actions,
  ) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Column(
            children: [
              for (var index = 0; index < actions.length; index++) ...[
                if (index > 0)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    indent: 60,
                    color: Color(0xFFF1F5F9),
                  ),
                _buildQuickActionsGroupItem(context, actions[index]),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionsGroupItem(
    BuildContext context,
    _MobilePosQuickActionItem action,
  ) {
    final color = action.isDestructive
        ? const Color(0xFFB91C1C)
        : const Color(0xFF334155);
    return InkWell(
      onTap: () => Navigator.of(context).pop(action.value),
      child: SizedBox(
        height: 54,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(action.icon, size: 18, color: color),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  action.label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: color.withValues(alpha: 0.45),
                size: 19,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromotionQuickAction(Color primaryColor) {
    final l10n = AppLocalizations.of(context)!;
    return Semantics(
      button: true,
      label: _isPromoFilterActive ? '${l10n.promo} aktif' : l10n.promo,
      child: Material(
        color: _isPromoFilterActive ? const Color(0xFFF04438) : Colors.white,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: () =>
              setState(() => _isPromoFilterActive = !_isPromoFilterActive),
          borderRadius: BorderRadius.circular(13),
          child: Container(
            width: 64,
            height: 56,
            decoration: BoxDecoration(
              border: Border.all(
                color: _isPromoFilterActive
                    ? const Color(0xFFF04438)
                    : const Color(0xFFE2E8F0),
              ),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.local_offer_outlined,
                      color: _isPromoFilterActive ? Colors.white : primaryColor,
                      size: 19,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.promo,
                      style: TextStyle(
                        color: _isPromoFilterActive
                            ? Colors.white
                            : primaryColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleMobileQuickAction(_MobilePosQuickAction action) async {
    final l10n = AppLocalizations.of(context)!;
    switch (action) {
      case _MobilePosQuickAction.discount:
        _showDiscountActionSheet();
        return;
      case _MobilePosQuickAction.clearOrder:
        _showClearCartDialog();
        return;
      case _MobilePosQuickAction.cancelOrder:
        unawaited(_commitCartOrder(statusCode: 5));
        return;
      case _MobilePosQuickAction.cashIn:
        unawaited(_showCashInDialog());
        return;
      case _MobilePosQuickAction.cashOut:
        unawaited(_showCashOutDialog());
        return;
      case _MobilePosQuickAction.syncData:
        unawaited(_syncQuickMasterData());
        return;
      case _MobilePosQuickAction.closeOutlet:
        _showFeedback(l10n.featureNotWiredMessage(l10n.closeOutletAction));
        return;
      case _MobilePosQuickAction.settings:
        await showDialog<void>(
          context: context,
          builder: (context) => const PosSettingsDialog(),
        );
        await _loadTaxSettings();
        return;
    }
  }

  Future<void> _showDiscountActionSheet() async {
    final l10n = AppLocalizations.of(context)!;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          decoration: const BoxDecoration(
            color: Color(0xFFFAFCFF),
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.discount,
                style: const TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.discountActionSubtitle,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
              ),
              const SizedBox(height: 12),
              _buildDiscountActionOption(
                icon: Icons.local_offer_outlined,
                iconColor: const Color(0xFFB45309),
                iconBackground: const Color(0xFFFFF7E6),
                title: l10n.choosePromo,
                subtitle: _selectedPromotions.isEmpty
                    ? l10n.choosePromoSubtitle
                    : l10n.promoAppliedCount(_selectedPromotions.length),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_showPromotionPicker());
                },
              ),
              const SizedBox(height: 8),
              _buildDiscountActionOption(
                icon: Icons.discount_outlined,
                iconColor: Theme.of(context).colorScheme.primary,
                iconBackground: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.10),
                title: l10n.manualDiscount,
                subtitle: l10n.manualDiscountSubtitle,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_showManualDiscountSheet());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiscountActionOption({
    required IconData icon,
    required Color iconColor,
    required Color iconBackground,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: iconColor, size: 19),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF1E293B),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF94A3B8),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showManualDiscountSheet() async {
    if (_cartItems.isEmpty) {
      _showFeedback('Tambahkan produk sebelum menerapkan diskon.');
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final amountController = TextEditingController();
    var isPercent = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, sheetSetState) => SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                decoration: const BoxDecoration(
                  color: Color(0xFFFAFCFF),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.manualDiscount,
                      style: const TextStyle(
                        color: Color(0xFF1E293B),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.manualDiscountSubtitle,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SegmentedButton<bool>(
                      segments: [
                        ButtonSegment(
                          value: false,
                          label: Text(l10n.discountTypeRp),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text(l10n.discountTypePercent),
                        ),
                      ],
                      selected: {isPercent},
                      onSelectionChanged: (selection) {
                        sheetSetState(() {
                          isPercent = selection.first;
                          amountController.clear();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      autofocus: false,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onTapOutside: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      decoration: InputDecoration(
                        prefixText: isPercent ? null : 'Rp ',
                        suffixText: isPercent ? '%' : null,
                        hintText: isPercent ? '0–100' : '0',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 46,
                      child: FilledButton(
                        onPressed: () {
                          final value = int.tryParse(
                            amountController.text.replaceAll(
                              RegExp(r'[^0-9]'),
                              '',
                            ),
                          );
                          if (value == null || value <= 0) {
                            _showFeedback(
                              'Masukkan nominal diskon yang valid.',
                            );
                            return;
                          }
                          if (isPercent && value > 100) {
                            _showFeedback('Diskon persentase maksimal 100%.');
                            return;
                          }
                          setState(_selectedPromotions.clear);
                          _recalculateCartPromotions();
                          setState(() {
                            _orderLevelDiscountAmount = isPercent
                                ? (_subtotalAmount * value / 100).round()
                                : value.clamp(0, _subtotalAmount).toInt();
                          });
                          Navigator.of(sheetContext).pop();
                        },
                        child: Text(l10n.applyDiscount),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    // The modal route completes when pop starts; retain the controller until
    // its reverse animation has finished rebuilding the TextField.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    amountController.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetchPaymentModes() async {
    final session = PosV2RuntimeSessionStore.instance.currentSession;
    List<Map<String, dynamic>> modes = [];

    if (session != null &&
        session.baseUrl.isNotEmpty &&
        session.authToken.isNotEmpty) {
      try {
        modes = await ExpenseService(
          baseUrl: session.baseUrl,
          authToken: session.authToken,
        ).getPaymentModes();
      } catch (_) {}
    }

    if (modes.isNotEmpty) return modes;

    if (session?.tenantId != null) {
      try {
        final localDbModes = await DatabaseService.instance.rawQuery(
          '''
          SELECT
            COALESCE(NULLIF(remote_id, ''), CAST(id AS TEXT)) AS id,
            remote_id,
            name,
            '' AS type
          FROM payment_mode
          WHERE tenant_id = ?
            AND deleted_at IS NULL
            AND is_active = 1
            AND TRIM(COALESCE(name, '')) != ''
          ORDER BY selected_by_default DESC, name ASC
          ''',
          [session!.tenantId],
        );
        if (localDbModes.isNotEmpty) {
          return List<Map<String, dynamic>>.from(localDbModes);
        }
      } catch (_) {}
    }

    // Do not fabricate bank or QRIS methods when neither the server nor the
    // locally-synchronised payment-mode catalogue is available. Their IDs are
    // tenant-specific and submitting a guessed ID can record cash flow under
    // the wrong method.
    return const [
      {'id': 1, 'name': 'Kas / Tunai', 'type': 'cash'},
    ];
  }

  Future<void> _showCashInDialog() async {
    if (ActiveShiftStore.instance.activeShiftNotifier.value == null) {
      _showFeedback(
        'Silakan buka shift terlebih dahulu untuk menambah kas masuk.',
      );
      return;
    }
    final session = PosV2RuntimeSessionStore.instance.currentSession;
    final paymentModes = await _fetchPaymentModes();
    if (!mounted) return;

    final inputData = await KasMasukDialog.show(
      context,
      paymentModes: paymentModes,
      optimizeForMobileKeyboard: true,
    );
    if (inputData == null || !mounted) return;

    try {
      if (session?.tenantId != null) {
        await DatabaseService.instance.rawInsert(
          '''
          INSERT INTO pos_cash_flow (
            tenant_id, location_id, type, amount, note, staff_id_snapshot, sync_state, created_at, updated_at
          ) VALUES (?, ?, 'in', ?, ?, ?, 'dirty_create', ?, ?)
          ''',
          [
            session!.tenantId,
            session.locationId,
            inputData.amount,
            inputData.catatan.isNotEmpty
                ? '${inputData.nama} - ${inputData.catatan}'
                : inputData.nama,
            session.staffId,
            inputData.tanggal.toIso8601String(),
            DateTime.now().toIso8601String(),
          ],
        );
      }
      _showFeedback('Kas masuk (Petty Cash) berhasil dicatat.');
    } catch (error) {
      _showFeedback('Gagal mencatat kas masuk: $error');
    }
  }

  Future<void> _showCashOutDialog() async {
    if (ActiveShiftStore.instance.activeShiftNotifier.value == null) {
      _showFeedback(
        'Silakan buka shift terlebih dahulu untuk menambah kas keluar.',
      );
      return;
    }
    final session = PosV2RuntimeSessionStore.instance.currentSession;
    final paymentModes = await _fetchPaymentModes();
    if (!mounted) return;

    final inputData = await KasKeluarDialog.show(
      context,
      paymentModes: paymentModes,
      optimizeForMobileKeyboard: true,
    );
    if (inputData == null || !mounted) return;

    try {
      if (session?.tenantId != null) {
        await DatabaseService.instance.rawInsert(
          '''
          INSERT INTO pos_cash_flow (
            tenant_id, location_id, type, amount, note, staff_id_snapshot, sync_state, created_at, updated_at
          ) VALUES (?, ?, 'out', ?, ?, ?, 'dirty_create', ?, ?)
          ''',
          [
            session!.tenantId,
            session.locationId,
            inputData.amount,
            inputData.catatan.isNotEmpty
                ? '${inputData.nama} - ${inputData.catatan}'
                : inputData.nama,
            session.staffId,
            inputData.tanggal.toIso8601String(),
            DateTime.now().toIso8601String(),
          ],
        );
      }
      if (session != null &&
          session.baseUrl.isNotEmpty &&
          session.authToken.isNotEmpty) {
        final expenseService = ExpenseService(
          baseUrl: session.baseUrl,
          authToken: session.authToken,
        );
        unawaited(
          expenseService
              .postExpense(
                inputData: inputData,
                paymentModeId: inputData.paymentModeId,
              )
              .catchError((_) => <String, dynamic>{}),
        );
      }
      _showFeedback('Pengeluaran kas keluar berhasil dicatat.');
    } catch (error) {
      _showFeedback('Gagal mencatat kas keluar: $error');
    }
  }

  Future<void> _syncQuickMasterData() async {
    if (_isSyncingQuickData) return;

    final l10n = AppLocalizations.of(context)!;
    final session =
        PosV2RuntimeSessionStore.instance.currentSession ??
        await PosV2RuntimeSessionStore.instance.restoreFromDatabase();
    if (session == null) {
      _showFeedback(l10n.loginRequiredMessage);
      return;
    }

    setState(() => _isSyncingQuickData = true);
    _showFeedback(l10n.syncDataStartedMessage);
    try {
      final orchestrator = PosV2SyncOrchestrator();
      final syncContext = session.toSyncContext();
      await orchestrator.syncCategories(syncContext);
      await orchestrator.syncBrands(syncContext);
      await orchestrator.syncItemsPaged(
        syncContext,
        baseQuery: const <String, dynamic>{'status': 'active'},
        itemPerPage: 500,
        startPage: 1,
        maxPages: 25,
      );
      await orchestrator.syncPromotions(
        syncContext,
        query: <String, dynamic>{
          'status': '1',
          if (session.locationId.isNotEmpty) 'id_location': session.locationId,
        },
        allowNotFoundEmpty: true,
      );
      await orchestrator.syncCustomers(syncContext);
      await PosCatalogStore.instance.refresh();
      await SalesOrderStore.instance.refreshFromPersistence();
      _showFeedback(l10n.syncDataSuccessMessage);
    } catch (error) {
      _showFeedback(
        l10n.syncDataFailedMessage(
          error.toString().replaceFirst('Exception: ', ''),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSyncingQuickData = false);
    }
  }

  bool _isProductInSelectedPromotion(Map<String, dynamic> product) {
    final remoteId = product['remoteId']?.toString();
    final categoryId = product['categoryRemoteId']?.toString();
    return _selectedPromotions.any(
      (promo) =>
          promo.eligibleProductIds.contains(remoteId) ||
          promo.eligibleCategoryIds.contains(categoryId),
    );
  }

  void _openMobileOrders() {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const _MobileOrdersPage()));
  }

  Widget _buildFilterRail({
    required List<String> labels,
    required String selectedLabel,
    required ValueChanged<String> onSelected,
    required Color primaryColor,
    bool subtle = false,
  }) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final label = labels[index];
          final selected = label == selectedLabel;
          final selectedColor = subtle
              ? primaryColor.withValues(alpha: 0.10)
              : primaryColor;
          final selectedTextColor = subtle ? primaryColor : Colors.white;
          return ChoiceChip(
            label: Text(label),
            selected: selected,
            onSelected: (_) => onSelected(label),
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
            labelStyle: TextStyle(
              color: selected ? selectedTextColor : const Color(0xFF475569),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
            selectedColor: selectedColor,
            backgroundColor: Colors.white,
            side: BorderSide(
              color: selected
                  ? (subtle
                        ? primaryColor.withValues(alpha: 0.22)
                        : Colors.transparent)
                  : const Color(0xFFE2E8F0),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCatalogEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off_rounded,
              color: Color(0xFF94A3B8),
              size: 30,
            ),
            const SizedBox(height: 9),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductTile({
    required Map<String, dynamic> product,
    required Color primaryColor,
  }) {
    final remoteId = product['remoteId']?.toString();
    final quantity = _cartItems
        .where((item) => item.productRemoteId == remoteId)
        .fold(0, (sum, item) => sum + item.quantity);
    final priceValue = product['discountedPrice'] ?? product['price'] ?? '0';
    final price =
        int.tryParse(priceValue.toString().replaceAll(RegExp(r'[^0-9]'), '')) ??
        0;
    final imageUrl =
        product['image']?.toString() ?? product['imageUrl']?.toString() ?? '';
    final stockLabel = product['stock']?.toString().trim() ?? '0';
    final stockValue = double.tryParse(stockLabel) ?? 0;
    final hasStock = stockValue > 0;
    final isLowStock = hasStock && stockValue <= 5;
    final selectedPromo = _selectedPromotions.where(
      (promo) =>
          promo.eligibleProductIds.contains(remoteId) ||
          promo.eligibleCategoryIds.contains(
            product['categoryRemoteId']?.toString(),
          ),
    );
    final hasPromo =
        selectedPromo.isNotEmpty ||
        product['promo']?.toString().trim().isNotEmpty == true;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _addProductToCart(product),
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE5EAF2)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(13),
                      ),
                      child: imageUrl.isEmpty
                          ? _buildProductImagePlaceholder(
                              product['name']?.toString() ?? '-',
                            )
                          : ColoredBox(
                              color: Colors.white,
                              child: CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.medium,
                                fadeInDuration: const Duration(
                                  milliseconds: 120,
                                ),
                                placeholder: (_, _) =>
                                    _buildProductImagePlaceholder(
                                      product['name']?.toString() ?? '-',
                                      loading: true,
                                    ),
                                errorWidget: (_, _, _) =>
                                    _buildProductImagePlaceholder(
                                      product['name']?.toString() ?? '-',
                                    ),
                              ),
                            ),
                    ),
                    if (quantity > 0)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 26,
                            minHeight: 26,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 7),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: primaryColor,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            '$quantity',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    if (hasPromo)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD97706),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.local_offer_rounded,
                                color: Colors.white,
                                size: 11,
                              ),
                              SizedBox(width: 3),
                              Text(
                                'PROMO',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  letterSpacing: 0.3,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(11, 9, 11, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 30,
                      child: Text(
                        product['name']?.toString() ?? '-',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF1E293B),
                          fontSize: 11.5,
                          height: 1.25,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _formatCurrency(price),
                            style: TextStyle(
                              color: primaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Icon(
                          hasStock
                              ? Icons.inventory_2_outlined
                              : Icons.remove_shopping_cart_outlined,
                          size: 12,
                          color: hasStock
                              ? (isLowStock
                                    ? const Color(0xFFB45309)
                                    : const Color(0xFF64748B))
                              : const Color(0xFFB91C1C),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          hasStock ? 'Stok $stockLabel' : 'Habis',
                          style: TextStyle(
                            color: hasStock
                                ? (isLowStock
                                      ? const Color(0xFFB45309)
                                      : const Color(0xFF64748B))
                                : const Color(0xFFB91C1C),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductImagePlaceholder(
    String productName, {
    bool loading = false,
  }) {
    final trimmedName = productName.trim();
    final initial = trimmedName.isEmpty
        ? 'P'
        : trimmedName.substring(0, 1).toUpperCase();

    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
      ),
    );
  }

  // Stage 2: cart gets a dedicated workspace so editing never competes with the catalog.
  Widget _buildCartScreen(ThemeData theme, Color primaryColor) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        scrolledUnderElevation: 0,
        title: Text(
          'Keranjang · ${_cartItems.fold(0, (sum, item) => sum + item.quantity)} item',
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        leading: IconButton(
          tooltip: 'Kembali ke katalog',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () =>
              setState(() => _currentStage = _MobilePosStage.catalog),
        ),
        actions: [
          TextButton.icon(
            onPressed: _cartItems.isEmpty ? null : _showClearCartDialog,
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Kosongkan'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFDC2626),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                _buildOrderTypeSelector(primaryColor),
                const SizedBox(height: 8),
                _buildPromotionSelector(primaryColor),
              ],
            ),
          ),
          Expanded(
            child: _cartItems.isEmpty
                ? _buildCartEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
                    itemCount: _cartItems.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 9),
                    itemBuilder: (context, index) => _buildCartItemRow(
                      item: _cartItems[index],
                      primaryColor: primaryColor,
                    ),
                  ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 13, 16, 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Column(
                children: [
                  _buildTotalRow('Subtotal', _formatCurrency(_subtotalAmount)),
                  if (_orderLevelDiscountAmount > 0) ...[
                    const SizedBox(height: 7),
                    _buildTotalRow(
                      'Diskon promo',
                      '- ${_formatCurrency(_orderLevelDiscountAmount)}',
                      valueColor: const Color(0xFFDC2626),
                    ),
                  ],
                  if (_taxAmount > 0) ...[
                    const SizedBox(height: 7),
                    _buildTotalRow(
                      _taxName ?? 'Pajak',
                      _formatCurrency(_taxAmount),
                    ),
                  ],
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 11),
                    child: Divider(height: 1, color: Color(0xFFE8EDF5)),
                  ),
                  _buildTotalRow(
                    'Total pembayaran',
                    _formatCurrency(_totalPay),
                    bold: true,
                    valueColor: primaryColor,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed:
                              _cartItems.isEmpty ||
                                  _isCommitting ||
                                  _isTaxSettingsLoading
                              ? null
                              : _saveActiveOrder,
                          icon: const Icon(
                            Icons.bookmark_border_rounded,
                            size: 18,
                          ),
                          label: const Text('Simpan'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF475569),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            minimumSize: const Size(0, 44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(11),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed:
                              _cartItems.isEmpty ||
                                  _isCommitting ||
                                  _isTaxSettingsLoading
                              ? null
                              : _sendToKitchen,
                          icon: const Icon(Icons.restaurant_outlined, size: 18),
                          label: const Text('Kirim dapur'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFECFDF5),
                            foregroundColor: const Color(0xFF047857),
                            minimumSize: const Size(0, 44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(11),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed:
                          _cartItems.isEmpty ||
                              _isCommitting ||
                              _isTaxSettingsLoading
                          ? null
                          : _proceedToPaymentStage,
                      icon: _isCommitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.arrow_forward_rounded, size: 19),
                      label: Text(
                        _isCommitting
                            ? 'Memeriksa pesanan…'
                            : 'Lanjut ke pembayaran',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromotionSelector(Color primaryColor) {
    final hasPromotion = _selectedPromotions.isNotEmpty;
    final label = hasPromotion
        ? _selectedPromotions.map((promo) => promo.name).join(' · ')
        : 'Pilih promo untuk pesanan ini';
    final caption = hasPromotion
        ? '${_selectedPromotions.length} promo diterapkan'
        : 'Promo akan dihitung dari produk dan tipe pesanan';

    return Material(
      color: hasPromotion ? const Color(0xFFFFFBEB) : Colors.white,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: _showPromotionPicker,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            border: Border.all(
              color: hasPromotion
                  ? const Color(0xFFFDE68A)
                  : const Color(0xFFE2E8F0),
            ),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1CC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.local_offer_outlined,
                  color: Color(0xFFB45309),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF1E293B),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: hasPromotion
                            ? const Color(0xFFB45309)
                            : const Color(0xFF64748B),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                hasPromotion ? 'Ubah' : 'Pilih',
                style: TextStyle(
                  color: hasPromotion ? const Color(0xFFB45309) : primaryColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.chevron_right_rounded,
                color: hasPromotion ? const Color(0xFFB45309) : primaryColor,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartItemRow({
    required _PosCartItem item,
    required Color primaryColor,
  }) {
    final itemTotal = item.activeUnitPrice * item.quantity;
    final promoName = item.appliedPromoName ?? item.promoLabel;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: widget.isReadOnly ? null : () => _showMobileCartItemEditor(item),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5EAF2)),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    clipBehavior: Clip.antiAlias,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEEF2F7)),
                    ),
                    child: item.imageUrl.isEmpty
                        ? const ColoredBox(
                            color: Colors.white,
                            child: Center(
                              child: Icon(
                                Icons.inventory_2_outlined,
                                color: Color(0xFF94A3B8),
                                size: 21,
                              ),
                            ),
                          )
                        : CachedNetworkImage(
                            imageUrl: item.imageUrl,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.medium,
                            placeholder: (_, _) => const ColoredBox(
                              color: Colors.white,
                              child: Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFFCBD5E1),
                                  ),
                                ),
                              ),
                            ),
                            errorWidget: (_, _, _) => const ColoredBox(
                              color: Colors.white,
                              child: Center(
                                child: Icon(
                                  Icons.image_not_supported_outlined,
                                  color: Color(0xFF94A3B8),
                                  size: 21,
                                ),
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF1E293B),
                            fontSize: 12.5,
                            height: 1.25,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _formatCurrency(item.activeUnitPrice),
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (promoName?.isNotEmpty == true) ...[
                          const SizedBox(height: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7E8),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              promoName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFB45309),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildQuantityControl(item, primaryColor),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(height: 1, color: Color(0xFFF0F3F7)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: widget.isReadOnly
                          ? null
                          : () => _showMobileCartItemEditor(item),
                      icon: Icon(
                        item.note?.isNotEmpty == true
                            ? Icons.sticky_note_2_outlined
                            : Icons.add_comment_outlined,
                        size: 16,
                      ),
                      label: Text(
                        item.note?.isNotEmpty == true
                            ? item.note!
                            : 'Tambah catatan',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: TextButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        foregroundColor: const Color(0xFF64748B),
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        minimumSize: const Size(44, 36),
                        textStyle: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Total item',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatCurrency(itemTotal),
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuantityControl(_PosCartItem item, Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Kurangi ${item.displayName}',
            onPressed: widget.isReadOnly
                ? null
                : () => _onChangeQuantity(item.id, item.quantity - 1),
            icon: const Icon(Icons.remove_rounded, size: 17),
            color: const Color(0xFF475569),
            constraints: const BoxConstraints(minHeight: 40, minWidth: 40),
            padding: EdgeInsets.zero,
          ),
          SizedBox(
            width: 24,
            child: Text(
              '${item.quantity}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Tambah ${item.displayName}',
            onPressed: widget.isReadOnly
                ? null
                : () => _onChangeQuantity(item.id, item.quantity + 1),
            icon: const Icon(Icons.add_rounded, size: 17),
            color: primaryColor,
            constraints: const BoxConstraints(minHeight: 40, minWidth: 40),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildCartEmptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shopping_bag_outlined, color: Color(0xFF94A3B8), size: 34),
          SizedBox(height: 10),
          Text(
            'Keranjang masih kosong',
            style: TextStyle(
              color: Color(0xFF475569),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(
    String label,
    String value, {
    bool bold = false,
    Color? valueColor,
  }) {
    final style = TextStyle(
      color: bold ? const Color(0xFF1E293B) : const Color(0xFF64748B),
      fontSize: bold ? 13 : 11.5,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(
          value,
          style: style.copyWith(color: valueColor ?? const Color(0xFF1E293B)),
        ),
      ],
    );
  }

  void _showClearCartDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kosongkan keranjang?'),
        content: const Text('Semua item pada pesanan ini akan dihapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _resetCurrentOrder();
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            child: const Text('Kosongkan'),
          ),
        ],
      ),
    );
  }

  Future<void> _showMobileCartItemEditor(_PosCartItem item) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final primaryColor = Theme.of(context).colorScheme.primary;
    final noteController = TextEditingController(text: item.note ?? '');
    var quantity = item.quantity;
    var splitQuantity = quantity > 1 ? 1 : 0;
    var selectedOrderType = item.orderType ?? _selectedOrderType;
    var discountEnabled = item.isDiscountEnabled;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, sheetSetState) => SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.82,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFFFAFCFF),
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF1E293B),
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Material(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(11),
                          child: InkWell(
                            onTap: () {
                              Navigator.of(sheetContext).pop();
                              _onChangeQuantity(item.id, 0);
                            },
                            borderRadius: BorderRadius.circular(11),
                            child: const SizedBox(
                              width: 40,
                              height: 40,
                              child: Icon(
                                Icons.delete_outline_rounded,
                                color: Color(0xFFB91C1C),
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _formatCurrency(item.activeUnitPrice),
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Jumlah',
                      style: TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: quantity > 1
                                ? () => sheetSetState(() {
                                    quantity--;
                                    if (quantity < 2) {
                                      splitQuantity = 0;
                                    } else if (splitQuantity >= quantity) {
                                      splitQuantity = quantity - 1;
                                    }
                                  })
                                : null,
                            icon: const Icon(Icons.remove_rounded),
                            color: const Color(0xFF475569),
                          ),
                          Expanded(
                            child: Text(
                              '$quantity',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF1E293B),
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => sheetSetState(() {
                              quantity++;
                              if (splitQuantity == 0) splitQuantity = 1;
                            }),
                            icon: const Icon(Icons.add_rounded),
                            color: primaryColor,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Tipe pesanan',
                      style: TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 13),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedOrderType,
                          isExpanded: true,
                          items: _orderTypeOptions
                              .map(
                                (option) => DropdownMenuItem<String>(
                                  value: option.$1,
                                  child: Text(option.$2),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              sheetSetState(() => selectedOrderType = value);
                            }
                          },
                        ),
                      ),
                    ),
                    if (item.discountedUnitPrice != null) ...[
                      const SizedBox(height: 12),
                      Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        child: SwitchListTile.adaptive(
                          value: discountEnabled,
                          onChanged: (value) =>
                              sheetSetState(() => discountEnabled = value),
                          activeThumbColor: primaryColor,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 13,
                          ),
                          title: Text(
                            item.promoLabel ?? 'Gunakan harga promo',
                            style: const TextStyle(
                              color: Color(0xFF334155),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Text(
                      'Catatan item',
                      style: TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    TextField(
                      controller: noteController,
                      autofocus: false,
                      minLines: 2,
                      maxLines: 3,
                      textInputAction: TextInputAction.done,
                      onTapOutside: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      decoration: InputDecoration(
                        hintText: 'Contoh: tanpa es, lebih pedas',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.all(13),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                      ),
                    ),
                    if (quantity > 1) ...[
                      const SizedBox(height: 14),
                      Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Jumlah yang dipisahkan',
                                style: TextStyle(
                                  color: Color(0xFF475569),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: splitQuantity > 1
                                  ? () => sheetSetState(() => splitQuantity--)
                                  : null,
                              icon: const Icon(Icons.remove_rounded, size: 18),
                              color: const Color(0xFF475569),
                            ),
                            SizedBox(
                              width: 20,
                              child: Text(
                                '$splitQuantity',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFF1E293B),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: splitQuantity < quantity - 1
                                  ? () => sheetSetState(() => splitQuantity++)
                                  : null,
                              icon: const Icon(Icons.add_rounded, size: 18),
                              color: primaryColor,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () {
                          final note = noteController.text.trim();
                          _splitCartItem(
                            item.id,
                            totalQuantity: quantity,
                            splitQuantity: splitQuantity,
                            orderType: selectedOrderType,
                            note: note.isEmpty ? null : note,
                            isDiscountEnabled: discountEnabled,
                          );
                          Navigator.of(sheetContext).pop();
                        },
                        icon: const Icon(Icons.call_split_rounded, size: 18),
                        label: Text('Pisahkan $splitQuantity item'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryColor,
                          minimumSize: const Size.fromHeight(44),
                          side: BorderSide(
                            color: primaryColor.withValues(alpha: 0.45),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: () {
                          final note = noteController.text.trim();
                          _replaceCartItem(
                            item.id,
                            item.copyWith(
                              quantity: quantity,
                              orderType: selectedOrderType,
                              note: note.isEmpty ? null : note,
                              clearNote: note.isEmpty,
                              isDiscountEnabled: discountEnabled,
                            ),
                          );
                          Navigator.of(sheetContext).pop();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Simpan perubahan'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    noteController.dispose();
  }

  Widget _buildOrderTypeSelector(Color primaryColor) {
    final option = _orderTypeOptions.firstWhere(
      (option) => option.$1 == _selectedOrderType,
      orElse: () => _orderTypeOptions.first,
    );

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: _showOrderTypePicker,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(option.$3, color: primaryColor, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tipe pesanan',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                  ],
                ),
              ),
              Text(
                option.$2,
                style: const TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF64748B),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<(String, String, IconData)> get _orderTypeOptions => [
    ('dine_in', 'Makan di tempat', Icons.table_restaurant_outlined),
    ('take_away', 'Bawa pulang', Icons.shopping_bag_outlined),
    ('shopee_food', 'ShopeeFood', Icons.storefront_outlined),
    ('go_food', 'GoFood', Icons.delivery_dining_outlined),
    ('grab_food', 'GrabFood', Icons.local_shipping_outlined),
  ];

  void _showOrderTypePicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          decoration: const BoxDecoration(
            color: Color(0xFFFAFCFF),
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Pilih tipe pesanan',
                style: TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tipe akan diterapkan ke seluruh item di keranjang.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
              ),
              const SizedBox(height: 12),
              for (final option in _orderTypeOptions) ...[
                _buildOrderTypeOption(option, sheetContext),
                const SizedBox(height: 7),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderTypeOption(
    (String, String, IconData) option,
    BuildContext sheetContext,
  ) {
    final selected = option.$1 == _selectedOrderType;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Material(
      color: selected ? primaryColor.withValues(alpha: 0.09) : Colors.white,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: () {
          _setOrderType(option.$1);
          Navigator.pop(sheetContext);
        },
        borderRadius: BorderRadius.circular(13),
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? primaryColor : const Color(0xFFE2E8F0),
            ),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Row(
            children: [
              Icon(
                option.$3,
                color: selected ? primaryColor : const Color(0xFF64748B),
                size: 19,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  option.$2,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFF1E3A8A)
                        : const Color(0xFF334155),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, color: primaryColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _setOrderType(String typeCode) {
    if (typeCode == _selectedOrderType) return;
    setState(() {
      _selectedOrderType = typeCode;
      _cartItems = _cartItems
          .map((item) => item.copyWith(orderType: typeCode))
          .toList(growable: false);
    });
    _recalculateCartPromotions();
  }

  // Stage 3: payment keeps method selection and confirmation visibly separate.
  Widget _buildPaymentScreen(ThemeData theme, Color primaryColor) {
    final changeAmount = (_tenderAmount - _totalPay).clamp(0, 1 << 31);
    final selectedOption = _selectedPaymentOption;
    final isCash =
        selectedOption != null && _isCashPaymentOption(selectedOption);
    final merchantOptions = _paymentOptions
        .where((option) => !_isCashPaymentOption(option))
        .toList(growable: false);
    final cashOptions = _paymentOptions
        .where(_isCashPaymentOption)
        .toList(growable: false);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        scrolledUnderElevation: 0,
        title: const Text(
          'Pembayaran',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        leading: IconButton(
          tooltip: 'Kembali ke keranjang',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => setState(() => _currentStage = _MobilePosStage.cart),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          _buildPaymentSummary(primaryColor),
          const SizedBox(height: 26),
          const Text(
            'Metode pembayaran',
            style: TextStyle(
              color: Color(0xFF1E293B),
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Pilih metode yang digunakan pelanggan.',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                if (merchantOptions.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(14, 12, 14, 5),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'METODE MERCHANT',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.45,
                        ),
                      ),
                    ),
                  ),
                  for (
                    var index = 0;
                    index < merchantOptions.length;
                    index++
                  ) ...[
                    _buildPaymentMethodOption(
                      merchantOptions[index],
                      primaryColor,
                    ),
                    if (index < merchantOptions.length - 1)
                      const Padding(
                        padding: EdgeInsets.only(left: 61),
                        child: Divider(height: 1, color: Color(0xFFF0F3F7)),
                      ),
                  ],
                ],
                if (merchantOptions.isNotEmpty && cashOptions.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(14, 7, 14, 7),
                    child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                  ),
                if (cashOptions.isNotEmpty) ...[
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      14,
                      merchantOptions.isNotEmpty ? 0 : 12,
                      14,
                      5,
                    ),
                    child: const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'PEMBAYARAN DI KASIR',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.45,
                        ),
                      ),
                    ),
                  ),
                  for (var index = 0; index < cashOptions.length; index++) ...[
                    _buildPaymentMethodOption(cashOptions[index], primaryColor),
                    if (index < cashOptions.length - 1)
                      const Padding(
                        padding: EdgeInsets.only(left: 61),
                        child: Divider(height: 1, color: Color(0xFFF0F3F7)),
                      ),
                  ],
                ],
                if (_paymentOptions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Belum ada metode pembayaran yang tersedia.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
          if (isCash) ...[
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Uang diterima',
                    style: TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _manualTenderController,
                    keyboardType: TextInputType.number,
                    onChanged: (value) => setState(() {
                      _tenderAmount = int.tryParse(value) ?? 0;
                      _paymentErrorMessage = null;
                    }),
                    decoration: InputDecoration(
                      prefixText: 'Rp ',
                      prefixStyle: const TextStyle(
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w700,
                      ),
                      hintText: 'Masukkan nominal',
                      fillColor: const Color(0xFFF8FAFC),
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildQuickCashButton(_totalPay),
                      _buildQuickCashButton(50000),
                      _buildQuickCashButton(100000),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.keyboard_return_rounded,
                          color: Color(0xFF15803D),
                          size: 17,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Kembalian',
                            style: TextStyle(
                              color: Color(0xFF166534),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          _formatCurrency(changeAmount),
                          style: const TextStyle(
                            color: Color(0xFF166534),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else if (selectedOption != null) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 17,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      selectedOption.description?.trim().isNotEmpty == true
                          ? selectedOption.description!.trim()
                          : 'Pastikan pembayaran berhasil sebelum mengonfirmasi pesanan.',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 10.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_paymentErrorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _paymentErrorMessage!,
              style: const TextStyle(color: Color(0xFFDC2626), fontSize: 11.5),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: _isCommitting || selectedOption == null
                  ? null
                  : _confirmAndCommitOrder,
              icon: _isCommitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline_rounded, size: 19),
              label: Text(
                _isCommitting
                    ? 'Menyimpan pesanan…'
                    : 'Bayar ${_formatCurrency(_totalPay)}',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentMethodOption(
    SalesPaymentModeOption option,
    Color primaryColor,
  ) {
    final selected = option.remoteId == _selectedPaymentOption?.remoteId;
    final subtitle = option.description?.trim();
    final isCash = _isCashPaymentOption(option);
    final accentColor = isCash ? const Color(0xFF15803D) : primaryColor;
    return Semantics(
      selected: selected,
      button: true,
      label: 'Metode pembayaran ${option.name}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() {
            _selectedPaymentOption = option;
            _tenderAmount = _totalPay;
            _manualTenderController.text = _tenderAmount.toString();
            _paymentErrorMessage = null;
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(
              color: selected
                  ? accentColor.withValues(alpha: 0.075)
                  : Colors.transparent,
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: selected
                        ? accentColor.withValues(alpha: 0.13)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isCash
                        ? Icons.payments_outlined
                        : Icons.account_balance_wallet_outlined,
                    size: 18,
                    color: selected ? accentColor : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFF1E293B),
                          fontSize: 12,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w700,
                        ),
                      ),
                      if (subtitle?.isNotEmpty == true) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? accentColor : const Color(0xFFCBD5E1),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentSummary(Color primaryColor) {
    final itemCount = _cartItems.fold<int>(
      0,
      (total, item) => total + item.quantity,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'TOTAL UNTUK DIBAYAR',
          style: TextStyle(
            color: Color(0xFF64748B),
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.55,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          _formatCurrency(_totalPay),
          style: TextStyle(
            color: const Color(0xFF172554),
            fontSize: 27,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.75,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.receipt_long_outlined, color: primaryColor, size: 15),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '$itemCount item · ${_orderTypeLabel()}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.only(top: 15),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
      ],
    );
  }

  bool _isCashPaymentOption(SalesPaymentModeOption option) {
    final label = '${option.name} ${option.description ?? ''}'.toLowerCase();
    return label.contains('cash') || label.contains('tunai');
  }

  Widget _buildQuickCashButton(int amount) {
    return OutlinedButton(
      onPressed: () {
        setState(() {
          _tenderAmount = amount;
          _manualTenderController.text = amount.toString();
          _paymentErrorMessage = null;
        });
      },
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF475569),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        minimumSize: const Size(0, 38),
        padding: const EdgeInsets.symmetric(horizontal: 11),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
      ),
      child: Text(_formatCurrency(amount)),
    );
  }
}
