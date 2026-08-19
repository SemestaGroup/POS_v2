import 'package:flutter/material.dart';

import '../../../../core/printing/services/printer_rendering_service.dart';
import '../../../../core/printing/services/printer_transport_service.dart';
import '../../../../core/services/sync/pos_v2_runtime_session_store.dart';
import '../../../settings/printers/controllers/printer_settings_controller.dart';
import '../models/shift_history_item.dart';
import '../services/shift_report_builder.dart';
import '../services/shift_history_service.dart';

class ShiftHistoryController extends ChangeNotifier {
  ShiftHistoryController._();

  static final ShiftHistoryController instance = ShiftHistoryController._();

  List<ShiftHistoryItem> _allRows = <ShiftHistoryItem>[];
  bool _isLoading = false;
  String? _errorMessage;
  String _selectedFilter = 'all';
  int? _printingShiftId;

  List<ShiftHistoryItem> get allRows => List.unmodifiable(_allRows);
  List<ShiftHistoryItem> get items => allRows;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;
  String get selectedFilter => _selectedFilter;
  int? get printingShiftId => _printingShiftId;

  List<ShiftHistoryItem> get filteredRows {
    if (_selectedFilter == 'open') {
      return _allRows.where((r) => !r.isClosed).toList();
    } else if (_selectedFilter == 'closed') {
      return _allRows.where((r) => r.isClosed).toList();
    }
    return _allRows;
  }

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _allRows = await ShiftHistoryService.instance.fetchShiftHistory();
    } catch (e) {
      _errorMessage = 'Gagal memuat riwayat shift: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setFilter(String filter) {
    if (_selectedFilter == filter) return;
    _selectedFilter = filter;
    notifyListeners();
  }

  Future<void> printThermalReport(BuildContext context, ShiftHistoryItem shift) async {
    if (_printingShiftId != null) return;
    _printingShiftId = shift.id;
    notifyListeners();

    try {
      final session = PosV2RuntimeSessionStore.instance.currentSession;
      final tenantId = session?.tenantId ?? 1;

      final document = await ShiftReportBuilder.instance.buildReport(
        shiftSessionId: shift.id,
        tenantId: tenantId,
        isEod: false,
      );

      if (document != null && context.mounted) {
        final state = PrinterSettingsController.instance.stateNotifier.value;
        final printer =
            state.printers
                .where((p) => p.isActive && p.roles.contains('cashier'))
                .firstOrNull ??
            state.printers.where((p) => p.isActive).firstOrNull;

        if (printer != null) {
          final renderResult = await PrinterRenderingService.instance.render(
            printer,
            document,
          );
          final dispatchResult = await PrinterTransportService.instance
              .dispatch(printer, renderResult);

          if (!dispatchResult.success && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Gagal mencetak: ${dispatchResult.message ?? "Printer error"}',
                ),
                backgroundColor: Colors.redAccent,
              ),
            );
          } else if (dispatchResult.success && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Laporan shift berhasil dicetak'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Printer thermal belum diatur di Pengaturan.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mencetak laporan: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      _printingShiftId = null;
      notifyListeners();
    }
  }
}
