import 'package:flutter/material.dart';

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
    final lines = _sampleLines(printer.effectiveCharsPerLine);
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              lines.join('\n'),
              style: const TextStyle(
                fontSize: 11,
                height: 1.5,
                fontFamily: 'monospace',
                color: Color(0xFF111827),
              ),
            ),
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
                onPressed: () => _controller.printTest(printer),
                icon: const Icon(Icons.print_rounded, size: 16),
                label: const Text('Preview / Print', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<String> _sampleLines(int maxChars) {
    final separator = '-' * maxChars;
    return <String>[
      _center('TEST PROFILE', maxChars),
      separator,
      _row('Order', '#TEST-001', maxChars),
      _row('Queue', 'A-014', maxChars),
      separator,
      ..._wrap('1x Signature Latte Extra Shot with Oat Milk', maxChars),
      ..._wrap('2x Butter Croissant', maxChars),
      separator,
      _row('Subtotal', '45.000', maxChars),
      _row('Discount', '-5.000', maxChars),
      _row('Total', '40.000', maxChars),
      _row('Cash', '50.000', maxChars),
      _row('Change', '10.000', maxChars),
      separator,
      _center('50mm must be tighter than 80mm.', maxChars),
    ];
  }

  String _row(String left, String right, int maxChars) {
    final safeLeft = left.length + right.length + 1 > maxChars
        ? '${left.substring(0, (maxChars - right.length - 3).clamp(1, left.length))}..'
        : left;
    final padding = maxChars - safeLeft.length - right.length;
    return '$safeLeft${' ' * (padding > 1 ? padding : 1)}$right';
  }

  String _center(String text, int maxChars) {
    if (text.length >= maxChars) {
      return text;
    }
    final padding = ((maxChars - text.length) / 2).floor();
    return '${' ' * padding}$text';
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
}
