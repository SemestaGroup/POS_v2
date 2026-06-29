import '../../../modules/settings/printers/models/printer_settings_models.dart';

enum PrinterDocumentType { receipt, kitchenTicket, label, report, test }

class PrinterInfoRow {
  const PrinterInfoRow({required this.label, required this.value});

  final String label;
  final String value;
}

class PrinterLineItem {
  const PrinterLineItem({
    required this.label,
    required this.quantity,
    this.amount,
    this.note,
  });

  final String label;
  final int quantity;
  final int? amount;
  final String? note;
}

class PrinterSummaryRow {
  const PrinterSummaryRow({
    required this.label,
    required this.value,
    this.highlighted = false,
  });

  final String label;
  final String value;
  final bool highlighted;
}

class PrinterDocumentData {
  const PrinterDocumentData({
    required this.type,
    required this.title,
    this.subtitle,
    this.headerLines = const <String>[],
    this.infoRows = const <PrinterInfoRow>[],
    this.items = const <PrinterLineItem>[],
    this.summaryRows = const <PrinterSummaryRow>[],
    this.footerLines = const <String>[],
  });

  final PrinterDocumentType type;
  final String title;
  final String? subtitle;
  final List<String> headerLines;
  final List<PrinterInfoRow> infoRows;
  final List<PrinterLineItem> items;
  final List<PrinterSummaryRow> summaryRows;
  final List<String> footerLines;
}

class PrinterRenderOutput {
  const PrinterRenderOutput({
    required this.documentType,
    required this.printer,
    required this.previewText,
    required this.pdfBytes,
    required this.rawBytes,
  });

  final PrinterDocumentType documentType;
  final PrinterDeviceConfig printer;
  final String previewText;
  final List<int> pdfBytes;
  final List<int> rawBytes;
}

class PrinterDispatchResult {
  const PrinterDispatchResult({
    required this.success,
    required this.channel,
    this.message,
  });

  final bool success;
  final String channel;
  final String? message;
}
