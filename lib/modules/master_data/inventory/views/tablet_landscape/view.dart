import 'package:flutter/material.dart';

import 'package:flinkpos_v2/modules/master_data/inventory/views/inventory_items/tablet_landscape/view.dart';
import 'package:flinkpos_v2/modules/master_data/inventory/views/purchase_marketplace/tablet_landscape/view.dart';
import 'package:flinkpos_v2/modules/master_data/inventory/views/purchase_orders/tablet_landscape/view.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Kembali',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.inventory_2_rounded, size: 18, color: primaryColor),
            ),
            const SizedBox(width: 10),
            const Text(
              'Inventory',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryColor,
          unselectedLabelColor: Colors.grey.shade600,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          indicatorColor: primaryColor,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: 'Inventory Items'),
            Tab(text: 'Marketplace'),
            Tab(text: 'Purchase Orders'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          InventoryItemsView(),
          PurchaseMarketplaceView(),
          PurchaseOrdersView(),
        ],
      ),
    );
  }
}