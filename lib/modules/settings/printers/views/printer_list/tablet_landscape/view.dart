import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../controllers/printer_settings_controller.dart';
import '../../../models/printer_settings_models.dart';
import 'dart:convert';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import '../../../../../../core/services/sync/pos_v2_options_service.dart';
import '../../../../../../core/services/sync/pos_v2_sync_status_store.dart';
import '../../../../../../l10n/app_localizations.dart';

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
  String? _bluetoothError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.refresh();
      _loadInitialData();
    });
    PosV2SyncStatusStore.instance.statusNotifier.addListener(_onSyncStatusChanged);
  }

  @override
  void dispose() {
    PosV2SyncStatusStore.instance.statusNotifier.removeListener(_onSyncStatusChanged);
    super.dispose();
  }

  void _onSyncStatusChanged() {
    final status = PosV2SyncStatusStore.instance.statusNotifier.value;
    if (!status.isSyncing) {
      _loadInitialData();
    }
  }

  Future<void> _loadInitialData() async {
    final options = await PosV2OptionsService.instance.getLocalOptions();
    final raw = options['pos_app_settings'];
    try {
      if (raw is Map) {
        _appSettings = Map<String, dynamic>.from(raw);
      } else if (raw is String && raw.isNotEmpty) {
        _appSettings = jsonDecode(raw) as Map<String, dynamic>;
      }
    } catch (_) {}

    final printing = _appSettings['printing'] is Map<String, dynamic>
        ? _appSettings['printing'] as Map<String, dynamic>
        : <String, dynamic>{};

    if (mounted) {
      setState(() {
        _autoPrint = printing['auto_print'] ?? false;
      });
    }

    await _loadBluetoothDevices();
  }

  Future<void> _loadBluetoothDevices() async {
    if (!mounted) return;
    setState(() {
      _isLoadingBluetooth = true;
      _bluetoothError = null;
    });

    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      if (mounted) {
        setState(() {
          _bluetoothDevices = [];
          _isLoadingBluetooth = false;
          _bluetoothError = 'Pencarian Bluetooth hanya didukung di perangkat Android / iOS.';
        });
      }
      return;
    }

    try {
      final bluetooth = BlueThermalPrinter.instance;

      final isAvailable = await bluetooth.isAvailable.timeout(
        const Duration(seconds: 3),
        onTimeout: () => false,
      );

      if (isAvailable != true) {
        if (mounted) {
          setState(() {
            _bluetoothDevices = [];
            _isLoadingBluetooth = false;
            _bluetoothError = 'Bluetooth tidak tersedia pada perangkat ini.';
          });
        }
        return;
      }

      final isOn = await bluetooth.isOn.timeout(
        const Duration(seconds: 3),
        onTimeout: () => false,
      );

      if (isOn != true) {
        if (mounted) {
          setState(() {
            _bluetoothDevices = [];
            _isLoadingBluetooth = false;
            _bluetoothError = 'Bluetooth belum aktif. Harap nyalakan Bluetooth HP/Tablet Anda.';
          });
        }
        return;
      }

      final devices = await bluetooth.getBondedDevices().timeout(
        const Duration(seconds: 5),
        onTimeout: () => <BluetoothDevice>[],
      );

      if (mounted) {
        setState(() {
          _bluetoothDevices = devices;
          _isLoadingBluetooth = false;
          if (_bluetoothDevices.isEmpty) {
            _bluetoothError = 'Tidak ada perangkat Bluetooth yang terpasang (paired). Pastikan printer sudah dipasangkan di Pengaturan Bluetooth HP/Tablet.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _bluetoothDevices = [];
          _isLoadingBluetooth = false;
          _bluetoothError = 'Gagal memuat perangkat Bluetooth: ${e.toString().replaceFirst('Exception: ', '')}';
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
                                    child: Text(AppLocalizations.of(context)!.delete, style: const TextStyle(fontSize: 11)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                     ),
                  
                  const SizedBox(height: 16),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.printerPairedBluetoothDevices,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        onPressed: _isLoadingBluetooth ? null : _loadBluetoothDevices,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        tooltip: 'Pindai Ulang Bluetooth',
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (_isLoadingBluetooth)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_bluetoothError != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _bluetoothError!,
                            style: TextStyle(fontSize: 12, color: Colors.brown.shade800),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _loadBluetoothDevices,
                            icon: const Icon(Icons.refresh_rounded, size: 14),
                            label: const Text('Pindai Ulang', style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                    )
                  else if (_bluetoothDevices.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'Tidak ada perangkat Bluetooth yang terpasang.',
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
                              child: Text(AppLocalizations.of(context)!.printerAddProfile, style: const TextStyle(fontSize: 11)),
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
        title: Text(AppLocalizations.of(context)!.printerDeleteTitle),
        content: Text(AppLocalizations.of(context)!.printerDeleteConfirmMessage),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(AppLocalizations.of(context)!.cancel)),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(AppLocalizations.of(context)!.delete)),
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
          return Dialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 16, 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F2FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.print_rounded, size: 22, color: Color(0xFF4F46E5)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                printer == null ? AppLocalizations.of(context)!.printerAddProfile : 'Edit Printer',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Konfigurasi koneksi dan profil kertas',
                                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF9CA3AF)),
                          style: IconButton.styleFrom(backgroundColor: const Color(0xFFF9FAFB)),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFF3F4F6)),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _sectionTitle('General Info'),
                          const SizedBox(height: 12),
                          _field(name, 'Printer Name', Icons.badge_outlined),
                          
                          const SizedBox(height: 24),
                          _sectionTitle('Connection'),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: connectionType,
                            items: [
                              DropdownMenuItem(value: 'system', child: Text(AppLocalizations.of(context)!.printerTypeSystem, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                              DropdownMenuItem(value: 'network', child: Text(AppLocalizations.of(context)!.printerTypeNetwork, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                              DropdownMenuItem(value: 'bluetooth', child: Text(AppLocalizations.of(context)!.printerTypeBluetooth, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                              DropdownMenuItem(value: 'usb', child: Text(AppLocalizations.of(context)!.printerTypeUsb, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                            ],
                            onChanged: (value) => setDialogState(() => connectionType = value ?? 'system'),
                            decoration: _decoration('Connection Type', Icons.settings_ethernet_rounded),
                            dropdownColor: Colors.white,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 2,
                                child: _field(target, connectionType == 'network' ? 'IP / Host' : 'Device / Queue', Icons.link_rounded),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 1,
                                child: _field(port, 'Port', Icons.numbers_rounded),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 24),
                          _sectionTitle('Paper & Formatting'),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: paperProfileId,
                            items: kPrinterPaperProfiles
                                .map((profile) => DropdownMenuItem(
                                      value: profile.id,
                                      child: Text(profile.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
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
                            decoration: _decoration('Paper Profile', Icons.receipt_long_rounded),
                            dropdownColor: Colors.white,
                          ),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Text(
                              'Real profile: ${profile.widthMm.toStringAsFixed(0)}mm • ${profile.defaultCharsPerLine} chars/line',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                            ),
                          ),
                          if (paperProfileId == 'custom_roll') ...[
                            const SizedBox(height: 12),
                            _field(customWidth, 'Custom Width (mm)', Icons.straighten_rounded),
                          ],
                          const SizedBox(height: 12),
                          _field(chars, 'Chars Per Line Override', Icons.text_format_rounded),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _readonlyField('Font Scale', fontScale.toStringAsFixed(1))),
                              const SizedBox(width: 12),
                              Expanded(child: _readonlyField('Line Spacing', lineSpacing.toStringAsFixed(1))),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _field(notes, 'Notes', Icons.notes_rounded),
                          
                          const SizedBox(height: 24),
                          _sectionTitle('Options'),
                          const SizedBox(height: 12),
                          _toggleCard(
                            AppLocalizations.of(context)!.printerSupportsAutoCut,
                            'Otomatis potong kertas setelah mencetak struk',
                            autoCut,
                            (value) => setDialogState(() => autoCut = value),
                          ),
                          const SizedBox(height: 8),
                          _toggleCard(
                            AppLocalizations.of(context)!.printerActive,
                            'Aktifkan atau nonaktifkan printer ini untuk operasional',
                            isActive,
                            (value) => setDialogState(() => isActive = value),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFF3F4F6)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF4B5563),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          child: Text(AppLocalizations.of(context)!.cancel, style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 12),
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
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                          ),
                          child: Text(AppLocalizations.of(context)!.save, style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: Color(0xFF111827),
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, [IconData? icon, bool enabled = true]) {
    return TextField(
      controller: controller,
      enabled: enabled,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      decoration: _decoration(label, icon),
    );
  }

  InputDecoration _decoration(String label, [IconData? icon]) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        prefixIcon: icon != null ? Icon(icon, size: 18, color: const Color(0xFF9CA3AF)) : null,
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
        ),
      );

  Widget _readonlyField(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ],
        ),
      );

  Widget _toggleCard(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: value ? const Color(0xFFC7D2FE) : const Color(0xFFE5E7EB),
        ),
      ),
      child: SwitchListTile.adaptive(
        value: value,
        onChanged: onChanged,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
        activeTrackColor: const Color(0xFF4F46E5),
      ),
    );
  }

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
