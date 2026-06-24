import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../../l10n/app_localizations.dart';
import 'sales_metrics_view.dart';
import 'customer_metrics_view.dart';

class OwnerOverviewView extends StatefulWidget {
  const OwnerOverviewView({super.key});

  @override
  State<OwnerOverviewView> createState() => _OwnerOverviewViewState();
}

class _OwnerOverviewViewState extends State<OwnerOverviewView> {
  int _selectedTab = 0; // 0 for Sales, 1 for Customer
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    // Default date range: last 7 days
    final now = DateTime.now();
    _selectedDateRange = DateTimeRange(
      start: now.subtract(const Duration(days: 7)),
      end: now,
    );
  }

  void _selectDateRange(String rangeType) {
    final now = DateTime.now();
    DateTime start;
    DateTime end = now;

    switch (rangeType) {
      case 'today':
        start = DateTime(now.year, now.month, now.day);
        break;
      case 'yesterday':
        start = DateTime(now.year, now.month, now.day - 1);
        end = DateTime(now.year, now.month, now.day - 1, 23, 59, 59);
        break;
      case 'last7days':
        start = now.subtract(const Duration(days: 7));
        break;
      case 'last30days':
        start = now.subtract(const Duration(days: 30));
        break;
      case 'thisMonth':
        start = DateTime(now.year, now.month, 1);
        break;
      default:
        start = now.subtract(const Duration(days: 7));
    }

    setState(() {
      _selectedDateRange = DateTimeRange(start: start, end: end);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header (Tabs & Filters)
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0),
              child: _buildHeader(context, theme),
            ),
            const Divider(height: 1, color: Colors.transparent),

            // Body
            Expanded(
              child: _selectedTab == 0
                  ? const SalesMetricsView()
                  : const CustomerMetricsView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    final localeName = Localizations.localeOf(context).toLanguageTag();
    final lastModifiedAt = DateTime(2026, 6, 4, 11, 35);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row 1: Tabs and "Terakhir diubah"
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildTabs(context, theme),
            Text(
              AppLocalizations.of(context)!.lastModified(
                DateFormat.yMMMMd(localeName).format(lastModifiedAt),
                DateFormat.Hm(localeName).format(lastModifiedAt),
              ),
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 10),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Row 2: Filters
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildDateFilter(theme),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 32,
                      child: OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          side: BorderSide(color: theme.dividerColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.applyFilter,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              height: 32,
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  side: BorderSide(color: theme.colorScheme.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  AppLocalizations.of(context)!.dailySales,
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  void _showDateMenu(BuildContext context, ThemeData theme) async {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(button.size.bottomLeft(const Offset(0, 8)), ancestor: overlay),
        button.localToGlobal(button.size.bottomLeft(const Offset(0, 8)), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    final l10n = AppLocalizations.of(context)!;
    final String? result = await showMenu<String>(
      context: context,
      position: position,
      color: Colors.white,
      elevation: 10,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.zero,
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      items: [
        _buildPopupMenuItem(l10n.filterToday, 'today', theme),
        _buildPopupMenuItem(l10n.filterYesterday, 'yesterday', theme),
        _buildPopupMenuItem(l10n.filterLast7Days, 'last7days', theme),
        _buildPopupMenuItem(l10n.filterLast30Days, 'last30days', theme),
        _buildPopupMenuItem(l10n.filterThisMonth, 'thisMonth', theme),
      ],
    );

    if (result != null) {
      _selectDateRange(result);
    }
  }

  Widget _buildDateFilter(ThemeData theme) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final l10n = AppLocalizations.of(context)!;
    final dateText = _selectedDateRange != null
        ? '${dateFormat.format(_selectedDateRange!.start)} - ${dateFormat.format(_selectedDateRange!.end)}'
        : l10n.selectDate;

    return Builder(
      builder: (context) {
        return InkWell(
          onTap: () => _showDateMenu(context, theme),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: theme.dividerColor),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/mockups/dashboard/date-filter.webp', width: 14, height: 14),
                const SizedBox(width: 6),
                Text(
                  dateText,
                  style: const TextStyle(fontSize: 10, color: Colors.black87),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: Colors.black54,
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  PopupMenuItem<String> _buildPopupMenuItem(String text, String value, ThemeData theme) {
    return PopupMenuItem<String>(
      value: value,
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black87),
      ),
    );
  }

  Widget _buildTabs(BuildContext context, ThemeData theme) {
    return Stack(
      alignment: Alignment.bottomLeft,
      children: [
        // Inactive continuous line
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(height: 1.5, color: theme.dividerColor),
        ),
        // Tab Items
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTabItem(theme, AppLocalizations.of(context)!.sales, 0),
            _buildTabItem(theme, AppLocalizations.of(context)!.customer, 1),
            const SizedBox(
              width: 16,
            ), // Extra padding to let the continuous line extend a bit
          ],
        ),
      ],
    );
  }

  Widget _buildTabItem(ThemeData theme, String title, int index) {
    final isActive = _selectedTab == index;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTab = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.only(bottom: 8, left: 12, right: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? theme.colorScheme.primary : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
            color: isActive
                ? theme.colorScheme.primary
                : theme.textTheme.bodyMedium?.color,
          ),
        ),
      ),
    );
  }
}
