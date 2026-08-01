import 'package:flutter/material.dart';

import '../../../controllers/printer_settings_controller.dart';
import '../../../models/printer_settings_models.dart';

/// Clean, Ergonomic Mobile View for Printer Mapping
class PrinterMappingMobileView extends StatefulWidget {
  const PrinterMappingMobileView({super.key});

  @override
  State<PrinterMappingMobileView> createState() =>
      _PrinterMappingMobileViewState();
}

class _PrinterMappingMobileViewState extends State<PrinterMappingMobileView> {
  final PrinterSettingsController _controller =
      PrinterSettingsController.instance;
  String? _selectedPrinterKey;
  int? _testingPrinterId;
  PrinterDeviceConfig? _draft;
  String? _draftPrinterKey;
  bool _hasUnsavedChanges = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.refresh();
    });
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

  PrinterDeviceConfig _draftFor(PrinterDeviceConfig printer) {
    if (_draftPrinterKey != printer.printerKey) {
      _draft = printer;
      _draftPrinterKey = printer.printerKey;
      _hasUnsavedChanges = false;
    }
    return _draft!;
  }

  Future<void> _selectPrinter(String printerKey) async {
    if (printerKey == _selectedPrinterKey) return;
    if (_hasUnsavedChanges) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Buang perubahan?'),
          content: const Text(
            'Perubahan pemetaan yang belum disimpan akan hilang.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Tetap di sini'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Buang perubahan'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    setState(() {
      _selectedPrinterKey = printerKey;
      _draft = null;
      _draftPrinterKey = null;
      _hasUnsavedChanges = false;
    });
  }

  void _setDraft(PrinterDeviceConfig draft) {
    setState(() {
      _draft = draft;
      _draftPrinterKey = draft.printerKey;
      _hasUnsavedChanges = true;
    });
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
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: ValueListenableBuilder<PrinterSettingsState>(
        valueListenable: _controller.stateNotifier,
        builder: (context, state, _) {
          final printers = state.printers;

          if (state.isLoading && printers.isEmpty) {
            return Center(
              child: CircularProgressIndicator(strokeWidth: 2, color: primary),
            );
          }

          if (printers.isEmpty) {
            return _buildEmptyState();
          }

          if (_selectedPrinterKey == null ||
              printers.every((p) => p.printerKey != _selectedPrinterKey)) {
            _selectedPrinterKey = printers.first.printerKey;
          }

          PrinterDeviceConfig? selected;
          for (final p in printers) {
            if (p.printerKey == _selectedPrinterKey) {
              selected = p;
              break;
            }
          }

          if (selected == null) return const SizedBox();
          selected = _draftFor(selected);

          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 85),
                children: [
                  // 1. Horizontal Printer Selector Pills
                  const Text(
                    'Pilih Printer',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: printers.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 6),
                      itemBuilder: (context, index) {
                        final p = printers[index];
                        final isSelected = p.printerKey == _selectedPrinterKey;

                        return InkWell(
                          onTap: _isSaving
                              ? null
                              : () => _selectPrinter(p.printerKey),
                          borderRadius: BorderRadius.circular(8),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected ? primary : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? primary
                                    : const Color(0xFFE5E7EB),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _connIcon(p.connectionType),
                                  size: 14,
                                  color: isSelected ? Colors.white : primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  p.displayName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFF1F2937),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 2. Selected Printer Info & Test Print Banner
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selected.displayName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                '${selected.connectionType.toUpperCase()} • ${selected.paperProfile.label}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _testingPrinterId == selected.id
                              ? null
                              : () => _handleTestPrint(selected!),
                          icon: _testingPrinterId == selected.id
                              ? SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.8,
                                    color: primary,
                                  ),
                                )
                              : Icon(
                                  Icons.print_rounded,
                                  size: 14,
                                  color: primary,
                                ),
                          label: Text(
                            _testingPrinterId == selected.id
                                ? 'Tes...'
                                : 'Cetak Tes',
                            style: TextStyle(
                              fontSize: 11,
                              color: primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            visualDensity: VisualDensity.compact,
                            side: BorderSide(
                              color: primary.withValues(alpha: 0.4),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 3. Section: Peran Printer
                  const Text(
                    'Peran & Tugas Printer',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tentukan jenis dokumen yang dicetak oleh printer ini:',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      children: [
                        _buildRoleTile(
                          'cashier',
                          'Struk Kasir',
                          'Cetak bukti transaksi pembayaran saat checkout',
                          Icons.receipt_long_rounded,
                          const Color(0xFF2563EB),
                          selected,
                          primary,
                          _isSaving,
                        ),
                        const Divider(
                          height: 1,
                          indent: 14,
                          endIndent: 14,
                          color: Color(0xFFF3F4F6),
                        ),
                        _buildRoleTile(
                          'kitchen',
                          'Dapur & Bar',
                          'Cetak tiket pesanan ke kitchen/bar',
                          Icons.restaurant_rounded,
                          const Color(0xFFD97706),
                          selected,
                          primary,
                          _isSaving,
                        ),
                        const Divider(
                          height: 1,
                          indent: 14,
                          endIndent: 14,
                          color: Color(0xFFF3F4F6),
                        ),
                        _buildRoleTile(
                          'label',
                          'Label & Stiker',
                          'Cetak stiker nama item / label cup',
                          Icons.label_important_rounded,
                          const Color(0xFF9333EA),
                          selected,
                          primary,
                          _isSaving,
                        ),
                        const Divider(
                          height: 1,
                          indent: 14,
                          endIndent: 14,
                          color: Color(0xFFF3F4F6),
                        ),
                        _buildRoleTile(
                          'report',
                          'Laporan Shift',
                          'Cetak ringkasan rekap shift dan audit kas',
                          Icons.analytics_rounded,
                          const Color(0xFF059669),
                          selected,
                          primary,
                          _isSaving,
                        ),
                      ],
                    ),
                  ),

                  // 4. Section: Filter Brand Per Role
                  if (selected.roles.isNotEmpty &&
                      state.availableBrands.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Filter Brand Produk',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Kosongkan filter untuk mencetak semua brand:',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),

                    for (final role in selected.roles) ...[
                      if (role == 'kitchen' ||
                          role == 'cashier' ||
                          role == 'label') ...[
                        _buildBrandFilterBox(
                          selected,
                          role,
                          state.availableBrands,
                          primary,
                          _isSaving,
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ],
                ],
              ),

              // 5. Sticky Bottom Action Bar
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                  ),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed:
                            (_isSaving || state.isSaving || !_hasUnsavedChanges)
                            ? null
                            : () => _saveMapping(selected!),
                        icon: (_isSaving || state.isSaving)
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.8,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.check_circle_outline_rounded,
                                size: 18,
                              ),
                        label: Text(
                          (_isSaving || state.isSaving)
                              ? 'Menyimpan...'
                              : 'Simpan Pemetaan Printer',
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
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.print_disabled_outlined,
              size: 36,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 10),
            const Text(
              'Belum ada printer tersedia',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tambahkan printer terlebih dahulu di menu "Daftar Printer".',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleTile(
    String key,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    PrinterDeviceConfig selected,
    Color primary,
    bool isSaving,
  ) {
    final isChecked = selected.roles.contains(key);

    return SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      secondary: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1F2937),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
      ),
      value: isChecked,
      activeTrackColor: primary,
      onChanged: isSaving
          ? null
          : (val) {
              final nextRoles = List<String>.from(selected.roles);
              if (val) {
                if (!nextRoles.contains(key)) nextRoles.add(key);
              } else {
                nextRoles.remove(key);
              }
              _updatePrinterRoles(selected, nextRoles);
            },
    );
  }

  Widget _buildBrandFilterBox(
    PrinterDeviceConfig selected,
    String role,
    List<String> availableBrands,
    Color primary,
    bool isSaving,
  ) {
    final currentFilters = selected.roleBrandFilters[role] ?? <String>[];
    final isAllSelected = currentFilters.isEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filter Brand: ${_roleTitle(role)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF374151),
                ),
              ),
              TextButton(
                onPressed: isSaving
                    ? null
                    : () {
                        final nextMap = Map<String, List<String>>.from(
                          selected.roleBrandFilters,
                        );
                        if (isAllSelected) {
                          nextMap[role] = List<String>.from(availableBrands);
                        } else {
                          nextMap.remove(role);
                        }
                        _updateRoleBrandFilters(selected, nextMap);
                      },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(
                  isAllSelected ? 'Pilih Semua' : 'Reset (Semua)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: availableBrands.map((brand) {
              final isBrandSelected =
                  isAllSelected || currentFilters.contains(brand);

              return FilterChip(
                label: Text(brand, style: const TextStyle(fontSize: 11)),
                selected: isBrandSelected,
                selectedColor: primary.withValues(alpha: 0.12),
                checkmarkColor: primary,
                backgroundColor: const Color(0xFFF3F4F6),
                side: BorderSide(
                  color: isBrandSelected
                      ? primary.withValues(alpha: 0.3)
                      : const Color(0xFFE5E7EB),
                ),
                visualDensity: VisualDensity.compact,
                onSelected: isSaving
                    ? null
                    : (selectedVal) {
                        final nextMap = Map<String, List<String>>.from(
                          selected.roleBrandFilters,
                        );
                        List<String> list = List<String>.from(
                          nextMap[role] ??
                              (isAllSelected ? availableBrands : []),
                        );

                        if (selectedVal) {
                          if (!list.contains(brand)) list.add(brand);
                        } else {
                          list.remove(brand);
                        }

                        if (list.length == availableBrands.length ||
                            list.isEmpty) {
                          nextMap.remove(role);
                        } else {
                          nextMap[role] = list;
                        }
                        _updateRoleBrandFilters(selected, nextMap);
                      },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  IconData _connIcon(String type) {
    switch (type.toLowerCase()) {
      case 'bluetooth':
        return Icons.bluetooth_rounded;
      case 'network':
        return Icons.wifi_rounded;
      case 'usb':
        return Icons.usb_rounded;
      default:
        return Icons.print_rounded;
    }
  }

  String _roleTitle(String role) {
    switch (role) {
      case 'cashier':
        return 'Struk Kasir';
      case 'kitchen':
        return 'Dapur & Bar';
      case 'label':
        return 'Label / Stiker';
      case 'report':
        return 'Laporan';
      default:
        return role;
    }
  }

  void _updatePrinterRoles(
    PrinterDeviceConfig selected,
    List<String> nextRoles,
  ) {
    _setDraft(selected.copyWith(roles: nextRoles));
  }

  void _updateRoleBrandFilters(
    PrinterDeviceConfig selected,
    Map<String, List<String>> nextFilters,
  ) {
    _setDraft(selected.copyWith(roleBrandFilters: nextFilters));
  }

  Future<void> _saveMapping(PrinterDeviceConfig selected) async {
    setState(() => _isSaving = true);
    try {
      await _controller.savePrinter(selected);
      if (!mounted) return;
      setState(() {
        _draft = null;
        _draftPrinterKey = null;
        _hasUnsavedChanges = false;
      });
      _showFeedback('Pemetaan printer berhasil disimpan');
    } catch (error) {
      _showFeedback(
        'Pemetaan tidak dapat disimpan: ${_messageFor(error)}',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
