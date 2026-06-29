import 'dart:convert';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../modules/settings/printers/models/printer_settings_models.dart';
import '../models/printer_render_models.dart';

class PrinterRenderingService {
  PrinterRenderingService._();

  static final PrinterRenderingService instance = PrinterRenderingService._();

  Future<PrinterRenderOutput> render(
    PrinterDeviceConfig printer,
    PrinterDocumentData document,
  ) async {
    final previewText = _buildPreviewText(printer, document);
    final pdfBytes = await _buildPdf(printer, document);
    final rawBytes = _buildRawBytes(printer, previewText);

    return PrinterRenderOutput(
      documentType: document.type,
      printer: printer,
      previewText: previewText,
      pdfBytes: pdfBytes,
      rawBytes: rawBytes,
    );
  }

  PrinterDocumentData buildSampleDocument(PrinterDeviceConfig printer, PrinterDocumentType type) {
    switch (type) {
      case PrinterDocumentType.receipt:
        return PrinterDocumentData(
          type: type,
          title: 'Receipt Sample',
          subtitle: 'Cashier receipt layout test',
          headerLines: <String>['FlinkPOS Cafe', 'Batam, Indonesia'],
          infoRows: <PrinterInfoRow>[
            const PrinterInfoRow(label: 'Order', value: '#TEST-001'),
            const PrinterInfoRow(label: 'Type', value: 'Dine In'),
            const PrinterInfoRow(label: 'Queue', value: 'A014'),
          ],
          items: const <PrinterLineItem>[
            PrinterLineItem(label: 'Signature Latte Extra Shot with Oat Milk', quantity: 1, amount: 35000),
            PrinterLineItem(label: 'Butter Croissant', quantity: 2, amount: 20000),
          ],
          summaryRows: const <PrinterSummaryRow>[
            PrinterSummaryRow(label: 'Subtotal', value: '55.000'),
            PrinterSummaryRow(label: 'Discount', value: '-5.000'),
            PrinterSummaryRow(label: 'Total', value: '50.000', highlighted: true),
          ],
          footerLines: const <String>['Thank you', 'Printed from FlinkPOS V2'],
        );
      case PrinterDocumentType.kitchenTicket:
        return PrinterDocumentData(
          type: type,
          title: 'Kitchen Ticket',
          subtitle: 'Preparation queue test',
          infoRows: const <PrinterInfoRow>[
            PrinterInfoRow(label: 'Order', value: '#KDS-014'),
            PrinterInfoRow(label: 'Table', value: 'T05'),
            PrinterInfoRow(label: 'Priority', value: 'Normal'),
          ],
          items: const <PrinterLineItem>[
            PrinterLineItem(label: '1x Iced Americano', quantity: 1, note: 'Less ice'),
            PrinterLineItem(label: '2x Chicken Sandwich', quantity: 2, note: 'No onion'),
          ],
          footerLines: const <String>['Kitchen flow sample'],
        );
      case PrinterDocumentType.label:
        return PrinterDocumentData(
          type: type,
          title: 'Label Print',
          subtitle: 'Short, sticker-friendly layout',
          infoRows: const <PrinterInfoRow>[
            PrinterInfoRow(label: 'Queue', value: 'B008'),
            PrinterInfoRow(label: 'Time', value: '12:14'),
          ],
          items: const <PrinterLineItem>[
            PrinterLineItem(label: 'Cold Brew Bottle 1L', quantity: 1),
          ],
          footerLines: const <String>['Label sample'],
        );
      case PrinterDocumentType.report:
        return PrinterDocumentData(
          type: type,
          title: 'Shift Report',
          subtitle: 'Summary report layout test',
          infoRows: const <PrinterInfoRow>[
            PrinterInfoRow(label: 'Shift', value: 'Morning Shift'),
            PrinterInfoRow(label: 'Cashier', value: 'Alfan'),
            PrinterInfoRow(label: 'Date', value: '2026-06-27'),
          ],
          summaryRows: const <PrinterSummaryRow>[
            PrinterSummaryRow(label: 'Gross Sales', value: '1.250.000'),
            PrinterSummaryRow(label: 'Cash', value: '650.000'),
            PrinterSummaryRow(label: 'Non-Cash', value: '600.000'),
            PrinterSummaryRow(label: 'Variance', value: '0', highlighted: true),
          ],
          footerLines: const <String>['Report sample'],
        );
      case PrinterDocumentType.test:
        return PrinterDocumentData(
          type: type,
          title: 'Generic Test',
          subtitle: 'Profile-only verification',
          headerLines: <String>[
            'Paper: ${printer.paperProfile.label}',
            'Width: ${printer.effectiveWidthMm.toStringAsFixed(0)}mm',
            'Chars/line: ${printer.effectiveCharsPerLine}',
          ],
          footerLines: const <String>[
            'If 50mm and 80mm still look the same, chars-per-line is wrong.',
          ],
        );
    }
  }

  String _buildPreviewText(PrinterDeviceConfig printer, PrinterDocumentData document) {
    final maxChars = printer.effectiveCharsPerLine;
    final separator = '-' * maxChars;
    final lines = <String>[];

    lines.addAll(_centerWrapped(document.title, maxChars));
    if ((document.subtitle ?? '').trim().isNotEmpty) {
      lines.addAll(_centerWrapped(document.subtitle!, maxChars));
    }
    for (final line in document.headerLines) {
      lines.addAll(_centerWrapped(line, maxChars));
    }
    lines.add(separator);
    for (final row in document.infoRows) {
      lines.add(_row(row.label, row.value, maxChars));
    }
    if (document.infoRows.isNotEmpty) {
      lines.add(separator);
    }
    for (final item in document.items) {
      final title = item.amount != null
          ? '${item.quantity}x ${item.label}'
          : item.label;
      lines.addAll(_wrap(title, maxChars));
      if (item.amount != null) {
        lines.add(_row(' ', _formatMoney(item.amount!), maxChars));
      }
      if ((item.note ?? '').trim().isNotEmpty) {
        lines.addAll(_wrap('  note: ${item.note!.trim()}', maxChars));
      }
    }
    if (document.items.isNotEmpty) {
      lines.add(separator);
    }
    for (final row in document.summaryRows) {
      lines.add(_row(row.label, row.value, maxChars));
    }
    if (document.summaryRows.isNotEmpty) {
      lines.add(separator);
    }
    for (final line in document.footerLines) {
      lines.addAll(_centerWrapped(line, maxChars));
    }
    return lines.join('\n');
  }

  Future<List<int>> _buildPdf(
    PrinterDeviceConfig printer,
    PrinterDocumentData document,
  ) async {
    final doc = pw.Document();
    final previewText = _buildPreviewText(printer, document);
    doc.addPage(
      pw.MultiPage(
        pageFormat: _pageFormat(printer),
        margin: const pw.EdgeInsets.all(8),
        build: (context) => [
          pw.Text(
            previewText,
            style: pw.TextStyle(
              fontSize: 9 * printer.fontScale,
              height: printer.lineSpacing,
            ),
          ),
        ],
      ),
    );
    return doc.save();
  }

  List<int> _buildRawBytes(PrinterDeviceConfig printer, String previewText) {
    final bytes = <int>[0x1B, 0x40];
    bytes.addAll(utf8.encode(previewText.replaceAll('\n', '\r\n')));
    bytes.addAll(<int>[0x0A, 0x0A, 0x0A]);
    if (printer.supportsAutoCut) {
      bytes.addAll(<int>[0x1D, 0x56, 0x41, 0x03]);
    }
    return bytes;
  }

  PdfPageFormat _pageFormat(PrinterDeviceConfig printer) {
    switch (printer.paperProfile.id) {
      case 'sheet_a4':
        return PdfPageFormat.a4;
      case 'sheet_a5':
        return PdfPageFormat.a5;
      default:
        return PdfPageFormat(
          printer.effectiveWidthMm * PdfPageFormat.mm,
          240 * PdfPageFormat.mm,
        );
    }
  }

  String _row(String left, String right, int maxChars) {
    final plainLeft = left.trim().isEmpty ? '' : left;
    var safeLeft = plainLeft;
    if (safeLeft.length + right.length + 1 > maxChars) {
      final allowedLeft = (maxChars - right.length - 3).clamp(1, safeLeft.length);
      safeLeft = '${safeLeft.substring(0, allowedLeft)}..';
    }
    final padding = maxChars - safeLeft.length - right.length;
    return '$safeLeft${' ' * (padding > 1 ? padding : 1)}$right';
  }

  List<String> _centerWrapped(String text, int maxChars) {
    return _wrap(text, maxChars)
        .map((line) {
          final spaces = ((maxChars - line.length) / 2).floor();
          return '${' ' * (spaces < 0 ? 0 : spaces)}$line';
        })
        .toList(growable: false);
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

  String _formatMoney(int value) {
    final negative = value < 0;
    final digits = value.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digits[i]);
    }
    return '${negative ? '-' : ''}${buffer.toString()}';
  }
}
