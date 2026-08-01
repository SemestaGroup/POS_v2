import 'dart:convert';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../../../core/services/sync/pos_v2_options_service.dart';
import '../../../../../../core/services/sync/pos_v2_sync_status_store.dart';
import '../../../../../../l10n/app_localizations.dart';
import '../../../controllers/printer_settings_controller.dart';
import '../../../models/printer_settings_models.dart';

/// Professional Mobile Portrait View for Printer Management
class PrinterListMobileView extends StatefulWidget {
  const PrinterListMobileView({super.key});

  @override
  State<PrinterListMobileView> createState() => _PrinterListMobileViewState();
}

class _PrinterListMobileViewState extends State<PrinterListMobileView> {
  final PrinterSettingsController _controller =
      PrinterSettingsController.instance;

  bool _autoPrint = false;
  List<BluetoothDevice> _bluetoothDevices = [];
  Map<String, dynamic> _appSettings = {};
  bool _isLoadingBluetooth = false;
  String? _bluetoothError;
  int? _testingPrinterId;
  bool _showBluetoothSection = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.refresh();
      _loadInitialData();
    });
    PosV2SyncStatusStore.instance.statusNotifier.addListener(
      _onSyncStatusChanged,
    );
  }

  @override
  void dispose() {
    PosV2SyncStatusStore.instance.statusNotifier.removeListener(
      _onSyncStatusChanged,
    );
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
          _bluetoothError =
              'Pencarian Bluetooth hanya didukung di Android / iOS.';
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
            _bluetoothError =
                'Bluetooth belum aktif. Harap nyalakan Bluetooth Anda.';
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
            _bluetoothError = 'Belum ada perangkat Bluetooth paired.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _bluetoothDevices = [];
          _isLoadingBluetooth = false;
          _bluetoothError =
              'Gagal memuat Bluetooth: ${e.toString().replaceFirst('Exception: ', '')}';
        });
      }
    }
  }

  Future<void> _updateAutoPrint(bool val) async {
    final previousValue = _autoPrint;
    setState(() => _autoPrint = val);
    try {
      final opts = await PosV2OptionsService.instance.getLocalOptions();
      Map<String, dynamic> latestSettings = {};
      try {
        latestSettings = jsonDecode(
          opts['pos_app_settings']?.toString() ?? '{}',
        );
      } catch (_) {}

      final printing = latestSettings['printing'] is Map<String, dynamic>
          ? latestSettings['printing'] as Map<String, dynamic>
          : <String, dynamic>{};
      printing['auto_print'] = val;
      latestSettings['printing'] = printing;

      await PosV2OptionsService.instance.updateOption(
        'pos_app_settings',
        jsonEncode(latestSettings),
      );
      _appSettings = latestSettings;
    } catch (_) {
      if (mounted) {
        setState(() => _autoPrint = previousValue);
        _showFeedback(
          'Pengaturan Auto-Print tidak dapat disimpan.',
          isError: true,
        );
      }
    }
  }

  void _openEditorWithDevice(BluetoothDevice device) {
    final newPrinter = PrinterDeviceConfig(
      id: 0,
      printerKey: 'printer-${DateTime.now().microsecondsSinceEpoch}',
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
    _openEditor(newPrinter);
  }

  Future<void> _handleTestPrint(PrinterDeviceConfig printer) async {
    setState(() => _testingPrinterId = printer.id);
    try {
      await _controller.printTest(printer);
      final result = _controller.stateNotifier.value.lastDispatchResult;
      if (result != null) {
        _showFeedback(result, isError: result.startsWith('Failed'));
      }
    } catch (error) {
      _showFeedback('Gagal mencetak tes: ${_messageFor(error)}', isError: true);
    } finally {
      if (mounted) setState(() => _testingPrinterId = null);
    }
  }

  Future<void> _togglePrinterActive(
    PrinterDeviceConfig printer,
    bool active,
  ) async {
    try {
      await _controller.savePrinter(printer.copyWith(isActive: active));
    } catch (error) {
      _showFeedback(
        'Status printer tidak dapat disimpan: ${_messageFor(error)}',
        isError: true,
      );
    }
  }

  Future<void> _delete(PrinterDeviceConfig printer) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Icon(
              Icons.delete_outline_rounded,
              color: Color(0xFFEF4444),
              size: 32,
            ),
            const SizedBox(height: 10),
            Text(
              l10n.printerDeleteTitle,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Hapus profil "${printer.displayName}"?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      l10n.cancel,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      l10n.delete,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      try {
        await _controller.deletePrinter(printer);
      } catch (error) {
        _showFeedback(
          'Printer tidak dapat dihapus: ${_messageFor(error)}',
          isError: true,
        );
      }
    }
  }

  void _openEditor(PrinterDeviceConfig? printer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _PrinterEditorBottomSheet(
          printer: printer,
          bluetoothDevices: _bluetoothDevices,
          onSave: _controller.savePrinter,
        ),
      ),
    );
  }

  String _messageFor(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  void _showFeedback(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        backgroundColor: isError
            ? const Color(0xFFEF4444)
            : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: ValueListenableBuilder<PrinterSettingsState>(
        valueListenable: _controller.stateNotifier,
        builder: (context, state, _) {
          if (state.isLoading && state.printers.isEmpty) {
            return Center(
              child: CircularProgressIndicator(strokeWidth: 2, color: primary),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await _controller.refresh();
              await _loadBluetoothDevices();
            },
            color: primary,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
              children: [
                // 1. Grouped Options Box
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        SwitchListTile.adaptive(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 2,
                          ),
                          secondary: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.print_outlined,
                              color: primary,
                              size: 20,
                            ),
                          ),
                          title: const Text(
                            'Auto-Print Struk',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          subtitle: const Text(
                            'Cetak struk otomatis saat checkout',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          value: _autoPrint,
                          activeTrackColor: primary,
                          onChanged: _updateAutoPrint,
                        ),
                        const Divider(
                          height: 1,
                          indent: 14,
                          endIndent: 14,
                          color: Color(0xFFF3F4F6),
                        ),

                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 2,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.bluetooth_rounded,
                              color: Color(0xFF2563EB),
                              size: 20,
                            ),
                          ),
                          title: const Text(
                            'Perangkat Bluetooth Paired',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          subtitle: Text(
                            _isLoadingBluetooth
                                ? 'Mencari perangkat...'
                                : '${_bluetoothDevices.length} printer paired terdeteksi',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          trailing: Icon(
                            _showBluetoothSection
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: const Color(0xFF6B7280),
                          ),
                          onTap: () {
                            setState(() {
                              _showBluetoothSection = !_showBluetoothSection;
                            });
                            if (_showBluetoothSection &&
                                _bluetoothDevices.isEmpty) {
                              _loadBluetoothDevices();
                            }
                          },
                        ),

                        if (_showBluetoothSection) ...[
                          const Divider(height: 1, color: Color(0xFFF3F4F6)),
                          if (_bluetoothError != null)
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.info_outline_rounded,
                                    size: 16,
                                    color: Color(0xFFD97706),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _bluetoothError!,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF92400E),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.refresh_rounded,
                                      size: 18,
                                    ),
                                    onPressed: _loadBluetoothDevices,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                            )
                          else if (_bluetoothDevices.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                'Belum ada printer Bluetooth dipasangkan.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _bluetoothDevices.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(
                                    height: 1,
                                    indent: 14,
                                    endIndent: 14,
                                    color: Color(0xFFF3F4F6),
                                  ),
                              itemBuilder: (context, index) {
                                final dev = _bluetoothDevices[index];
                                return ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 0,
                                  ),
                                  title: Text(
                                    dev.name ?? 'Bluetooth Printer',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    dev.address ?? '-',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF9CA3AF),
                                    ),
                                  ),
                                  trailing: TextButton(
                                    onPressed: () => _openEditorWithDevice(dev),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      foregroundColor: primary,
                                    ),
                                    child: const Text(
                                      'Gunakan',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 2. Section Header: Profil Printer List
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Daftar Printer (${state.printers.length})',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: state.isSaving
                          ? null
                          : () => _openEditor(null),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text(
                        'Tambah Printer',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // 3. Printer Cards List
                if (state.printers.isEmpty)
                  _buildEmptyState()
                else
                  for (final printer in state.printers) ...[
                    _buildPrinterCard(printer, state.isSaving, primary),
                    const SizedBox(height: 10),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.print_disabled_outlined,
            size: 36,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 10),
          const Text(
            'Belum ada printer dikonfigurasi',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tekan "Tambah Printer" di atas untuk membuat profil baru.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildPrinterCard(
    PrinterDeviceConfig printer,
    bool isSaving,
    Color primary,
  ) {
    final isTesting = _testingPrinterId == printer.id;

    IconData connIcon;
    Color connBg;
    Color connFg;

    switch (printer.connectionType.toLowerCase()) {
      case 'bluetooth':
        connIcon = Icons.bluetooth_rounded;
        connBg = const Color(0xFFEFF6FF);
        connFg = const Color(0xFF2563EB);
        break;
      case 'network':
        connIcon = Icons.wifi_rounded;
        connBg = const Color(0xFFFFFBEB);
        connFg = const Color(0xFFD97706);
        break;
      case 'usb':
        connIcon = Icons.usb_rounded;
        connBg = const Color(0xFFF3E8FF);
        connFg = const Color(0xFF9333EA);
        break;
      default:
        connIcon = Icons.print_rounded;
        connBg = const Color(0xFFF3F4F6);
        connFg = const Color(0xFF4B5563);
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: printer.isActive
              ? const Color(0xFFE5E7EB)
              : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Icon, Title, Target & Active Switch
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: connBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(connIcon, color: connFg, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        printer.displayName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: printer.isActive
                              ? const Color(0xFF1F2937)
                              : Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '${printer.connectionType.toUpperCase()} • ${printer.connectionTarget ?? 'Target belum diatur'}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Transform.scale(
                  scale: 0.75,
                  child: Switch.adaptive(
                    value: printer.isActive,
                    activeTrackColor: primary,
                    onChanged: isSaving
                        ? null
                        : (val) => _togglePrinterActive(printer, val),
                  ),
                ),
              ],
            ),
          ),

          // Prominent Specs Badges Row (Paper Size, CPL, Auto-Cut & Roles)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 5,
              runSpacing: 4,
              children: [
                // Clear Paper Profile Tag
                _buildPill(
                  printer.paperProfile.label,
                  Icons.receipt_long_rounded,
                  const Color(0xFFF3F4F6),
                  const Color(0xFF374151),
                ),
                // Chars Per Line Tag
                _buildPill(
                  '${printer.effectiveCharsPerLine} CPL',
                  Icons.format_size_rounded,
                  const Color(0xFFF3F4F6),
                  const Color(0xFF4B5563),
                ),
                // Auto-Cut Support Tag
                if (printer.supportsAutoCut)
                  _buildPill(
                    'Auto-Cut',
                    Icons.content_cut_rounded,
                    const Color(0xFFEFF6FF),
                    const Color(0xFF2563EB),
                  ),
                // Assigned Roles Tags
                for (final role in printer.roles)
                  _buildPill(
                    _roleLabel(role),
                    _roleIcon(role),
                    primary.withValues(alpha: 0.08),
                    primary,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          const Divider(height: 1, color: Color(0xFFF3F4F6)),

          // Card Buttons Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (isSaving || isTesting)
                        ? null
                        : () => _handleTestPrint(printer),
                    icon: isTesting
                        ? SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.8,
                              color: primary,
                            ),
                          )
                        : Icon(Icons.print_rounded, size: 14, color: primary),
                    label: Text(
                      isTesting ? 'Cetak...' : 'Cetak Tes',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: primary,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      side: BorderSide(color: primary.withValues(alpha: 0.4)),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: Color(0xFF4B5563),
                  ),
                  onPressed: isSaving ? null : () => _openEditor(printer),
                  tooltip: 'Edit',
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: Color(0xFFEF4444),
                  ),
                  onPressed: isSaving ? null : () => _delete(printer),
                  tooltip: 'Hapus',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPill(String label, IconData icon, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: fg),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  IconData _roleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'cashier':
        return Icons.receipt_long_rounded;
      case 'kitchen':
        return Icons.restaurant_rounded;
      case 'label':
        return Icons.label_important_rounded;
      case 'report':
        return Icons.analytics_rounded;
      default:
        return Icons.print_rounded;
    }
  }

  String _roleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'cashier':
        return 'Kasir';
      case 'kitchen':
        return 'Dapur';
      case 'label':
        return 'Stiker';
      case 'report':
        return 'Laporan';
      default:
        return role;
    }
  }
}

/// Keyboard-Safe, Professional Mobile Editor Bottom Sheet with Editable CPL
class _PrinterEditorBottomSheet extends StatefulWidget {
  const _PrinterEditorBottomSheet({
    required this.printer,
    required this.bluetoothDevices,
    required this.onSave,
  });

  final PrinterDeviceConfig? printer;
  final List<BluetoothDevice> bluetoothDevices;
  final Future<void> Function(PrinterDeviceConfig config) onSave;

  @override
  State<_PrinterEditorBottomSheet> createState() =>
      _PrinterEditorBottomSheetState();
}

class _PrinterEditorBottomSheetState extends State<_PrinterEditorBottomSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _targetCtrl;
  late final TextEditingController _portCtrl;
  late final TextEditingController _customWidthCtrl;
  late final TextEditingController _charsCtrl;
  late final TextEditingController _fontScaleCtrl;
  late final TextEditingController _lineSpacingCtrl;
  late final TextEditingController _notesCtrl;

  late String _connectionType;
  late String _paperProfileId;
  late bool _supportsAutoCut;
  late bool _isActive;
  bool _isSaving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    final p = widget.printer;
    final suffix = DateTime.now().microsecondsSinceEpoch.toString().substring(
      10,
    );
    final profile = p?.paperProfile ?? kPrinterPaperProfiles[1];

    _nameCtrl = TextEditingController(
      text: p?.displayName ?? 'Printer $suffix',
    );
    _targetCtrl = TextEditingController(text: p?.connectionTarget ?? '');
    _portCtrl = TextEditingController(
      text: (p?.networkPort ?? 9100).toString(),
    );
    _customWidthCtrl = TextEditingController(
      text: p?.customWidthMm?.toStringAsFixed(0) ?? '',
    );
    // CPL (Chars Per Line) is ALWAYS initialized and editable for ALL paper profiles!
    _charsCtrl = TextEditingController(
      text: (p?.charsPerLine ?? profile.defaultCharsPerLine).toString(),
    );
    _fontScaleCtrl = TextEditingController(
      text: (p?.fontScale ?? 1.0).toStringAsFixed(1),
    );
    _lineSpacingCtrl = TextEditingController(
      text: (p?.lineSpacing ?? 0.0).toStringAsFixed(0),
    );
    _notesCtrl = TextEditingController(text: p?.notes ?? '');

    _connectionType = p?.connectionType ?? 'bluetooth';
    _paperProfileId = p?.paperProfileId ?? 'thermal_58';
    _supportsAutoCut = p?.supportsAutoCut ?? false;
    _isActive = p?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _targetCtrl.dispose();
    _portCtrl.dispose();
    _customWidthCtrl.dispose();
    _charsCtrl.dispose();
    _fontScaleCtrl.dispose();
    _lineSpacingCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final p = widget.printer;
    final generatedKey = p?.printerKey.isNotEmpty == true
        ? p!.printerKey
        : 'printer_${DateTime.now().millisecondsSinceEpoch}';

    final config = PrinterDeviceConfig(
      id: p?.id ?? 0,
      printerKey: generatedKey,
      displayName: _nameCtrl.text.trim(),
      connectionType: _connectionType,
      connectionTarget: _targetCtrl.text.trim().isEmpty
          ? null
          : _targetCtrl.text.trim(),
      networkPort: int.tryParse(_portCtrl.text.trim()) ?? 9100,
      paperProfileId: _paperProfileId,
      customWidthMm: double.tryParse(_customWidthCtrl.text.trim()),
      charsPerLine: int.tryParse(_charsCtrl.text.trim()),
      fontScale: double.tryParse(_fontScaleCtrl.text.trim()) ?? 1.0,
      lineSpacing: double.tryParse(_lineSpacingCtrl.text.trim()) ?? 0.0,
      supportsAutoCut: _supportsAutoCut,
      roles: p?.roles ?? const ['cashier'],
      roleBrandFilters: p?.roleBrandFilters ?? const {},
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      isActive: _isActive,
    );

    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    try {
      await widget.onSave(config);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(
          () => _saveError = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.printer == null
                          ? 'Tambah Profil Printer'
                          : 'Edit Profil Printer',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.pop(context),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),

          // Scrollable Form Fields
          Flexible(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                shrinkWrap: true,
                children: [
                  if (_saveError != null) ...[
                    _buildSaveError(_saveError!),
                    const SizedBox(height: 12),
                  ],
                  // Nama Printer
                  _buildFieldLabel('Nama Printer *'),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: _nameCtrl,
                    style: const TextStyle(fontSize: 12),
                    decoration: _inputDecoration('Misal: Printer Kasir Depan'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Nama printer wajib diisi'
                        : null,
                  ),
                  const SizedBox(height: 14),

                  // Tipe Koneksi
                  _buildFieldLabel('Tipe Koneksi'),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildConnBtn(
                        'bluetooth',
                        'Bluetooth',
                        Icons.bluetooth_rounded,
                        primary,
                      ),
                      const SizedBox(width: 6),
                      _buildConnBtn(
                        'network',
                        'LAN',
                        Icons.wifi_rounded,
                        primary,
                      ),
                      const SizedBox(width: 6),
                      _buildConnBtn('usb', 'USB', Icons.usb_rounded, primary),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Alamat Target Koneksi
                  if (_connectionType == 'bluetooth') ...[
                    if (widget.bluetoothDevices.isNotEmpty) ...[
                      _buildFieldLabel('Pilih Perangkat Bluetooth Paired'),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        initialValue:
                            widget.bluetoothDevices.any(
                              (d) => d.address == _targetCtrl.text,
                            )
                            ? _targetCtrl.text
                            : null,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1F2937),
                        ),
                        decoration: _inputDecoration('Pilih printer bluetooth'),
                        items: widget.bluetoothDevices.map((d) {
                          return DropdownMenuItem(
                            value: d.address,
                            child: Text(
                              '${d.name ?? 'Device'} (${d.address})',
                              style: const TextStyle(fontSize: 11),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _targetCtrl.text = val);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                    _buildFieldLabel('Alamat MAC Bluetooth'),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _targetCtrl,
                      style: const TextStyle(fontSize: 12),
                      decoration: _inputDecoration('00:11:22:33:44:55'),
                    ),
                  ] else if (_connectionType == 'network') ...[
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFieldLabel('IP Address *'),
                              const SizedBox(height: 4),
                              TextFormField(
                                controller: _targetCtrl,
                                keyboardType: TextInputType.datetime,
                                style: const TextStyle(fontSize: 12),
                                decoration: _inputDecoration('192.168.1.200'),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                    ? 'IP wajib diisi'
                                    : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFieldLabel('Port'),
                              const SizedBox(height: 4),
                              TextFormField(
                                controller: _portCtrl,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(fontSize: 12),
                                decoration: _inputDecoration('9100'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    _buildFieldLabel('Port USB Target'),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _targetCtrl,
                      style: const TextStyle(fontSize: 12),
                      decoration: _inputDecoration('/dev/bus/usb/001/002'),
                    ),
                  ],
                  const SizedBox(height: 14),

                  // Ukuran & Profil Kertas
                  _buildFieldLabel('Ukuran & Profil Kertas'),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: _paperProfileId,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF1F2937),
                    ),
                    decoration: _inputDecoration('Pilih Profil Kertas'),
                    items: kPrinterPaperProfiles.map((p) {
                      return DropdownMenuItem(
                        value: p.id,
                        child: Text(
                          '${p.label} (${p.widthMm.toStringAsFixed(0)}mm • ${p.defaultCharsPerLine} CPL)',
                          style: const TextStyle(fontSize: 11),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _paperProfileId = val;
                          final profile = kPrinterPaperProfiles.firstWhere(
                            (p) => p.id == val,
                            orElse: () => kPrinterPaperProfiles[1],
                          );
                          _charsCtrl.text = profile.defaultCharsPerLine
                              .toString();
                          if (val == 'custom_roll' &&
                              _customWidthCtrl.text.isEmpty) {
                            _customWidthCtrl.text = '58';
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // Karakter per Baris (CPL) - ALWAYS EDITABLE FOR ALL PROFILES!
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel('Karakter / Baris (CPL)'),
                            const SizedBox(height: 4),
                            TextFormField(
                              controller: _charsCtrl,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontSize: 12),
                              decoration: _inputDecoration('Misal: 32 CPL'),
                            ),
                          ],
                        ),
                      ),
                      if (_paperProfileId == 'custom_roll') ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFieldLabel('Lebar Kertas (mm)'),
                              const SizedBox(height: 4),
                              TextFormField(
                                controller: _customWidthCtrl,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(fontSize: 12),
                                decoration: _inputDecoration('Misal: 58'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Opsi Cetak Lanjutan (Clean Container tanpa Label Clipping)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Opsi Cetak Lanjutan',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF374151),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel('Skala Font (0.8 - 1.5)'),
                                  const SizedBox(height: 4),
                                  TextFormField(
                                    controller: _fontScaleCtrl,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    style: const TextStyle(fontSize: 12),
                                    decoration: _inputDecoration('1.0'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel('Spasi Baris Extra'),
                                  const SizedBox(height: 4),
                                  TextFormField(
                                    controller: _lineSpacingCtrl,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(fontSize: 12),
                                    decoration: _inputDecoration('0'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildFieldLabel('Catatan Printer (Opsional)'),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: _notesCtrl,
                          style: const TextStyle(fontSize: 12),
                          decoration: _inputDecoration(
                            'Misal: Bar Depan atau Dapur Utama',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Switches: Auto-cut & Status Active
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text(
                      'Potong Otomatis (Auto Cut)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'Perintah pemotong kertas fisik',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    value: _supportsAutoCut,
                    activeTrackColor: primary,
                    onChanged: (v) => setState(() => _supportsAutoCut = v),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text(
                      'Status Profil Aktif',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'Aktifkan profil untuk cetak transaksi',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    value: _isActive,
                    activeTrackColor: primary,
                    onChanged: (v) => setState(() => _isActive = v),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Action Bar (Non-Cutoff, Safe Layout)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _submit,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 18,
                        ),
                  label: Text(
                    _isSaving ? 'Menyimpan...' : 'Simpan Profil Printer',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Color(0xFF374151),
      ),
    );
  }

  Widget _buildSaveError(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Text(
        'Profil belum tersimpan: $message',
        style: const TextStyle(fontSize: 11, color: Color(0xFFB91C1C)),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade400),
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 1.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    );
  }

  Widget _buildConnBtn(
    String type,
    String label,
    IconData icon,
    Color primary,
  ) {
    final isSelected = _connectionType == type;

    return Expanded(
      child: InkWell(
        onTap: _isSaving ? null : () => setState(() => _connectionType = type),
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? primary.withValues(alpha: 0.1)
                  : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? primary : const Color(0xFFE5E7EB),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: isSelected ? primary : const Color(0xFF6B7280),
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? primary : const Color(0xFF4B5563),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
