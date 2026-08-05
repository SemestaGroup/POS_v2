import 'package:flutter/material.dart';

import 'package:flinkpos_v2/modules/master_data/shared/widgets/master_data_page_widgets.dart';
import 'package:flinkpos_v2/modules/master_data/inventory/views/inventory_items/tablet_landscape/view.dart';
import 'package:flinkpos_v2/modules/master_data/inventory/views/purchase_marketplace/tablet_landscape/view.dart';
import 'package:flinkpos_v2/modules/master_data/inventory/views/purchase_orders/tablet_landscape/view.dart';

class _InventoryMenuDefinition {
  final String title;
  final Widget view;

  const _InventoryMenuDefinition({
    required this.title,
    required this.view,
  });
}

class InventoryShellView extends StatefulWidget {
  const InventoryShellView({super.key});

  @override
  State<InventoryShellView> createState() => _InventoryShellViewState();
}

class _InventoryShellViewState extends State<InventoryShellView> {
  int _selectedTabIndex = 0;

  List<_InventoryMenuDefinition> get _menuItems {
    return const [
      _InventoryMenuDefinition(
        title: 'Inventory Items',
        view: InventoryItemsView(),
      ),
      _InventoryMenuDefinition(
        title: 'Marketplace',
        view: PurchaseMarketplaceView(),
      ),
      _InventoryMenuDefinition(
        title: 'Purchase Orders',
        view: PurchaseOrdersView(),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 240,
            padding: const EdgeInsets.fromLTRB(24, 24, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                right: BorderSide(color: theme.dividerColor.withOpacity(0.45)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 4),
                Text(
                  'Inventory',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Kelola stok dan pembelian pusat dalam satu interface.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 22),
                for (var i = 0; i < _menuItems.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () => setState(() => _selectedTabIndex = i),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: _selectedTabIndex == i
                              ? primaryColor.withOpacity(0.08)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          _menuItems[i].title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _selectedTabIndex == i
                                ? primaryColor
                                : const Color(0xFF374151),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _menuItems[_selectedTabIndex].view,
            ),
          ),
        ],
      ),
    );
  }
}
