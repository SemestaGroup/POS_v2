import 'package:flutter/material.dart';

import '../../../../../modules/sales/pos/views/pos_workspace/mobile_portrait/view.dart';
import '../../../../../modules/operations/views/tablet_landscape/view.dart';
import '../../../../../l10n/app_localizations.dart';

class CashierMobileShellView extends StatefulWidget {
  const CashierMobileShellView({super.key});

  @override
  State<CashierMobileShellView> createState() => _CashierMobileShellViewState();
}

class _CashierMobileShellViewState extends State<CashierMobileShellView> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          PosWorkspaceMobileView(key: ValueKey('cashier_sales_mobile')),
          OperationsShellView(key: ValueKey('cashier_operations_mobile')),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.shopping_bag_rounded),
            label: l10n.sales,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.sync_alt_rounded),
            label: l10n.operations,
          ),
        ],
      ),
    );
  }
}
