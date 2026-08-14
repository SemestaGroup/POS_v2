import 'package:flutter/material.dart';

import '../../controllers/inventory_cart_controller.dart';
import '../../models/marketplace_item.dart';
import '../../services/marketplace_service.dart';
import '../../stores/inventory_read_stores.dart';
import '../../../stores/master_data_read_stores.dart';
import 'widgets/cart_dock.dart';
import 'widgets/tabs/inventory_tab.dart';
import 'widgets/tabs/marketplace_tab.dart';
import 'widgets/tabs/requests_tab.dart';

class InventoryMobileView extends StatefulWidget {
  const InventoryMobileView({super.key});

  @override
  State<InventoryMobileView> createState() => _InventoryMobileViewState();
}

class _InventoryMobileViewState extends State<InventoryMobileView> {
  final _inventoryStore = InventoryListStore.instance;
  final _categoryStore = CategoryListStore.instance;
  final _brandStore = BrandListStore.instance;
  final _requestStore = PurchaseOrderRequestStore.instance;
  final _purchaseOrderStore = PurchaseOrderStore.instance;
  final _marketplaceService = MarketplaceService.instance;
  late final InventoryCartController _cartController;

  List<MarketplaceItem> _remoteItems = <MarketplaceItem>[];
  bool _isMarketplaceLoading = true;

  @override
  void initState() {
    super.initState();
    _cartController = InventoryCartController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inventoryStore.refresh();
      _categoryStore.refresh();
      _brandStore.refresh();
      _requestStore.refresh();
      _purchaseOrderStore.refresh();
      _loadCachedMarketplace();
      _fetchMarketplace();
    });
  }

  @override
  void dispose() {
    _cartController.dispose();
    super.dispose();
  }

  Future<void> _loadCachedMarketplace() async {
    final items = await _marketplaceService.loadCachedItems();
    if (mounted) {
      setState(() {
        _remoteItems = items;
        _isMarketplaceLoading = false;
      });
    }
  }

  Future<void> _fetchMarketplace() async {
    try {
      final items = await _marketplaceService.fetchRemoteItems();
      if (items != null && mounted) {
        setState(() {
          _remoteItems = items;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isMarketplaceLoading = false);
      }
    }
  }

  Future<void> _refresh() async {
    await Future.wait([
      _inventoryStore.refresh(),
      _categoryStore.refresh(),
      _brandStore.refresh(),
      _requestStore.refresh(),
      _purchaseOrderStore.refresh(),
      _fetchMarketplace(),
    ]);
  }

  Future<void> _handleSubmitOrder() async {
    try {
      final poCode = await _cartController.submitOrder();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          backgroundColor: const Color(0xFF0F172A),
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF22C55E),
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Purchase order $poCode berhasil dibuat.',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          backgroundColor: const Color(0xFFEF4444),
          content: Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Gagal membuat purchase order: $error',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return DefaultTabController(
      length: 3,
      child: ColoredBox(
        color: theme.scaffoldBackgroundColor,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: .09),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SizedBox(
                height: 40,
                child: TabBar(
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: primaryColor,
                    borderRadius: const BorderRadius.all(Radius.circular(9)),
                  ),
                  labelColor: theme.colorScheme.onPrimary,
                  unselectedLabelColor: primaryColor,
                  labelStyle: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: const [
                    Tab(text: 'Stok'),
                    Tab(text: 'Marketplace'),
                    Tab(text: 'Pengajuan'),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  TabBarView(
                    children: [
                      const InventoryTab(),
                      MarketplaceTab(
                        remoteItems: _remoteItems,
                        isLoading: _isMarketplaceLoading,
                        cartController: _cartController,
                        onRefresh: _refresh,
                      ),
                      const RequestsTab(),
                    ],
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 12,
                    child: FloatingCartDock(
                      cartController: _cartController,
                      primaryColor: primaryColor,
                      onSubmit: _handleSubmitOrder,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
