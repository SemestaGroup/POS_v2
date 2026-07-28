import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../../modules/overview/views/owner_overview/tablet_landscape/view.dart';
import '../../../../../modules/sales/pos/views/pos_workspace/mobile_portrait/view.dart';
import '../../../../../modules/operations/views/tablet_landscape/view.dart';
import '../../../../../modules/reports/views/tablet_landscape/view.dart';
import '../../../../../modules/master_data/views/tablet_landscape/view.dart';

class SupervisorMobileShellView extends StatefulWidget {
  const SupervisorMobileShellView({super.key});

  @override
  State<SupervisorMobileShellView> createState() => _SupervisorMobileShellViewState();
}

class _SupervisorMobileShellViewState extends State<SupervisorMobileShellView> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedIndex == 0
              ? 'Overview'
              : _selectedIndex == 1
                  ? l10n.sales
                  : _selectedIndex == 2
                      ? l10n.operations
                      : l10n.reports,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF111827)),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Color(0xFF6366F1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Flink POS',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Supervisor Portal',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.storage_rounded),
              title: const Text('Master Data'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) => Scaffold(
                      appBar: AppBar(
                        title: const Text('Master Data', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        elevation: 0,
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF111827),
                      ),
                      body: const MasterDataShellView(),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          OwnerOverviewView(key: ValueKey('supervisor_overview_mobile')),
          PosWorkspaceMobileView(key: ValueKey('supervisor_sales_mobile')),
          OperationsShellView(key: ValueKey('supervisor_operations_mobile')),
          ReportsShellView(key: ValueKey('supervisor_reports_mobile')),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Overview',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.shopping_bag_rounded),
            label: l10n.sales,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.sync_alt_rounded),
            label: l10n.operations,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.bar_chart_rounded),
            label: l10n.reports,
          ),
        ],
      ),
    );
  }
}
