import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../../core/services/sync/pos_v2_runtime_session_store.dart';
import '../../../../../../../l10n/app_localizations.dart';
import '../../../../../../../core/services/sync/pos_v2_customer_service.dart';
import '../../../../../operations/shift/models/active_shift_store.dart';
import '../../../../shared/models/pos_catalog_store.dart';
import '../../../../shared/models/pos_promotion_service.dart';
import '../../../../shared/models/sales_order_store.dart';
import '../../../../shared/widgets/customer_picker_dialog.dart';
import '../../../../orders/shared/orders_history_sync_service.dart';

import '../../../../orders/views/tablet_landscape/view.dart';

enum _PosQuickAction {
  discount,
  clearOrder,
  cancelOrder,
  cashFlow,
  syncData,
  closeOutlet,
  settings,
}

class _PosCartItem {
  const _PosCartItem({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.regularUnitPrice,
    required this.quantity,
    this.productRemoteId,
    this.discountedUnitPrice,
    this.promoLabel,
    this.isDiscountEnabled = false,
    this.orderType,
    this.note,
  });

  final String id;
  final String name;
  final String imageUrl;
  final int regularUnitPrice;
  final int quantity;
  final String? productRemoteId;
  final int? discountedUnitPrice;
  final String? promoLabel;
  final bool isDiscountEnabled;
  final String? orderType;
  final String? note;

  int get activeUnitPrice => isDiscountEnabled && discountedUnitPrice != null
      ? discountedUnitPrice!
      : regularUnitPrice;

  _PosCartItem copyWith({
    String? id,
    String? name,
    String? imageUrl,
    int? regularUnitPrice,
    int? quantity,
    String? productRemoteId,
    int? discountedUnitPrice,
    String? promoLabel,
    bool? isDiscountEnabled,
    String? orderType,
    String? note,
  }) {
    return _PosCartItem(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      regularUnitPrice: regularUnitPrice ?? this.regularUnitPrice,
      quantity: quantity ?? this.quantity,
      productRemoteId: productRemoteId ?? this.productRemoteId,
      discountedUnitPrice: discountedUnitPrice ?? this.discountedUnitPrice,
      promoLabel: promoLabel ?? this.promoLabel,
      isDiscountEnabled: isDiscountEnabled ?? this.isDiscountEnabled,
      orderType: orderType ?? this.orderType,
      note: note ?? this.note,
    );
  }
}

class PosWorkspaceView extends StatefulWidget {
  const PosWorkspaceView({
    super.key,
    this.embedded = false,
    this.onSectionSelected,
  });

  final bool embedded;
  final ValueChanged<int>? onSectionSelected;

  @override
  State<PosWorkspaceView> createState() => _PosWorkspaceViewState();
}

class _PosWorkspaceViewState extends State<PosWorkspaceView> {
  final TextEditingController _searchController = TextEditingController();
  bool _isPromoFilterActive = false;
  final List<_PosCartItem> _cartItems = [];
  String _selectedOrderType = 'dine_in';
  String _orderNote = '';
  int _lineSequence = 1;
  String? _appliedOrderPromoLabel;
  int _orderLevelDiscountAmount = 0;
  PosPromotionResult? _selectedPromotion;
  String? _editingOrderId;
  String? _editingOrderToken;
  DateTime? _editingOrderCreatedAt;

  bool _isPlaceholderImage(String url) {
    if (url.isEmpty) return true;
    final lower = url.toLowerCase();
    return lower.contains('no_image') ||
        lower.contains('default') ||
        lower.contains('placeholder');
  }

  PosCatalogSnapshot _catalogSnapshot = const PosCatalogSnapshot();
  String? _selectedBrandName;
  String? _selectedCategoryName;
  PosCustomerRecord? _selectedCustomer;

  void _handlePendingResumeOrder() {
    final pendingOrder = SalesOrderStore.instance.resumeOrderNotifier.value;
    if (pendingOrder == null) {
      return;
    }

    if (_cartItems.isNotEmpty) {
      _commitOrder(1); // Auto-save current workspace as active order
    }

    setState(() {
      _cartItems
        ..clear()
        ..addAll(
          pendingOrder.items.map(
            (item) => _PosCartItem(
              id: item.id,
              name: item.name,
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
          ),
        );
      _selectedOrderType = pendingOrder.orderType;
      _orderNote = pendingOrder.note ?? '';
      _editingOrderId = pendingOrder.id;
      _editingOrderToken = pendingOrder.token;
      _editingOrderCreatedAt = pendingOrder.createdAt;
      _appliedOrderPromoLabel = pendingOrder.appliedPromotionName;
      _orderLevelDiscountAmount = pendingOrder.orderLevelDiscountAmount;
      _selectedPromotion = pendingOrder.appliedPromotionName == null
          ? null
          : PosPromotionResult(
              remoteId: pendingOrder.appliedPromotionRemoteId ?? '',
              name: pendingOrder.appliedPromotionName!,
              promoType: pendingOrder.appliedPromotionType ?? 'discount',
              discountAmount: pendingOrder.orderLevelDiscountAmount,
              displayAmount: pendingOrder.orderLevelDiscountAmount.toString(),
              matchedTotal: pendingOrder.subtotalAmount,
              summary:
                  pendingOrder.appliedPromotionSummary == 'PROMO_NOT_APPLICABLE'
                  ? AppLocalizations.of(context)!.promoNotApplicable
                  : (pendingOrder.appliedPromotionSummary ?? ''),
            );
      if (pendingOrder.customerRemoteId.isNotEmpty) {
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

    SalesOrderStore.instance.clearPendingResumeOrder();
  }

  @override
  void initState() {
    super.initState();
    _catalogSnapshot = PosCatalogStore.instance.snapshotNotifier.value;
    PosCatalogStore.instance.snapshotNotifier.addListener(
      _handleCatalogSnapshotChanged,
    );
    SalesOrderStore.instance.resumeOrderNotifier.addListener(
      _handlePendingResumeOrder,
    );
    _handlePendingResumeOrder();
    unawaited(OrdersHistorySyncService.instance.ensureSynced());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PosCatalogStore.instance.refresh();
      _ensureDefaultCustomerSelected();
    });
    if (widget.embedded) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
        ),
      );
    });
  }

  void _handleCatalogSnapshotChanged() {
    if (!mounted) {
      return;
    }
    setState(() {
      _catalogSnapshot = PosCatalogStore.instance.snapshotNotifier.value;
      final brands = _catalogSnapshot.brands;
      if (brands.isEmpty) {
        _selectedBrandName = null;
        _selectedCategoryName = null;
      } else if (_selectedBrandName != null &&
          !brands.contains(_selectedBrandName)) {
        _selectedBrandName = null;
        _selectedCategoryName = null;
      }
    });
  }

  @override
  void dispose() {
    PosCatalogStore.instance.snapshotNotifier.removeListener(
      _handleCatalogSnapshotChanged,
    );
    SalesOrderStore.instance.resumeOrderNotifier.removeListener(
      _handlePendingResumeOrder,
    );
    _searchController.dispose();
    if (!widget.embedded) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  Future<void> _ensureDefaultCustomerSelected() async {
    if (_selectedCustomer != null) {
      return;
    }

    try {
      final defaultCustomer = await PosV2CustomerService.instance
          .ensureDefaultWalkInCustomer();
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedCustomer = defaultCustomer;
      });
    } catch (_) {
      // Keep POS usable; save flow will block if customer is still missing.
    }
  }

  String _customerDisplayName(BuildContext context) {
    final customer = _selectedCustomer;
    if (customer == null) {
      return AppLocalizations.of(context)!.walkInCustomer;
    }
    if (customer.isDefaultWalkIn ||
        customer.name == PosV2CustomerService.defaultWalkInName) {
      return AppLocalizations.of(context)!.walkInCustomer;
    }
    return customer.name;
  }

  String? _customerSecondaryLine(BuildContext context) {
    final customer = _selectedCustomer;
    if (customer == null) {
      return null;
    }
    if ((customer.phone ?? '').trim().isNotEmpty && customer.phone != '-') {
      return customer.phone!.trim();
    }
    if ((customer.address ?? '').trim().isNotEmpty && customer.address != '-') {
      return customer.address!.trim();
    }
    return null;
  }

  bool get _isCartEmpty => _cartItems.isEmpty;

  int get _subtotalAmount => _cartItems.fold(
    0,
    (sum, item) => sum + (item.activeUnitPrice * item.quantity),
  );

  int get _totalPay =>
      (_subtotalAmount - _orderLevelDiscountAmount).clamp(0, 1 << 31);

  int get _openOrdersCount => SalesOrderStore.instance.countForStatuses({1, 6});

  int _parseCurrency(String value) {
    final numeric = value.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(numeric) ?? 0;
  }

  String _formatCurrency(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();

    for (var index = 0; index < digits.length; index++) {
      final position = digits.length - index;
      buffer.write(digits[index]);
      if (position > 1 && position % 3 == 1) {
        buffer.write('.');
      }
    }

    return 'Rp. $buffer';
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

  Map<String, dynamic> _applySelectedOrderTypePricing(
    Map<String, dynamic> product,
  ) {
    final mapped = Map<String, dynamic>.from(product);
    final orderTypePrices =
        (mapped['orderTypePrices'] as Map?)?.cast<String, int>() ??
        const <String, int>{};
    final selectedPrice =
        orderTypePrices[_toBackendOrderTypeCode(_selectedOrderType)];
    if (selectedPrice == null || selectedPrice <= 0) {
      return mapped;
    }

    final originalRegularPrice =
        (mapped['regularPrice'] as int?) ??
        _parseCurrency(mapped['price'] as String);
    final currentDiscounted = mapped['discountedPrice'] as int?;
    int? nextDiscountedPrice = currentDiscounted;
    if (currentDiscounted != null && originalRegularPrice > currentDiscounted) {
      final discountAmount = originalRegularPrice - currentDiscounted;
      nextDiscountedPrice = (selectedPrice - discountAmount).clamp(
        0,
        selectedPrice,
      );
    }

    mapped['regularPrice'] = selectedPrice;
    mapped['discountedPrice'] = nextDiscountedPrice;
    mapped['price'] = _formatCurrency(nextDiscountedPrice ?? selectedPrice);
    return mapped;
  }

  List<PosPromotionMatchItem> _buildPromotionMatchItems() {
    final productIndex = <String, Map<String, dynamic>>{};
    for (final product in _catalogSnapshot.products) {
      final remoteId = product['remoteId']?.toString();
      if (remoteId == null || remoteId.isEmpty) {
        continue;
      }
      productIndex[remoteId] = product;
    }

    return _cartItems
        .where(
          (item) =>
              item.productRemoteId != null && item.productRemoteId!.isNotEmpty,
        )
        .map((item) {
          final metadata =
              productIndex[item.productRemoteId!] ?? const <String, dynamic>{};
          return PosPromotionMatchItem(
            productRemoteId: item.productRemoteId!,
            productName: item.name,
            categoryRemoteId: metadata['categoryRemoteId']?.toString(),
            brandRemoteId: metadata['brandRemoteId']?.toString(),
            activeUnitPrice: item.activeUnitPrice,
            quantity: item.quantity,
          );
        })
        .toList(growable: false);
  }

  List<String> _availableBrands(List<Map<String, dynamic>> products) {
    final result = <String>[];
    final seen = <String>{};
    for (final product in products) {
      final brand = product['brandName']?.toString();
      if (brand == null || brand.isEmpty || seen.contains(brand)) {
        continue;
      }
      seen.add(brand);
      result.add(brand);
    }
    return result;
  }

  List<String> _availableCategoriesForBrand(
    List<Map<String, dynamic>> products,
    String? brandName,
  ) {
    final result = <String>[];
    final seen = <String>{};
    for (final product in products) {
      final productBrand = product['brandName']?.toString();
      final category = product['categoryName']?.toString();
      if (brandName != null &&
          brandName.isNotEmpty &&
          productBrand != brandName) {
        continue;
      }
      if (category == null || category.isEmpty || seen.contains(category)) {
        continue;
      }
      seen.add(category);
      result.add(category);
    }
    return result;
  }

  void _selectBrand(String brandName) {
    setState(() {
      if (_selectedBrandName == brandName) {
        _selectedBrandName = null;
        _selectedCategoryName = null;
        return;
      }
      _selectedBrandName = brandName;
      _selectedCategoryName = null;
    });
  }

  String _orderTypeLabel(BuildContext context, [String? rawValue]) {
    final value = rawValue ?? _selectedOrderType;
    switch (value) {
      case 'take_away':
        return AppLocalizations.of(context)!.takeAway;
      case 'shopee_food':
        return 'ShopeeFood';
      case 'go_food':
        return 'GoFood';
      case 'grab_food':
        return 'GrabFood';
      default:
        return AppLocalizations.of(context)!.dineIn;
    }
  }

  String _orderNoteTabLabel(BuildContext context) {
    if (_orderNote.trim().isEmpty) {
      return AppLocalizations.of(context)!.orderNote;
    }

    const maxLength = 16;
    final trimmed = _orderNote.trim();
    if (trimmed.length <= maxLength) {
      return trimmed;
    }

    return '${trimmed.substring(0, maxLength - 2)}..';
  }

  String _newLineId() => 'line-${_lineSequence++}';

  void _addProductToCart(Map<String, dynamic> product) {
    final name = product['name'] as String;
    final parsedDisplayPrice = _parseCurrency(product['price'] as String);
    final regularUnitPrice =
        (product['regularPrice'] as int?) ?? parsedDisplayPrice;
    final discountedUnitPrice = product['discountedPrice'] as int?;
    final currentIndex = _cartItems.indexWhere(
      (item) => item.name == name && item.orderType == _selectedOrderType,
    );

    setState(() {
      if (currentIndex >= 0) {
        final currentItem = _cartItems[currentIndex];
        _cartItems[currentIndex] = currentItem.copyWith(
          quantity: currentItem.quantity + 1,
          orderType: _selectedOrderType,
        );
        return;
      }

      _cartItems.insert(
        0,
        _PosCartItem(
          id: _newLineId(),
          name: name,
          imageUrl: product['image'] as String,
          regularUnitPrice: regularUnitPrice,
          quantity: 1,
          productRemoteId: product['remoteId'] as String?,
          discountedUnitPrice: discountedUnitPrice,
          promoLabel: product['promo'] as String?,
          isDiscountEnabled: discountedUnitPrice != null,
          orderType: _selectedOrderType,
          note: null,
        ),
      );
    });
  }

  void _removeCartItem(String itemId) {
    setState(() {
      _cartItems.removeWhere((item) => item.id == itemId);
    });
  }

  int _findCartItemIndex(String itemId) =>
      _cartItems.indexWhere((item) => item.id == itemId);

  void _replaceCartItem(String itemId, _PosCartItem item) {
    final index = _findCartItemIndex(itemId);
    if (index < 0) {
      return;
    }

    setState(() {
      _cartItems[index] = item;
    });
  }

  void _splitCartItem(
    String itemId, {
    required int totalQuantity,
    required int splitQuantity,
    required String orderType,
    required String? note,
    required bool isDiscountEnabled,
  }) {
    final index = _findCartItemIndex(itemId);
    if (index < 0) {
      return;
    }

    final currentItem = _cartItems[index];
    if (totalQuantity < 2) {
      _showOrderActionFeedback(
        AppLocalizations.of(context)!.splitItemMinQuantityMessage,
      );
      return;
    }

    final safeSplitQuantity = splitQuantity.clamp(1, totalQuantity - 1);
    final remainingQuantity = totalQuantity - safeSplitQuantity;

    setState(() {
      _cartItems[index] = currentItem.copyWith(
        quantity: remainingQuantity,
        orderType: orderType,
        note: note,
        isDiscountEnabled: isDiscountEnabled,
      );
      _cartItems.insert(
        index + 1,
        currentItem.copyWith(
          id: _newLineId(),
          quantity: safeSplitQuantity,
          orderType: orderType,
          note: note,
          isDiscountEnabled: isDiscountEnabled,
        ),
      );
    });
  }

  Future<void> _showDiscountDialog() async {
    final promotions = await PosPromotionService.instance
        .getApplicablePromotions(
          items: _buildPromotionMatchItems(),
          orderTypeCode: _toBackendOrderTypeCode(_selectedOrderType),
        );
    if (!mounted) {
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        String numpadInput = '';
        bool isPercent = false;
        final primaryColor = Theme.of(context).colorScheme.primary;

        return StatefulBuilder(
          builder: (context, dialogSetState) {
            void handleNumpad(String key) {
              dialogSetState(() {
                if (key == 'C') {
                  numpadInput = '';
                } else if (key == '<') {
                  if (numpadInput.isNotEmpty) {
                    numpadInput = numpadInput.substring(
                      0,
                      numpadInput.length - 1,
                    );
                  }
                } else {
                  if (key == '000' && numpadInput.isEmpty) return;
                  if (isPercent) {
                    if (numpadInput.length < 3) {
                      final newStr = numpadInput + key;
                      final val = int.tryParse(newStr) ?? 0;
                      if (val <= 100) numpadInput = newStr;
                    }
                  } else {
                    if (numpadInput.length < 8) {
                      numpadInput += key;
                    }
                  }
                }
              });
            }

            Widget buildNumBtn(
              String label, {
              IconData? icon,
              Color? color,
              Color? textColor,
            }) {
              return Material(
                color: color ?? Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => handleNumpad(
                    icon != null
                        ? (icon == Icons.backspace_outlined ? '<' : 'C')
                        : label,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: Center(
                    child: icon != null
                        ? Icon(icon, color: textColor ?? Colors.black87)
                        : Text(
                            label,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: textColor ?? Colors.black87,
                            ),
                          ),
                  ),
                ),
              );
            }

            final parsedInput = int.tryParse(numpadInput) ?? 0;

            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                width: 720,
                height: 580,
                padding: const EdgeInsets.all(0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.of(context)!.choosePromo,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              AppLocalizations.of(context)!.choosePromoSubtitle,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Expanded(
                              child: promotions.isEmpty
                                  ? Center(
                                      child: Text(
                                        AppLocalizations.of(
                                          context,
                                        )!.noApplicablePromotionsMessage,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    )
                                  : ListView(
                                      children: [
                                        for (final promo in promotions)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 12,
                                            ),
                                            child: InkWell(
                                              onTap: () {
                                                setState(() {
                                                  _appliedOrderPromoLabel =
                                                      promo.name;
                                                  _orderLevelDiscountAmount =
                                                      promo.discountAmount;
                                                  _selectedPromotion = promo;
                                                });
                                                Navigator.pop(context);
                                              },
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 16,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      _appliedOrderPromoLabel ==
                                                          promo.name
                                                      ? primaryColor.withValues(
                                                          alpha: 0.08,
                                                        )
                                                      : Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  border: Border.all(
                                                    color:
                                                        _appliedOrderPromoLabel ==
                                                            promo.name
                                                        ? primaryColor
                                                        : Colors.grey.shade200,
                                                  ),
                                                  boxShadow: [
                                                    if (_appliedOrderPromoLabel !=
                                                        promo.name)
                                                      BoxShadow(
                                                        color: Colors.black
                                                            .withValues(
                                                              alpha: 0.02,
                                                            ),
                                                        blurRadius: 8,
                                                        offset: const Offset(
                                                          0,
                                                          2,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          Icons
                                                              .local_offer_outlined,
                                                          size: 20,
                                                          color:
                                                              _appliedOrderPromoLabel ==
                                                                  promo.name
                                                              ? primaryColor
                                                              : Colors
                                                                    .grey
                                                                    .shade600,
                                                        ),
                                                        const SizedBox(
                                                          width: 12,
                                                        ),
                                                        Expanded(
                                                          child: Text(
                                                            promo.name,
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              fontWeight:
                                                                  _appliedOrderPromoLabel ==
                                                                      promo.name
                                                                  ? FontWeight
                                                                        .bold
                                                                  : FontWeight
                                                                        .w600,
                                                              color:
                                                                  _appliedOrderPromoLabel ==
                                                                      promo.name
                                                                  ? primaryColor
                                                                  : Colors
                                                                        .black87,
                                                            ),
                                                          ),
                                                        ),
                                                        Text(
                                                          '- ${_formatCurrency(promo.discountAmount)}',
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 14,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w800,
                                                                color:
                                                                    Colors.red,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      promo.summary ==
                                                              'PROMO_NOT_APPLICABLE'
                                                          ? AppLocalizations.of(
                                                              context,
                                                            )!.promoNotApplicable
                                                          : promo.summary,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors
                                                            .grey
                                                            .shade600,
                                                        height: 1.35,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 4,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            promo.promoType ==
                                                                'bundling'
                                                            ? Colors
                                                                  .blue
                                                                  .shade50
                                                            : Colors
                                                                  .orange
                                                                  .shade50,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              999,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        promo.promoType ==
                                                                'bundling'
                                                            ? 'Bundling'
                                                            : 'Discount',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color:
                                                              promo.promoType ==
                                                                  'bundling'
                                                              ? Colors
                                                                    .blue
                                                                    .shade800
                                                              : Colors
                                                                    .orange
                                                                    .shade800,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                            ),
                            if (_orderLevelDiscountAmount > 0)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _appliedOrderPromoLabel = null;
                                      _orderLevelDiscountAmount = 0;
                                      _selectedPromotion = null;
                                    });
                                    Navigator.pop(context);
                                  },
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    size: 16,
                                    color: Colors.red,
                                  ),
                                  label: Text(
                                    AppLocalizations.of(
                                      context,
                                    )!.removePromoAction,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Container(width: 1, color: Colors.grey.shade200),
                    Container(
                      width: 320,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(22),
                          bottomRight: Radius.circular(22),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.manualDiscount,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => dialogSetState(() {
                                      isPercent = false;
                                      numpadInput = '';
                                    }),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: !isPercent
                                            ? primaryColor
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: !isPercent
                                            ? [
                                                const BoxShadow(
                                                  color: Colors.black12,
                                                  blurRadius: 4,
                                                  offset: Offset(0, 2),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        AppLocalizations.of(
                                          context,
                                        )!.discountTypeRp,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: !isPercent
                                              ? Colors.white
                                              : Colors.black54,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => dialogSetState(() {
                                      isPercent = true;
                                      numpadInput = '';
                                    }),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: isPercent
                                            ? primaryColor
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: isPercent
                                            ? [
                                                const BoxShadow(
                                                  color: Colors.black12,
                                                  blurRadius: 4,
                                                  offset: Offset(0, 2),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        AppLocalizations.of(
                                          context,
                                        )!.discountTypePercent,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isPercent
                                              ? Colors.white
                                              : Colors.black54,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.only(
                              left: 16,
                              right: 8,
                              top: 12,
                              bottom: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    isPercent
                                        ? (parsedInput > 0
                                              ? '$parsedInput %'
                                              : '0 %')
                                        : _formatCurrency(parsedInput),
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: parsedInput > 0
                                          ? Colors.black87
                                          : Colors.grey.shade400,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(
                                    Icons.cancel,
                                    color: Colors.grey,
                                    size: 20,
                                  ),
                                  onPressed: () => handleNumpad('C'),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: Column(
                              children: [
                                Expanded(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(child: buildNumBtn('1')),
                                      const SizedBox(width: 8),
                                      Expanded(child: buildNumBtn('2')),
                                      const SizedBox(width: 8),
                                      Expanded(child: buildNumBtn('3')),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(child: buildNumBtn('4')),
                                      const SizedBox(width: 8),
                                      Expanded(child: buildNumBtn('5')),
                                      const SizedBox(width: 8),
                                      Expanded(child: buildNumBtn('6')),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(child: buildNumBtn('7')),
                                      const SizedBox(width: 8),
                                      Expanded(child: buildNumBtn('8')),
                                      const SizedBox(width: 8),
                                      Expanded(child: buildNumBtn('9')),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(child: buildNumBtn('000')),
                                      const SizedBox(width: 8),
                                      Expanded(child: buildNumBtn('0')),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: buildNumBtn(
                                          '<',
                                          icon: Icons.backspace_outlined,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton(
                              onPressed: parsedInput > 0
                                  ? () {
                                      setState(() {
                                        if (isPercent) {
                                          _appliedOrderPromoLabel =
                                              '${AppLocalizations.of(context)!.discount} $parsedInput%';
                                          _orderLevelDiscountAmount =
                                              (_subtotalAmount *
                                                      parsedInput /
                                                      100)
                                                  .round();
                                          _selectedPromotion = null;
                                        } else {
                                          _appliedOrderPromoLabel =
                                              AppLocalizations.of(
                                                context,
                                              )!.manualDiscount;
                                          _orderLevelDiscountAmount =
                                              parsedInput;
                                          _selectedPromotion = null;
                                        }
                                      });
                                      Navigator.pop(context);
                                    }
                                  : null,
                              style: FilledButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                AppLocalizations.of(context)!.applyDiscount,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<SalesOrderLineItem> _buildOrderLines() {
    return _cartItems
        .map(
          (item) => SalesOrderLineItem(
            id: item.id,
            name: item.name,
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
  }

  void _resetCurrentOrder() {
    setState(() {
      _cartItems.clear();
      _orderNote = '';
      _selectedOrderType = 'dine_in';
      _editingOrderId = null;
      _editingOrderToken = null;
      _editingOrderCreatedAt = null;
      _appliedOrderPromoLabel = null;
      _orderLevelDiscountAmount = 0;
      _selectedPromotion = null;
      _selectedCustomer = null;
    });
    unawaited(_ensureDefaultCustomerSelected());
  }

  void _showOrderActionFeedback(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
    );
  }

  Future<void> _commitOrder(int statusCode) async {
    final l10n = AppLocalizations.of(context)!;
    if (statusCode == 2) {
      _showOrderActionFeedback(l10n.featureNotWiredMessage(l10n.payNow));
      return;
    }

    if (_cartItems.isEmpty) {
      _showOrderActionFeedback(l10n.addProductFirstMessage);
      return;
    }

    await ActiveShiftStore.instance.refresh();
    final activeShift = ActiveShiftStore.instance.activeShiftNotifier.value;
    if (PosV2RuntimeSessionStore.instance.currentSession?.staffId?.isNotEmpty ==
            true &&
        activeShift == null) {
      _showOrderActionFeedback(l10n.shiftRequiredBeforeOrderMessage);
      return;
    }

    await _ensureDefaultCustomerSelected();
    final customer = _selectedCustomer;
    if (customer == null || customer.remoteId.trim().isEmpty) {
      _showOrderActionFeedback(l10n.customerSelectionRequiredMessage);
      return;
    }

    SalesOrderStore.instance.createOrder(
      statusCode: statusCode,
      items: _buildOrderLines(),
      customerName: customer.isDefaultWalkIn
          ? PosV2CustomerService.defaultWalkInName
          : customer.name,
      customerRemoteId: customer.remoteId,
      customerLocalId: customer.localId,
      customerPhone: customer.phone,
      customerAddress: customer.address,
      appliedPromotionRemoteId: _selectedPromotion?.remoteId,
      appliedPromotionName: _selectedPromotion?.name,
      appliedPromotionType: _selectedPromotion?.promoType,
      appliedPromotionSummary: _selectedPromotion?.summary,
      existingOrderId: _editingOrderId,
      existingOrderToken: _editingOrderToken,
      existingCreatedAt: _editingOrderCreatedAt,
      orderType: _selectedOrderType,
      note: _orderNote,
      orderLevelDiscountAmount: _orderLevelDiscountAmount,
    );

    _resetCurrentOrder();

    switch (statusCode) {
      case 1:
        _showOrderActionFeedback(l10n.activeOrderCreatedMessage);
        return;
      case 2:
        _showOrderActionFeedback(l10n.closedOrderCreatedMessage);
        return;
      case 5:
        _showOrderActionFeedback(l10n.voidOrderCreatedMessage);
        return;
      case 6:
        _showOrderActionFeedback(l10n.parkedOrderCreatedMessage);
        return;
    }
  }

  void _handleQuickAction(_PosQuickAction action) {
    final l10n = AppLocalizations.of(context)!;

    switch (action) {
      case _PosQuickAction.discount:
        _showDiscountDialog();
        return;
      case _PosQuickAction.clearOrder:
        _resetCurrentOrder();
        return;
      case _PosQuickAction.cancelOrder:
        _commitOrder(5);
        return;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(switch (action) {
              _PosQuickAction.cashFlow => l10n.featureNotWiredMessage(
                l10n.cashFlowMenu,
              ),
              _PosQuickAction.syncData => l10n.featureNotWiredMessage(
                l10n.syncDataAction,
              ),
              _PosQuickAction.closeOutlet => l10n.featureNotWiredMessage(
                l10n.closeOutletAction,
              ),
              _PosQuickAction.settings => l10n.featureNotWiredMessage(
                l10n.settings,
              ),
              _PosQuickAction.discount => '',
              _PosQuickAction.clearOrder => '',
              _PosQuickAction.cancelOrder => '',
            }),
          ),
        );
    }
  }

  void _showOrderTypeMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final options = [
      ('dine_in', l10n.dineIn, Icons.table_restaurant_rounded),
      ('take_away', l10n.takeAway, Icons.shopping_bag_outlined),
      ('shopee_food', 'ShopeeFood', Icons.storefront_outlined),
      ('go_food', 'GoFood', Icons.delivery_dining_rounded),
      ('grab_food', 'GrabFood', Icons.local_shipping_outlined),
    ];

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: Container(
            width: 360,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 28,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.selectOrderType,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.selectOrderTypeSubtitle,
                  style: TextStyle(fontSize: 11, color: Colors.black54),
                ),
                const SizedBox(height: 16),
                for (final option in options)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedOrderType = option.$1;
                          final updatedItems = _cartItems.map((item) {
                            return item.copyWith(orderType: option.$1);
                          }).toList();
                          _cartItems.clear();
                          _cartItems.addAll(updatedItems);
                        });
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: _selectedOrderType == option.$1
                              ? primaryColor.withValues(alpha: 0.08)
                              : const Color(0xFFF7F8FC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _selectedOrderType == option.$1
                                ? primaryColor
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              option.$3,
                              size: 18,
                              color: _selectedOrderType == option.$1
                                  ? primaryColor
                                  : Colors.black54,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                option.$2,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _selectedOrderType == option.$1
                                      ? primaryColor
                                      : Colors.black87,
                                ),
                              ),
                            ),
                            if (_selectedOrderType == option.$1)
                              Icon(
                                Icons.check_circle_rounded,
                                size: 18,
                                color: primaryColor,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showOrderNoteDialog(BuildContext context) {
    final controller = TextEditingController(text: _orderNote);
    final primaryColor = Theme.of(context).colorScheme.primary;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 400,
              maxHeight: MediaQuery.sizeOf(context).height * 0.72,
            ),
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 28,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.orderNote,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppLocalizations.of(context)!.orderNoteSubtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F8FC),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: TextField(
                        controller: controller,
                        minLines: 3,
                        maxLines: 4,
                        keyboardType: TextInputType.multiline,
                        textAlignVertical: TextAlignVertical.top,
                        strutStyle: const StrutStyle(
                          fontSize: 13,
                          height: 1.35,
                          forceStrutHeight: true,
                        ),
                        style: const TextStyle(fontSize: 13, height: 1.35),
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(
                            context,
                          )!.enterNotesHere,
                          hintStyle: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(AppLocalizations.of(context)!.cancel),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _orderNote = controller.text.trim();
                            });
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(AppLocalizations.of(context)!.save),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCustomerSearchDialog(BuildContext context) async {
    final selected = await showCustomerPickerDialog(
      context,
      initiallySelected: _selectedCustomer,
    );
    if (!mounted || selected == null) {
      return;
    }

    setState(() {
      _selectedCustomer = selected;
    });
  }

  void _showCartItemOptionsDialog(BuildContext context, String itemId) {
    FocusScope.of(context).unfocus(); // Dismiss keyboard if search is active
    final primaryColor = Theme.of(context).colorScheme.primary;
    final cartItem = _cartItems.where((item) => item.id == itemId).firstOrNull;
    if (cartItem == null) {
      return;
    }

    final noteController = TextEditingController(text: cartItem.note ?? '');
    final orderTypeOptions = [
      ('dine_in', AppLocalizations.of(context)!.dineIn),
      ('take_away', AppLocalizations.of(context)!.takeAway),
      ('shopee_food', 'ShopeeFood'),
      ('go_food', 'GoFood'),
      ('grab_food', 'GrabFood'),
    ];

    showDialog(
      context: context,
      builder: (context) {
        var quantity = cartItem.quantity;
        var selectedOrderType = cartItem.orderType ?? _selectedOrderType;
        var discountEnabled = cartItem.isDiscountEnabled;
        var splitQuantity = quantity > 1 ? 1 : 0;

        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: SizedBox(
                width: 680,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              cartItem.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              _removeCartItem(cartItem.id);
                              Navigator.pop(context);
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.delete_outline,
                                size: 22,
                                color: Colors.red.shade400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // LEFT COLUMN
                              Expanded(
                                flex: 13,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          AppLocalizations.of(
                                            context,
                                          )!.quantity,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                            color: Colors.black54,
                                          ),
                                        ),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(
                                              30,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              InkWell(
                                                onTap: () {
                                                  if (quantity > 1) {
                                                    dialogSetState(() {
                                                      quantity -= 1;
                                                      if (quantity <= 1) {
                                                        splitQuantity = 0;
                                                      } else if (splitQuantity >=
                                                          quantity) {
                                                        splitQuantity =
                                                            quantity - 1;
                                                      }
                                                    });
                                                  }
                                                },
                                                borderRadius:
                                                    BorderRadius.circular(30),
                                                child: Padding(
                                                  padding: const EdgeInsets.all(
                                                    8.0,
                                                  ),
                                                  child: Icon(
                                                    Icons.remove,
                                                    size: 16,
                                                    color: Colors.grey.shade700,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                constraints:
                                                    const BoxConstraints(
                                                      minWidth: 36,
                                                    ),
                                                alignment: Alignment.center,
                                                child: Text(
                                                  '$quantity',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                              InkWell(
                                                onTap: () {
                                                  dialogSetState(() {
                                                    quantity += 1;
                                                    if (splitQuantity == 0) {
                                                      splitQuantity = 1;
                                                    }
                                                  });
                                                },
                                                borderRadius:
                                                    BorderRadius.circular(30),
                                                child: Padding(
                                                  padding: const EdgeInsets.all(
                                                    8.0,
                                                  ),
                                                  child: Icon(
                                                    Icons.add,
                                                    size: 16,
                                                    color: primaryColor,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      AppLocalizations.of(context)!.orderType,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    DropdownButtonFormField<String>(
                                      initialValue: selectedOrderType,
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: Colors.grey.shade50,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 12,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                      ),
                                      items: orderTypeOptions
                                          .map(
                                            (option) =>
                                                DropdownMenuItem<String>(
                                                  value: option.$1,
                                                  child: Text(option.$2),
                                                ),
                                          )
                                          .toList(),
                                      onChanged: (value) {
                                        if (value == null) {
                                          return;
                                        }
                                        dialogSetState(() {
                                          selectedOrderType = value;
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      AppLocalizations.of(context)!.note,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    TextField(
                                      controller: noteController,
                                      minLines: 4,
                                      maxLines: 5,
                                      keyboardType: TextInputType.multiline,
                                      textAlignVertical: TextAlignVertical.top,
                                      strutStyle: const StrutStyle(
                                        fontSize: 13,
                                        height: 1.4,
                                        forceStrutHeight: true,
                                      ),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: AppLocalizations.of(
                                          context,
                                        )!.anySpecialRequests,
                                        hintStyle: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade400,
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey.shade50,
                                        contentPadding: const EdgeInsets.all(
                                          14,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.grey.shade200,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.grey.shade200,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: primaryColor,
                                            width: 1.2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: Container(
                                  width: 1,
                                  color: Colors.grey.shade200,
                                ),
                              ),
                              // RIGHT COLUMN
                              Expanded(
                                flex: 10,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (cartItem.discountedUnitPrice !=
                                        null) ...[
                                      SwitchListTile.adaptive(
                                        value: discountEnabled,
                                        contentPadding: EdgeInsets.zero,
                                        activeThumbColor: primaryColor,
                                        title: Text(
                                          cartItem.promoLabel ??
                                              AppLocalizations.of(
                                                context,
                                              )!.discount,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        subtitle: Text(
                                          discountEnabled
                                              ? AppLocalizations.of(
                                                  context,
                                                )!.productDiscountEnabled
                                              : AppLocalizations.of(
                                                  context,
                                                )!.productDiscountDisabled,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54,
                                          ),
                                        ),
                                        onChanged: (value) {
                                          dialogSetState(() {
                                            discountEnabled = value;
                                          });
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                      Divider(
                                        color: Colors.grey.shade200,
                                        height: 1,
                                      ),
                                      const SizedBox(height: 24),
                                    ],
                                    if (quantity > 1) ...[
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            AppLocalizations.of(
                                              context,
                                            )!.splitQuantityLabel,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                              color: Colors.black54,
                                            ),
                                          ),
                                          Container(
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(30),
                                            ),
                                            child: Row(
                                              children: [
                                                InkWell(
                                                  onTap: () {
                                                    if (splitQuantity > 1) {
                                                      dialogSetState(() {
                                                        splitQuantity -= 1;
                                                      });
                                                    }
                                                  },
                                                  borderRadius:
                                                      BorderRadius.circular(30),
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          8.0,
                                                        ),
                                                    child: Icon(
                                                      Icons.remove,
                                                      size: 16,
                                                      color:
                                                          Colors.grey.shade700,
                                                    ),
                                                  ),
                                                ),
                                                Container(
                                                  constraints:
                                                      const BoxConstraints(
                                                        minWidth: 36,
                                                      ),
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    '$splitQuantity',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ),
                                                InkWell(
                                                  onTap: () {
                                                    if (splitQuantity <
                                                        quantity - 1) {
                                                      dialogSetState(() {
                                                        splitQuantity += 1;
                                                      });
                                                    }
                                                  },
                                                  borderRadius:
                                                      BorderRadius.circular(30),
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          8.0,
                                                        ),
                                                    child: Icon(
                                                      Icons.add,
                                                      size: 16,
                                                      color: primaryColor,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.info_outline,
                                              size: 16,
                                              color: Colors.blue.shade600,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                AppLocalizations.of(
                                                  context,
                                                )!.splitPreview(
                                                  quantity - splitQuantity,
                                                  splitQuantity,
                                                ),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.blue.shade800,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 46,
                                        child: OutlinedButton.icon(
                                          onPressed: quantity > 1
                                              ? () {
                                                  _splitCartItem(
                                                    cartItem.id,
                                                    totalQuantity: quantity,
                                                    splitQuantity:
                                                        splitQuantity,
                                                    orderType:
                                                        selectedOrderType,
                                                    note:
                                                        noteController.text
                                                            .trim()
                                                            .isEmpty
                                                        ? null
                                                        : noteController.text
                                                              .trim(),
                                                    isDiscountEnabled:
                                                        discountEnabled,
                                                  );
                                                  Navigator.pop(context);
                                                }
                                              : null,
                                          icon: const Icon(
                                            Icons.call_split,
                                            size: 18,
                                          ),
                                          label: Text(
                                            AppLocalizations.of(
                                              context,
                                            )!.splitItem,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                            ),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: primaryColor,
                                            side: BorderSide(
                                              color: primaryColor.withValues(
                                                alpha: 0.5,
                                              ),
                                              width: 1.5,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (cartItem.discountedUnitPrice == null &&
                                        quantity <= 1) ...[
                                      Center(
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            top: 40,
                                          ),
                                          child: Text(
                                            AppLocalizations.of(
                                              context,
                                            )!.noAdditionalOptions,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Colors.grey.shade400,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                        border: Border(
                          top: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            _replaceCartItem(
                              cartItem.id,
                              cartItem.copyWith(
                                quantity: quantity,
                                orderType: selectedOrderType,
                                note: noteController.text.trim().isEmpty
                                    ? null
                                    : noteController.text.trim(),
                                isDiscountEnabled: discountEnabled,
                              ),
                            );
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.saveDetails,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final content = Row(
      children: [
        _buildSecondarySidebar(theme, primaryColor),
        Expanded(flex: 5, child: _buildMainContent(theme, primaryColor)),
        _buildCartSidebar(theme, primaryColor),
      ],
    );
    final scaledContent = MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(widget.embedded ? 0.92 : 1)),
      child: content,
    );

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: widget.embedded
          ? ColoredBox(
              color: theme.scaffoldBackgroundColor,
              child: scaledContent,
            )
          : Scaffold(
              resizeToAvoidBottomInset: false,
              backgroundColor: theme.scaffoldBackgroundColor,
              body: scaledContent,
            ),
    );
  }

  Widget _buildSecondarySidebar(ThemeData theme, Color primaryColor) {
    final l10n = AppLocalizations.of(context)!;
    final allProducts = _catalogSnapshot.products
        .map(_applySelectedOrderTypePricing)
        .toList(growable: false);
    final brandNames = _availableBrands(allProducts);
    final selectedBrandName = brandNames.contains(_selectedBrandName)
        ? _selectedBrandName
        : null;
    final categories = _availableCategoriesForBrand(
      allProducts,
      selectedBrandName,
    );
    final selectedCategoryName = categories.contains(_selectedCategoryName)
        ? _selectedCategoryName
        : null;

    return Container(
      width: widget.embedded ? 100 : 150,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(5, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0),
            child: Material(
              color: selectedCategoryName == null
                  ? primaryColor.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  setState(() {
                    _selectedBrandName = null;
                    _selectedCategoryName = null;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.widgets_rounded,
                        size: 20,
                        color: selectedCategoryName == null
                            ? primaryColor
                            : Colors.grey.shade500,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.all,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: 12,
                            fontWeight: selectedCategoryName == null
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: selectedCategoryName == null
                                ? primaryColor
                                : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: brandNames.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        l10n.catalogEmptySubtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 11,
                          height: 1.5,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    itemCount: brandNames.length,
                    itemBuilder: (context, index) {
                      final brand = brandNames[index];
                      final isExpanded = brand == selectedBrandName;
                      final brandCategories = _availableCategoriesForBrand(
                        allProducts,
                        brand,
                      );

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          decoration: BoxDecoration(
                            color: isExpanded
                                ? primaryColor.withValues(alpha: 0.04)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isExpanded
                                  ? primaryColor.withValues(alpha: 0.15)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => _selectBrand(brand),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 14,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            brand,
                                            // 💡 Di sini letak FONT SIZE untuk nama Brand
                                            style: TextStyle(
                                              color: isExpanded
                                                  ? primaryColor
                                                  : Colors.grey.shade700,
                                              fontWeight: isExpanded
                                                  ? FontWeight.w800
                                                  : FontWeight.w600,
                                              fontSize:
                                                  10, // <-- Ubah angka 12 ini untuk mengatur ukuran
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          isExpanded
                                              ? Icons.keyboard_arrow_up_rounded
                                              : Icons
                                                    .keyboard_arrow_down_rounded,
                                          size: 18,
                                          color: isExpanded
                                              ? primaryColor
                                              : Colors.grey.shade400,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOutCubic,
                                alignment: Alignment.topCenter,
                                child: isExpanded && brandCategories.isNotEmpty
                                    ? Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          12,
                                          0,
                                          12,
                                          12,
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: brandCategories.map((
                                            category,
                                          ) {
                                            final isSelected =
                                                category ==
                                                selectedCategoryName;
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 4,
                                              ),
                                              child: Material(
                                                color: isSelected
                                                    ? primaryColor
                                                    : Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                child: InkWell(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  onTap: () {
                                                    setState(() {
                                                      _selectedCategoryName =
                                                          isSelected
                                                          ? null
                                                          : category;
                                                    });
                                                  },
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 10,
                                                        ),
                                                    child: Text(
                                                      category,
                                                      style: TextStyle(
                                                        color: isSelected
                                                            ? Colors.white
                                                            : Colors
                                                                  .grey
                                                                  .shade700,
                                                        fontWeight: isSelected
                                                            ? FontWeight.w700
                                                            : FontWeight.w500,
                                                        fontSize: 10,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(ThemeData theme, Color primaryColor) {
    final products = _catalogSnapshot.products
        .map(_applySelectedOrderTypePricing)
        .toList(growable: true);
    final brandNames = _availableBrands(products);
    final selectedBrandName = brandNames.contains(_selectedBrandName)
        ? _selectedBrandName
        : null;
    final categoryNames = _availableCategoriesForBrand(
      products,
      selectedBrandName,
    );
    final selectedCategoryName = categoryNames.contains(_selectedCategoryName)
        ? _selectedCategoryName
        : null;

    products.sort((a, b) {
      if (_isPromoFilterActive) {
        final bool aHasPromo = a['promo'] != null;
        final bool bHasPromo = b['promo'] != null;
        if (aHasPromo && !bHasPromo) return -1;
        if (!aHasPromo && bHasPromo) return 1;
      }
      return (a['name'] as String).compareTo(b['name'] as String);
    });

    final query = _searchController.text.trim().toLowerCase();
    final visibleProducts = products.where((product) {
      if (selectedBrandName != null &&
          product['brandName']?.toString() != selectedBrandName) {
        return false;
      }
      if (selectedCategoryName != null &&
          product['categoryName']?.toString() != selectedCategoryName) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      return (product['name'] as String).toLowerCase().contains(query);
    }).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14.0, 10.0, 14.0, 14.0),
      child: Column(
        children: [
          SizedBox(
            height: 38,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    onTapOutside: (event) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: AppLocalizations.of(context)!.searchProduct,
                      hintStyle: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: Colors.grey,
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 0,
                        horizontal: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isPromoFilterActive = !_isPromoFilterActive;
                    });
                  },
                  icon: Icon(
                    Icons.local_offer_rounded,
                    size: 16,
                    color: _isPromoFilterActive
                        ? Colors.white
                        : Colors.red.shade700,
                  ),
                  label: Text(
                    AppLocalizations.of(context)!.promo,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: _isPromoFilterActive
                          ? Colors.white
                          : Colors.red.shade700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isPromoFilterActive
                        ? Colors.red.shade500
                        : Colors.red.shade50,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.table_restaurant_rounded, size: 16),
                  label: Text(
                    AppLocalizations.of(context)!.chooseTable,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black87,
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
                const SizedBox(width: 6),
                ElevatedButton.icon(
                  onPressed: () {
                    if (widget.onSectionSelected != null) {
                      widget.onSectionSelected!(1);
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OrdersShellView(),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.receipt_long_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  label: Row(
                    children: [
                      Text(
                        AppLocalizations.of(context)!.orders,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ValueListenableBuilder<List<SalesOrderRecord>>(
                          valueListenable:
                              SalesOrderStore.instance.recordsNotifier,
                          builder: (context, _, _) {
                            return Text(
                              '$_openOrdersCount',
                              style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: visibleProducts.isEmpty && !_catalogSnapshot.isLoaded
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          AppLocalizations.of(context)!.syncStatusPreparing,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  )
                : visibleProducts.isEmpty
                ? Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 320),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            color: Colors.grey.shade400,
                            size: 34,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            AppLocalizations.of(context)!.catalogEmptyTitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            AppLocalizations.of(context)!.catalogEmptySubtitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 208,
                          mainAxisExtent: 148,
                          crossAxisSpacing: 7,
                          mainAxisSpacing: 7,
                        ),
                    itemCount: visibleProducts.length,
                    itemBuilder: (context, index) {
                      final product = visibleProducts[index];
                      return _buildProductCard(primaryColor, product);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Color primaryColor, Map<String, dynamic> product) {
    final l10n = AppLocalizations.of(context)!;
    final name = product['name'] as String;
    final matchedItem = _cartItems
        .where((item) => item.name == name)
        .firstOrNull;
    final isSelected = matchedItem != null;
    const selectedBorderColor = Color(0xFFA5D6A7);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _addProductToCart(product),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? selectedBorderColor : Colors.grey.shade200,
              width: isSelected ? 2.0 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              height: 1.2,
                            ),
                          ),
                          if (product['promo'] != null) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                product['promo']!,
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 54,
                        height: double.infinity,
                        color: Colors.grey.shade100,
                        child:
                            _isPlaceholderImage(
                              product['image']?.toString() ?? '',
                            )
                            ? const Center(
                                child: Icon(
                                  Icons.image_not_supported_rounded,
                                  color: Colors.black26,
                                  size: 20,
                                ),
                              )
                            : CachedNetworkImage(
                                imageUrl: product['image']! as String,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) =>
                                    const Center(
                                      child: Icon(
                                        Icons.image_not_supported_rounded,
                                        color: Colors.black26,
                                        size: 20,
                                      ),
                                    ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    product['price']!,
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${l10n.stock} : ${product['stock']}',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 9),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartSidebar(ThemeData theme, Color primaryColor) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      width: widget.embedded ? 248 : 262,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: theme.dividerColor)),
      ),
      child: Material(
        color: Colors.white,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 4.0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _showCustomerSearchDialog(context),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          bottomLeft: Radius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: 10,
                            top: 6,
                            bottom: 6,
                            right: 8,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.person_outline_rounded,
                                  size: 14,
                                  color: primaryColor,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.customer,
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 10,
                                      ),
                                    ),
                                    Text(
                                      _customerDisplayName(context),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (_customerSecondaryLine(context) != null)
                                      Text(
                                        _customerSecondaryLine(context)!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 9.5,
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
                    Material(
                      color: Colors.transparent,
                      child: PopupMenuButton<_PosQuickAction>(
                        onSelected: _handleQuickAction,
                        color: Colors.white,
                        elevation: 10,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(16),
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                            topRight: Radius.zero,
                          ),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 160,
                          maxWidth: 200,
                        ),
                        position: PopupMenuPosition.under,
                        itemBuilder: (context) =>
                            <PopupMenuEntry<_PosQuickAction>>[
                              _buildQuickActionItem(
                                value: _PosQuickAction.discount,
                                icon: Icons.discount_outlined,
                                label: AppLocalizations.of(context)!.discount,
                              ),
                              _buildQuickActionItem(
                                value: _PosQuickAction.clearOrder,
                                icon: Icons.layers_clear_outlined,
                                label: AppLocalizations.of(
                                  context,
                                )!.clearOrderAction,
                              ),
                              _buildQuickActionItem(
                                value: _PosQuickAction.cancelOrder,
                                icon: Icons.cancel_outlined,
                                label: AppLocalizations.of(
                                  context,
                                )!.cancelOrderAction,
                                isDanger: true,
                              ),
                              _buildQuickActionItem(
                                value: _PosQuickAction.cashFlow,
                                icon: Icons.account_balance_wallet_outlined,
                                label: AppLocalizations.of(
                                  context,
                                )!.cashFlowMenu,
                              ),
                              _buildQuickActionItem(
                                value: _PosQuickAction.syncData,
                                icon: Icons.sync_outlined,
                                label: AppLocalizations.of(
                                  context,
                                )!.syncDataAction,
                              ),
                              _buildQuickActionItem(
                                value: _PosQuickAction.closeOutlet,
                                icon: Icons.store_mall_directory_outlined,
                                label: AppLocalizations.of(
                                  context,
                                )!.closeOutletAction,
                              ),
                              const PopupMenuDivider(),
                              _buildQuickActionItem(
                                value: _PosQuickAction.settings,
                                icon: Icons.settings_outlined,
                                label: AppLocalizations.of(context)!.settings,
                              ),
                            ],
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Icon(
                            Icons.more_horiz_rounded,
                            size: 20,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _showOrderTypeMenu(context),
                      highlightColor: primaryColor.withValues(alpha: 0.1),
                      splashColor: primaryColor.withValues(alpha: 0.2),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey.shade300,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.room_service_rounded,
                              size: 14,
                              color: primaryColor,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _orderTypeLabel(context),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => _showOrderNoteDialog(context),
                      highlightColor: Colors.grey.shade200,
                      splashColor: Colors.grey.shade300,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey.shade300,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _orderNote.isEmpty
                                  ? Icons.edit_note_rounded
                                  : Icons.sticky_note_2_outlined,
                              size: 14,
                              color: _orderNote.isEmpty
                                  ? Colors.grey.shade500
                                  : primaryColor,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _orderNoteTabLabel(context),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _orderNote.isEmpty
                                      ? Colors.grey.shade600
                                      : primaryColor,
                                  fontSize: 10,
                                  fontWeight: _orderNote.isEmpty
                                      ? FontWeight.w500
                                      : FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isCartEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/mockups/pos/empty-order-items.webp',
                            width: 152,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            AppLocalizations.of(context)!.emptyCartTitle,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Colors.black45,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            AppLocalizations.of(context)!.emptyCartSubtitle,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.black38,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 6.0,
                      ),
                      children: _cartItems
                          .map((item) => _buildCartItem(primaryColor, item))
                          .toList(),
                    ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    offset: const Offset(0, -4),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Column(
                children: [
                  if (_appliedOrderPromoLabel != null) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.local_offer_rounded, size: 12, color: Colors.red.shade600),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _appliedOrderPromoLabel!,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _appliedOrderPromoLabel = null;
                              _orderLevelDiscountAmount = 0;
                              _selectedPromotion = null;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.close_rounded, size: 12, color: Colors.red.shade700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Divider(color: Colors.grey.shade200, height: 1),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.subtotal,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        _formatCurrency(_subtotalAmount),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.tax,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 10,
                        ),
                      ),
                      const Text(
                        'Rp. 0',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  if (_orderLevelDiscountAmount > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.discount,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          '- ${_formatCurrency(_orderLevelDiscountAmount)}',
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.totalPay,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        _formatCurrency(_totalPay),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _commitOrder(1),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFA5D6A7),
                      foregroundColor: const Color(0xFF2E7D32),
                      elevation: 0,
                      minimumSize: const Size(double.infinity, 32),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.send_rounded, size: 14),
                    label: Text(
                      l10n.sendToKitchen,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _commitOrder(6),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black87,
                            side: BorderSide(color: Colors.grey.shade300),
                            minimumSize: const Size(0, 32),
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            l10n.save,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _commitOrder(2),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF536DFE),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            minimumSize: const Size(0, 28),
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            l10n.payNow,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
    );
  }

  PopupMenuItem<_PosQuickAction> _buildQuickActionItem({
    required _PosQuickAction value,
    required IconData icon,
    required String label,
    bool isDanger = false,
  }) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final iconColor = isDanger ? const Color(0xFFF57C00) : primaryColor;
    final textColor = isDanger ? const Color(0xFFF57C00) : Colors.black87;

    return PopupMenuItem<_PosQuickAction>(
      value: value,
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(Color primaryColor, _PosCartItem item) {
    return InkWell(
      onTap: () => _showCartItemOptionsDialog(context, item.id),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Container(
                    color: Colors.grey.shade100,
                    child: _isPlaceholderImage(item.imageUrl)
                        ? const Center(
                            child: Icon(
                              Icons.image_not_supported_rounded,
                              size: 20,
                              color: Colors.grey,
                            ),
                          )
                        : CachedNetworkImage(
                            imageUrl: item.imageUrl,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) => const Center(
                              child: Icon(
                                Icons.image_not_supported_rounded,
                                size: 20,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                height: 1.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (item.promoLabel != null)
                            Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.promoLabel!,
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 7,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (item.note != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2, bottom: 2),
                          child: Text(
                            item.note!,
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey.shade500,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${item.quantity}x',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                          if (item.orderType != null &&
                              item.orderType != _selectedOrderType)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _orderTypeLabel(context, item.orderType),
                                style: TextStyle(
                                  color: Colors.orange.shade700,
                                  fontSize: 7,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          const Spacer(),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (item.discountedUnitPrice != null &&
                                  item.isDiscountEnabled)
                                Text(
                                  _formatCurrency(
                                    item.regularUnitPrice * item.quantity,
                                  ),
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 8,
                                    decoration: TextDecoration.lineThrough,
                                    height: 1.0,
                                  ),
                                ),
                              Text(
                                _formatCurrency(
                                  item.activeUnitPrice * item.quantity,
                                ),
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  height: 1.0,
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
            ],
          ),
        ),
      ),
    );
  }
}
