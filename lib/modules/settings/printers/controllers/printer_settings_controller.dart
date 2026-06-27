import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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

  Future<void> printTest(PrinterDeviceConfig printer) async {
    await Printing.layoutPdf(
      onLayout: (_) => _buildTestPdf(printer),
      name: 'printer-test-${printer.displayName}',
    );

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
  }

  Future<Uint8List> _buildTestPdf(PrinterDeviceConfig printer) async {
    final doc = pw.Document();
    final pageFormat = _pageFormatForPrinter(printer);
    final lines = _buildSampleLines(printer);

    doc.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(8),
        build: (context) => [
          pw.Text(
            'FlinkPOS Printer Test',
            style: pw.TextStyle(
              fontSize: 12 * printer.fontScale,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text('Printer: ${printer.displayName}', style: _metaStyle(printer)),
          pw.Text('Paper: ${printer.paperProfile.label}', style: _metaStyle(printer)),
          pw.Text(
            'Chars/line: ${printer.effectiveCharsPerLine}  •  Width: ${printer.effectiveWidthMm.toStringAsFixed(0)}mm',
            style: _metaStyle(printer),
          ),
          pw.SizedBox(height: 8),
          ...lines.map(
            (line) => pw.Padding(
              padding: pw.EdgeInsets.only(bottom: 2 * printer.lineSpacing),
              child: pw.Text(
                line,
                style: pw.TextStyle(fontSize: 9 * printer.fontScale),
              ),
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }

  pw.TextStyle _metaStyle(PrinterDeviceConfig printer) =>
      pw.TextStyle(fontSize: 8 * printer.fontScale, color: PdfColors.grey700);

  PdfPageFormat _pageFormatForPrinter(PrinterDeviceConfig printer) {
    switch (printer.paperProfile.id) {
      case 'sheet_a4':
        return PdfPageFormat.a4;
      case 'sheet_a5':
        return PdfPageFormat.a5;
      default:
        return PdfPageFormat(
          printer.effectiveWidthMm * PdfPageFormat.mm,
          240 * PdfPageFormat.mm,
          marginAll: 0,
        );
    }
  }

  List<String> _buildSampleLines(PrinterDeviceConfig printer) {
    final maxChars = printer.effectiveCharsPerLine;
    final separator = '-' * maxChars;
    final lines = <String>[
      _center('TEST PROFILE', maxChars),
      separator,
      _row('Order', '#TEST-001', maxChars),
      _row('Date', DateTime.now().toString().split('.').first, maxChars),
      separator,
      ..._wrap('1x Signature Latte Extra Shot with Oat Milk', maxChars),
      _row('   item disc', '-5.000', maxChars),
      ..._wrap('2x Butter Croissant', maxChars),
      separator,
      _row('Subtotal', '45.000', maxChars),
      _row('Discount', '-5.000', maxChars),
      _row('Total', '40.000', maxChars),
      _row('Cash', '50.000', maxChars),
      _row('Change', '10.000', maxChars),
      separator,
      _center('If 50mm and 80mm look the same, chars/line is wrong.', maxChars),
    ];
    return lines;
  }

  String _row(String left, String right, int maxChars) {
    if (left.length + right.length + 1 > maxChars) {
      final allowedLeft = (maxChars - right.length - 3).clamp(1, left.length);
      final truncated = left.substring(0, allowedLeft);
      left = '$truncated..';
    }
    final padding = maxChars - left.length - right.length;
    return '$left${' ' * (padding > 1 ? padding : 1)}$right';
  }

  String _center(String text, int maxChars) {
    final wrapped = _wrap(text, maxChars);
    return wrapped
        .map((line) {
          final spaces = ((maxChars - line.length) / 2).floor();
          final safeSpaces = spaces < 0 ? 0 : spaces;
          return '${' ' * safeSpaces}$line';
        })
        .join('\n');
  }

  List<String> _wrap(String text, int maxChars) {
    if (text.length <= maxChars) {
      return <String>[text];
    }
    final words = text.split(' ');
    final lines = <String>[];
    var current = '';
    for (final word in words) {
      if (current.isEmpty) {
        current = word;
      } else if ('$current $word'.length <= maxChars) {
        current = '$current $word';
      } else {
        lines.add(current);
        current = word;
      }
    }
    if (current.isNotEmpty) {
      lines.add(current);
    }
    return lines;
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
