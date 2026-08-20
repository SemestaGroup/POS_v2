import 'package:flutter/material.dart';

import '../../controllers/shift_history_controller.dart';
import '../../models/shift_history_item.dart';
import '../../widgets/shift_history_card.dart';
import '../../widgets/shift_history_detail_modal.dart';
import '../../widgets/shift_history_filter_bar.dart';

class ShiftHistoryContent extends StatefulWidget {
  final bool isTablet;

  const ShiftHistoryContent({super.key, this.isTablet = false});

  @override
  State<ShiftHistoryContent> createState() => _ShiftHistoryContentState();
}

class _ShiftHistoryContentState extends State<ShiftHistoryContent> {
  final ShiftHistoryController _controller = ShiftHistoryController.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final allRows = _controller.allRows;
        final filteredRows = _controller.filteredRows;

        final openCount = allRows.where((r) => !r.isClosed).length;
        final closedCount = allRows.where((r) => r.isClosed).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.history_toggle_off_rounded,
                      color: primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Riwayat Shift Kasir',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.2,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Histori sesi kasir & rekonsiliasi kas',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: _controller.load,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.refresh_rounded,
                              size: 14,
                              color: primaryColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Refresh',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: primaryColor,
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

            // Horizontal Filter Chips Segment
            Container(
              height: 48,
              color: Colors.white,
              child: ShiftHistoryFilterBar(
                selectedFilter: _controller.selectedFilter,
                onFilterSelected: _controller.setFilter,
                totalCount: allRows.length,
                openCount: openCount,
                closedCount: closedCount,
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Content Area in Expanded
            Expanded(
              child: _controller.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : _controller.errorMessage != null
                  ? LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    size: 48,
                                    color: Colors.redAccent,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _controller.errorMessage!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: _controller.load,
                                    icon: const Icon(Icons.refresh_rounded),
                                    label: const Text('Coba Lagi'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  : filteredRows.isEmpty
                  ? RefreshIndicator(
                      onRefresh: _controller.load,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.5,
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.history_toggle_off_rounded,
                                    size: 48,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'Belum ada riwayat shift',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Data riwayat shift akan muncul di sini.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _controller.load,
                      child: widget.isTablet
                          ? GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    childAspectRatio: 1.6,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                  ),
                              itemCount: filteredRows.length,
                              itemBuilder: (context, index) {
                                final shift = filteredRows[index];
                                return ShiftHistoryCard(
                                  shift: shift,
                                  isPrinting:
                                      _controller.printingShiftId == shift.id,
                                  onTap: () => _openDetailModal(shift),
                                  onPrint: () => _controller.printThermalReport(
                                    context,
                                    shift,
                                  ),
                                );
                              },
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: filteredRows.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final shift = filteredRows[index];
                                return ShiftHistoryCard(
                                  shift: shift,
                                  isPrinting:
                                      _controller.printingShiftId == shift.id,
                                  onTap: () => _openDetailModal(shift),
                                  onPrint: () => _controller.printThermalReport(
                                    context,
                                    shift,
                                  ),
                                );
                              },
                            ),
                    ),
            ),
          ],
        );
      },
    );
  }

  void _openDetailModal(ShiftHistoryItem shift) {
    ShiftHistoryDetailModal.show(
      context,
      shift: shift,
      isPrinting: _controller.printingShiftId == shift.id,
      onPrint: () => _controller.printThermalReport(context, shift),
    );
  }
}
