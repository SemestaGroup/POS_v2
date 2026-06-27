import 'package:flutter/material.dart';

import '../../../controllers/printer_settings_controller.dart';
import '../../../models/printer_settings_models.dart';

class PrinterMappingView extends StatefulWidget {
  const PrinterMappingView({super.key});

  @override
  State<PrinterMappingView> createState() => _PrinterMappingViewState();
}

class _PrinterMappingViewState extends State<PrinterMappingView> {
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
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return ValueListenableBuilder<PrinterSettingsState>(
      valueListenable: _controller.stateNotifier,
      builder: (context, state, _) {
        final printers = state.printers;
        if (printers.isNotEmpty &&
            (_selectedPrinterKey == null ||
                printers.every((printer) => printer.printerKey != _selectedPrinterKey))) {
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
              const Text('Printer Mapping', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              const Text(
                'Map cashier, kitchen, label, and report roles to each printer. Brand filters are optional; empty means print all for that role.',
                style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 14),
              if (printers.isEmpty)
                Text(
                  'Create a printer first in Printer List.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                )
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
                if (selected != null) _mappingCard(selected, state.availableBrands, primary),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _mappingCard(PrinterDeviceConfig printer, List<String> availableBrands, Color primary) {
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
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kPrinterRoles.map((role) {
              final active = printer.roles.contains(role);
              return FilterChip(
                label: Text(_roleLabel(role), style: const TextStyle(fontSize: 11)),
                selected: active,
                onSelected: (selected) async {
                  final roles = List<String>.from(printer.roles);
                  if (selected) {
                    roles.add(role);
                  } else {
                    roles.remove(role);
                  }
                  await _controller.savePrinter(printer.copyWith(roles: roles));
                },
                selectedColor: primary.withValues(alpha: 0.12),
                checkmarkColor: primary,
              );
            }).toList(growable: false),
          ),
          const SizedBox(height: 14),
          ...printer.roles.map((role) {
            final selectedBrands = printer.roleBrandFilters[role] ?? const <String>[];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_roleLabel(role)} Brand Filter', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    selectedBrands.isEmpty ? 'Empty means print all brands for this role.' : 'Only selected brands will be routed here for this role.',
                    style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableBrands.map((brand) {
                      final active = selectedBrands.contains(brand);
                      return FilterChip(
                        label: Text(brand, style: const TextStyle(fontSize: 11)),
                        selected: active,
                        onSelected: (selected) async {
                          final next = Map<String, List<String>>.from(printer.roleBrandFilters);
                          final brands = List<String>.from(next[role] ?? const <String>[]);
                          if (selected) {
                            brands.add(brand);
                          } else {
                            brands.remove(brand);
                          }
                          next[role] = brands;
                          await _controller.savePrinter(printer.copyWith(roleBrandFilters: next));
                        },
                      );
                    }).toList(growable: false),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'cashier':
        return 'Receipt';
      case 'kitchen':
        return 'Kitchen';
      case 'label':
        return 'Label';
      case 'report':
        return 'Report';
      default:
        return role;
    }
  }
}
