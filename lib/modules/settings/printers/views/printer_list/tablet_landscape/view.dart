import 'package:flutter/material.dart';

import '../../../controllers/printer_settings_controller.dart';
import '../../../models/printer_settings_models.dart';
import 'dart:convert';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import '../../../../../../core/services/sync/pos_v2_options_service.dart';

class PrinterListView extends StatefulWidget {
  const PrinterListView({super.key});

  @override
  State<PrinterListView> createState() => _PrinterListViewState();
}

class _PrinterListViewState extends State<PrinterListView> {
  final PrinterSettingsController _controller = PrinterSettingsController.instance;

  bool _autoPrint = false;
  List<BluetoothDevice> _bluetoothDevices = [];
  Map<String, dynamic> _appSettings = {};
  bool _isLoadingBluetooth = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.refresh();
      _loadInitialData();
    });
  }

  Future<void> _loadInitialData() async {
    final options = await PosV2OptionsService.instance.getLocalOptions();
    final raw = options['pos_app_settings']?.toString() ?? '{}';
    try {
      _appSettings = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {}

    final printing = _appSettings['printing'] is Map<String, dynamic>
        ? _appSettings['printing'] as Map<String, dynamic>
        : <String, dynamic>{};

    if (mounted) {
      setState(() {
        _autoPrint = printing['auto_print'] ?? false;
        _isLoadingBluetooth = true;
      });
    }

    try {
      final devices = await BlueThermalPrinter.instance.getBondedDevices();
      if (mounted) {
        setState(() {
          _bluetoothDevices = devices;
          _isLoadingBluetooth = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingBluetooth = false;
        });
      }
    }
  }

  Future<void> _updateAutoPrint(bool val) async {
    setState(() => _autoPrint = val);

    final opts = await PosV2OptionsService.instance.getLocalOptions();
    Map<String, dynamic> latestSettings = {};
    try {
      latestSettings = jsonDecode(opts['pos_app_settings']?.toString() ?? '{}');
    } catch (_) {}

    final printing = latestSettings['printing'] is Map<String, dynamic>
        ? latestSettings['printing'] as Map<String, dynamic>
        : <String, dynamic>{};
    printing['auto_print'] = val;
    latestSettings['printing'] = printing;
    
    // Also update local cached settings to avoid UI mismatch if needed
    _appSettings = latestSettings;

    PosV2OptionsService.instance.updateOption('pos_app_settings', jsonEncode(latestSettings));
  }

  void _openEditorWithDevice(BuildContext context, BluetoothDevice device) {
    final newPrinter = PrinterDeviceConfig(
      id: 0,
      printerKey: '',
      displayName: device.name ?? 'Bluetooth Printer',
      connectionType: 'bluetooth',
      connectionTarget: device.address,
      paperProfileId: 'thermal_58',
      networkPort: 9100,
      fontScale: 1.0,
      lineSpacing: 0,
      supportsAutoCut: false,
      roles: const ['cashier'],
      roleBrandFilters: const {},
      isActive: true,
    );
    _openEditor(context, newPrinter);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return ValueListenableBuilder<PrinterSettingsState>(
      valueListenable: _controller.stateNotifier,
      builder: (context, state, _) {
        if (state.isLoading && state.printers.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              color: Colors.white,
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Printer List', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                        SizedBox(height: 3),
                        Text(
                          'Create printer profiles per device/tenant. Paper profile here affects the receipt width for real.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: state.isSaving ? null : _controller.refresh,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Refresh', style: TextStyle(fontSize: 11)),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: state.isSaving ? null : () => _openEditor(context, null),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Add Printer', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),
            if (state.errorMessage != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  state.errorMessage!,
                  style: TextStyle(fontSize: 11, color: Colors.red.shade600),
                ),
              ),
            ],
            if (state.lastDispatchResult != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  state.lastDispatchResult!,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF374151)),
                ),
              ),
            ],
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFEEEFF8), width: 1),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.print_rounded, size: 20, color: primary),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Auto Print Receipt', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              Text('Automatically print receipt when order is paid/completed.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                        Switch(
                          value: _autoPrint,
                          onChanged: _updateAutoPrint,
                        ),
                      ],
                    ),
                  ),

                  if (state.printers.isNotEmpty)
                     const Padding(
                       padding: EdgeInsets.only(bottom: 8),
                       child: Text('Saved Printers', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                     ),
                  
                  if (state.printers.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Center(
                        child: Text(
                          'No printer profiles yet.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                        ),
                      ),
                    ),

                  for (final printer in state.printers)
                     Padding(
                       padding: const EdgeInsets.only(bottom: 8),
                       child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.print_rounded, color: primary, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            printer.displayName,
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        _badge(
                                          printer.isActive ? 'Active' : 'Inactive',
                                          printer.isActive ? const Color(0xFFD1FAE5) : const Color(0xFFF3F4F6),
                                          printer.isActive ? const Color(0xFF047857) : const Color(0xFF6B7280),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${printer.connectionType.toUpperCase()} • ${printer.connectionTarget ?? '-'}',
                                      style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        _mini(printer.paperProfile.label),
                                        _mini('${printer.effectiveCharsPerLine} chars/line'),
                                        _mini('${printer.effectiveWidthMm.toStringAsFixed(0)}mm'),
                                        _mini(printer.supportsAutoCut ? 'Auto Cut' : 'Manual Tear'),
                                      ],
                                    ),
                                    if (printer.roles.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: printer.roles
                                            .map((role) => _badge(role, primary.withValues(alpha: 0.1), primary))
                                            .toList(growable: false),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  OutlinedButton(
                                    onPressed: state.isSaving ? null : () => _controller.printTest(printer),
                                    child: const Text('Test', style: TextStyle(fontSize: 11)),
                                  ),
                                  OutlinedButton(
                                    onPressed: state.isSaving ? null : () => _openEditor(context, printer),
                                    child: const Text('Edit', style: TextStyle(fontSize: 11)),
                                  ),
                                  OutlinedButton(
                                    onPressed: state.isSaving ? null : () => _delete(context, printer),
                                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade600),
                                    child: const Text('Delete', style: TextStyle(fontSize: 11)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                     ),
                  
                  const SizedBox(height: 16),
                  
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('Paired Bluetooth Devices', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                  if (_isLoadingBluetooth)
                    const Center(child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ))
                  else if (_bluetoothDevices.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'No paired Bluetooth devices found.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                        ),
                      ),
                    )
                  else
                    for (final device in _bluetoothDevices)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.bluetooth_rounded, size: 20, color: Colors.blue),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(device.name ?? 'Unknown', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  Text(device.address ?? '-', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                                ],
                              ),
                            ),
                            OutlinedButton(
                              onPressed: () {
                                _openEditorWithDevice(context, device);
                              },
                              child: const Text('Add Profile', style: TextStyle(fontSize: 11)),
                            )
                          ],
                        ),
                      ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _delete(BuildContext context, PrinterDeviceConfig printer) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Printer'),
        content: Text('Delete ${printer.displayName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await _controller.deletePrinter(printer);
    }
  }

  Future<void> _openEditor(BuildContext context, PrinterDeviceConfig? printer) async {
    final generatedSuffix = DateTime.now().microsecondsSinceEpoch
        .toString()
        .substring(10);
    final name = TextEditingController(
      text: printer?.displayName ?? 'Printer $generatedSuffix',
    );
    final target = TextEditingController(text: printer?.connectionTarget ?? '');
    final port = TextEditingController(text: (printer?.networkPort ?? 9100).toString());
    final customWidth = TextEditingController(text: printer?.customWidthMm?.toStringAsFixed(0) ?? '');
    final chars = TextEditingController(text: printer?.charsPerLine?.toString() ?? '');
    final notes = TextEditingController(text: printer?.notes ?? '');
    var connectionType = printer?.connectionType ?? 'system';
    var paperProfileId = printer?.paperProfileId ?? 'thermal_58';
    var fontScale = printer?.fontScale ?? 1.0;
    var lineSpacing = printer?.lineSpacing ?? 1.0;
    var autoCut = printer?.supportsAutoCut ?? false;
    var isActive = printer?.isActive ?? true;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final profile = kPrinterPaperProfiles.firstWhere(
            (profile) => profile.id == paperProfileId,
            orElse: () => kPrinterPaperProfiles[1],
          );
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Text(printer == null ? 'Add Printer' : 'Edit Printer'),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _field(name, 'Printer Name'),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: connectionType,
                      items: const [
                        DropdownMenuItem(value: 'system', child: Text('System Print / Browser', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'network', child: Text('Network / LAN', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'bluetooth', child: Text('Bluetooth', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'usb', child: Text('USB', style: TextStyle(fontSize: 12))),
                      ],
                      onChanged: (value) => setDialogState(() => connectionType = value ?? 'system'),
                      decoration: _decoration('Connection Type'),
                    ),
                    const SizedBox(height: 10),
                    _field(target, connectionType == 'network' ? 'IP / Host' : 'Device / Queue Identifier'),
                    const SizedBox(height: 10),
                    _field(port, 'Network Port'),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: paperProfileId,
                      items: kPrinterPaperProfiles
                          .map((profile) => DropdownMenuItem(
                                value: profile.id,
                                child: Text(profile.label, style: const TextStyle(fontSize: 12)),
                              ))
                          .toList(growable: false),
                      onChanged: (value) => setDialogState(() {
                        paperProfileId = value ?? 'thermal_58';
                        final selected = kPrinterPaperProfiles.firstWhere(
                          (profile) => profile.id == paperProfileId,
                          orElse: () => kPrinterPaperProfiles[1],
                        );
                        autoCut = selected.supportsAutoCut;
                        chars.text = selected.defaultCharsPerLine.toString();
                        if (paperProfileId != 'custom_roll') {
                          customWidth.text = '';
                        }
                      }),
                      decoration: _decoration('Paper Profile'),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Real profile: ${profile.widthMm.toStringAsFixed(0)}mm • ${profile.defaultCharsPerLine} chars/line',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
                      ),
                    ),
                    if (paperProfileId == 'custom_roll') ...[
                      const SizedBox(height: 10),
                      _field(customWidth, 'Custom Width (mm)'),
                    ],
                    const SizedBox(height: 10),
                    _field(chars, 'Chars Per Line Override'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _readonlyField(
                            'Font Scale',
                            fontScale.toStringAsFixed(1),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _readonlyField(
                            'Line Spacing',
                            lineSpacing.toStringAsFixed(1),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _field(notes, 'Notes'),
                    const SizedBox(height: 6),
                    SwitchListTile.adaptive(
                      value: autoCut,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Supports Auto Cut', style: TextStyle(fontSize: 12)),
                      onChanged: (value) => setDialogState(() => autoCut = value),
                    ),
                    SwitchListTile.adaptive(
                      value: isActive,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active', style: TextStyle(fontSize: 12)),
                      onChanged: (value) => setDialogState(() => isActive = value),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  final selectedProfile = kPrinterPaperProfiles.firstWhere(
                    (profile) => profile.id == paperProfileId,
                    orElse: () => kPrinterPaperProfiles[1],
                  );
                  final config = (printer ??
                          PrinterDeviceConfig(
                            id: 0,
                            printerKey: 'printer-${DateTime.now().microsecondsSinceEpoch}',
                            displayName: '',
                            connectionType: 'system',
                            connectionTarget: null,
                            networkPort: 9100,
                            paperProfileId: 'thermal_58',
                            customWidthMm: null,
                            charsPerLine: null,
                            fontScale: 1,
                            lineSpacing: 1,
                            supportsAutoCut: false,
                            roles: const <String>[],
                            roleBrandFilters: const <String, List<String>>{},
                            notes: null,
                            isActive: true,
                            lastTestedAt: null,
                          ))
                      .copyWith(
                    displayName: name.text.trim(),
                    connectionType: connectionType,
                    connectionTarget: target.text.trim(),
                    networkPort: int.tryParse(port.text.trim()) ?? 9100,
                    paperProfileId: paperProfileId,
                    customWidthMm: paperProfileId == 'custom_roll'
                        ? double.tryParse(customWidth.text.trim())
                        : null,
                    charsPerLine: int.tryParse(chars.text.trim()) ?? selectedProfile.defaultCharsPerLine,
                    fontScale: fontScale,
                    lineSpacing: lineSpacing,
                    supportsAutoCut: autoCut,
                    notes: notes.text.trim(),
                    isActive: isActive,
                  );
                  await _controller.savePrinter(config);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, {bool enabled = true}) {
    return TextField(
      controller: controller,
      enabled: enabled,
      style: const TextStyle(fontSize: 12),
      decoration: _decoration(label),
    );
  }

  Widget _readonlyField(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
            const SizedBox(height: 3),
            Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
      );

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  Widget _badge(String label, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
      );

  Widget _mini(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF4B5563))),
      );
}
