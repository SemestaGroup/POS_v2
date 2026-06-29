import 'package:flutter/material.dart';

import '../../../../../../core/printing/models/printer_render_models.dart';
import '../../../../../../core/printing/services/printer_rendering_service.dart';
import '../../../controllers/printer_settings_controller.dart';
import '../../../models/printer_settings_models.dart';

class PrinterTestView extends StatefulWidget {
  const PrinterTestView({super.key});

  @override
  State<PrinterTestView> createState() => _PrinterTestViewState();
}

class _PrinterTestViewState extends State<PrinterTestView> {
  final PrinterSettingsController _controller = PrinterSettingsController.instance;
  String? _selectedPrinterKey;
  PrinterDocumentType _selectedType = PrinterDocumentType.test;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PrinterSettingsState>(
      valueListenable: _controller.stateNotifier,
      builder: (context, state, _) {
        final printers = state.printers.where((printer) => printer.isActive).toList(growable: false);
        if (printers.isNotEmpty &&
            (_selectedPrinterKey == null || printers.every((printer) => printer.printerKey != _selectedPrinterKey))) {
          _selectedPrinterKey = printers.first.printerKey;
        }
        PrinterDeviceConfig? selected;
        for (final printer in printers) {
          if (printer.printerKey == _selectedPrinterKey) {
            selected = printer;
            break;
          }
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Printer Test', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              const Text(
                'Preview a sample receipt with the selected paper profile. This is where 50mm vs 80mm should visibly differ.',
                style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 14),
              if (printers.isEmpty)
                const Text('No active printer profile available. Add one first.', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)))
              else ...[
                DropdownButtonFormField<String>(
                  initialValue: _selectedPrinterKey,
                  decoration: InputDecoration(
                    labelText: 'Selected Printer',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: printers
                      .map((printer) => DropdownMenuItem(
                            value: printer.printerKey,
                            child: Text(printer.displayName, style: const TextStyle(fontSize: 12)),
                          ))
                      .toList(growable: false),
                  onChanged: (value) => setState(() => _selectedPrinterKey = value),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<PrinterDocumentType>(
                  initialValue: _selectedType,
                  decoration: InputDecoration(
                    labelText: 'Document Type',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: PrinterDocumentType.values
                      .map((type) => DropdownMenuItem(
                            value: type,
                            child: Text(_typeLabel(type), style: const TextStyle(fontSize: 12)),
                          ))
                      .toList(growable: false),
                  onChanged: (value) => setState(() => _selectedType = value ?? PrinterDocumentType.test),
                ),
                const SizedBox(height: 14),
                if (selected != null) _previewCard(selected),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _previewCard(PrinterDeviceConfig printer) {
    final sample = PrinterRenderingService.instance.buildSampleDocument(printer, _selectedType);
    final lines = PrinterRenderingService.instance
        .render(printer, sample)
        .then((output) => output.previewText.split('\n'));
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(printer.displayName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            '${printer.paperProfile.label} • ${printer.effectiveWidthMm.toStringAsFixed(0)}mm • ${printer.effectiveCharsPerLine} chars/line',
            style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<String>>(
            future: lines,
            builder: (context, snapshot) {
              final text = snapshot.data?.join('\n') ?? 'Loading preview...';
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  text,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.5,
                    fontFamily: 'monospace',
                    color: Color(0xFF111827),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'If this preview still looks identical after changing paper profile, chars-per-line is wrong.',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => _controller.printTest(printer, type: _selectedType),
                icon: const Icon(Icons.print_rounded, size: 16),
                label: const Text('Preview / Print', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _typeLabel(PrinterDocumentType type) {
    switch (type) {
      case PrinterDocumentType.receipt:
        return 'Receipt';
      case PrinterDocumentType.kitchenTicket:
        return 'Kitchen Ticket';
      case PrinterDocumentType.label:
        return 'Label';
      case PrinterDocumentType.report:
        return 'Report';
      case PrinterDocumentType.test:
        return 'Generic Test';
    }
  }
}
