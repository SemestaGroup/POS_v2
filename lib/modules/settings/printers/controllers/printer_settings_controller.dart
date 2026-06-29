import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../../../core/printing/models/printer_render_models.dart';
import '../../../../../core/printing/services/printer_rendering_service.dart';
import '../../../../../core/printing/services/printer_transport_service.dart';
import '../../../../../core/services/local/database_service.dart';
import '../../../../../core/services/sync/pos_v2_runtime_session_store.dart';
import '../models/printer_settings_models.dart';

class PrinterSettingsController {
  PrinterSettingsController._() {
    PosV2RuntimeSessionStore.instance.sessionNotifier.addListener(
      _handleSessionChanged,
    );
  }

  static final PrinterSettingsController instance = PrinterSettingsController._();

  final ValueNotifier<PrinterSettingsState> stateNotifier =
      ValueNotifier<PrinterSettingsState>(
    const PrinterSettingsState(
      isLoading: false,
      isSaving: false,
      printers: <PrinterDeviceConfig>[],
      availableBrands: <String>[],
    ),
  );

  void _handleSessionChanged() {
    refresh(silent: true);
  }

  Future<void> refresh({bool silent = false}) async {
    if (!silent) {
      stateNotifier.value = stateNotifier.value.copyWith(
        isLoading: true,
        clearError: true,
      );
    }

    try {
      final session = await _requireSession();
      final printerRows = await DatabaseService.instance.rawQuery(
        '''
        SELECT *
        FROM printer_device
        WHERE tenant_id = ?
          AND deleted_at IS NULL
        ORDER BY is_active DESC, display_name ASC, id ASC
        ''',
        <Object?>[session.tenantId],
      );
      final brandRows = await DatabaseService.instance.rawQuery(
        '''
        SELECT DISTINCT name
        FROM brand
        WHERE tenant_id = ?
          AND deleted_at IS NULL
          AND name IS NOT NULL
          AND name != ''
        ORDER BY name ASC
        ''',
        <Object?>[session.tenantId],
      );

      stateNotifier.value = stateNotifier.value.copyWith(
        isLoading: false,
        printers: printerRows
            .map((row) => PrinterDeviceConfig.fromRow(row))
            .toList(growable: false),
        availableBrands: brandRows
            .map((row) => row['name']?.toString() ?? '')
            .where((name) => name.trim().isNotEmpty)
            .toList(growable: false),
        clearError: true,
      );
    } catch (error) {
      stateNotifier.value = stateNotifier.value.copyWith(
        isLoading: false,
        errorMessage: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> savePrinter(PrinterDeviceConfig printer) async {
    final session = await _requireSession();
    await _runMutation(() async {
      final now = DateTime.now().toUtc().toIso8601String();
      await DatabaseService.instance.transaction((txn) async {
        if (printer.id > 0) {
          await txn.update(
            'printer_device',
            _toDbValues(printer, now, includeCreatedAt: false),
            where: 'id = ?',
            whereArgs: <Object?>[printer.id],
          );
        } else {
          await txn.insert(
            'printer_device',
            _toDbValues(printer, now, includeCreatedAt: true)
              ..['tenant_id'] = session.tenantId,
          );
        }
      });
    });
  }

  Future<void> deletePrinter(PrinterDeviceConfig printer) async {
    if (printer.id <= 0) {
      return;
    }
    await _runMutation(() async {
      final now = DateTime.now().toUtc().toIso8601String();
      await DatabaseService.instance.transaction((txn) async {
        await txn.update(
          'printer_device',
          <String, Object?>{'deleted_at': now, 'updated_at': now},
          where: 'id = ?',
          whereArgs: <Object?>[printer.id],
        );
      });
    });
  }

  Future<void> printTest(
    PrinterDeviceConfig printer, {
    PrinterDocumentType type = PrinterDocumentType.test,
  }) async {
    final document = PrinterRenderingService.instance.buildSampleDocument(
      printer,
      type,
    );
    final renderOutput = await PrinterRenderingService.instance.render(
      printer,
      document,
    );
    final dispatchResult =
        await PrinterTransportService.instance.dispatch(printer, renderOutput);

    if (printer.id > 0) {
      final now = DateTime.now().toUtc().toIso8601String();
      await DatabaseService.instance.transaction((txn) async {
        await txn.update(
          'printer_device',
          <String, Object?>{'last_tested_at': now, 'updated_at': now},
          where: 'id = ?',
          whereArgs: <Object?>[printer.id],
        );
      });
      await refresh(silent: true);
    }
    stateNotifier.value = stateNotifier.value.copyWith(
      lastDispatchResult: dispatchResult.success
          ? 'Printed via ${dispatchResult.channel}'
          : 'Failed via ${dispatchResult.channel}: ${dispatchResult.message ?? 'Unknown error'}',
    );
  }

  Future<void> _runMutation(Future<void> Function() action) async {
    stateNotifier.value = stateNotifier.value.copyWith(
      isSaving: true,
      clearError: true,
    );
    try {
      await action();
      await refresh(silent: true);
      stateNotifier.value = stateNotifier.value.copyWith(
        isSaving: false,
        clearError: true,
      );
    } catch (error) {
      stateNotifier.value = stateNotifier.value.copyWith(
        isSaving: false,
        errorMessage: error.toString().replaceFirst('Exception: ', ''),
      );
      rethrow;
    }
  }

  Future<PosV2RuntimeSession> _requireSession() async {
    final session = PosV2RuntimeSessionStore.instance.currentSession ??
        await PosV2RuntimeSessionStore.instance.restoreFromDatabase();
    if (session == null) {
      throw Exception('No active session found.');
    }
    return session;
  }

  Map<String, Object?> _toDbValues(
    PrinterDeviceConfig printer,
    String now, {
    required bool includeCreatedAt,
  }) {
    return <String, Object?>{
      'printer_key': printer.printerKey,
      'display_name': printer.displayName.trim(),
      'connection_type': printer.connectionType,
      'connection_target': _nullableText(printer.connectionTarget),
      'network_port': printer.networkPort,
      'paper_profile_id': printer.paperProfileId,
      'custom_width_mm': printer.paperProfileId == 'custom_roll'
          ? printer.customWidthMm
          : null,
      'chars_per_line': printer.charsPerLine,
      'font_scale': printer.fontScale,
      'line_spacing': printer.lineSpacing,
      'supports_autocut': printer.supportsAutoCut ? 1 : 0,
      'roles_json': jsonEncode(printer.roles),
      'role_brand_filters_json': jsonEncode(printer.roleBrandFilters),
      'notes': _nullableText(printer.notes),
      'is_active': printer.isActive ? 1 : 0,
      'updated_at': now,
      if (includeCreatedAt) 'created_at': now,
      'deleted_at': null,
    };
  }

  String? _nullableText(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
