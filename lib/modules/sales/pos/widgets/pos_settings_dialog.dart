import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/services/sync/pos_v2_options_service.dart';
import '../../../../../../core/services/local/database_service.dart';

class PosSettingsDialog extends StatefulWidget {
  const PosSettingsDialog({super.key});

  @override
  State<PosSettingsDialog> createState() => _PosSettingsDialogState();
}

class _PosSettingsDialogState extends State<PosSettingsDialog> {
  int _selectedIndex = 0;
  bool _isLoading = true;
  bool _isChanged = false;

  Map<String, dynamic> _appSettings = {};

  bool _showImage = true;
  bool _showName = true;
  bool _showPrice = true;
  bool _showStock = false;
  bool _compactGrid = false;
  bool _darkMode = false;

  // Mockups for other tabs
  bool _autoTax = true;
  bool _autoService = false;
  bool _autoPrint = true;
  bool _kitchenPrint = true;
  bool _printCashier = true;
  bool _printFooter = true;

  List<Map<String, dynamic>> _taxesList = [];
  String? _selectedTaxId;

  final List<String> _tabs = [
    'Tampilan',
    'Pajak & Biaya',
    'Struk',
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final options = await PosV2OptionsService.instance.getLocalOptions();
      final raw = options['pos_app_settings'];
      try {
        if (raw is Map) {
          _appSettings = Map<String, dynamic>.from(raw);
        } else if (raw is String && raw.isNotEmpty) {
          _appSettings = jsonDecode(raw) as Map<String, dynamic>;
        }
      } catch (_) {}

      final display = _appSettings['display'] is Map<String, dynamic>
          ? _appSettings['display'] as Map<String, dynamic>
          : <String, dynamic>{};

      final taxSetting = _appSettings['tax'] is Map<String, dynamic>
          ? _appSettings['tax'] as Map<String, dynamic>
          : <String, dynamic>{};

      final printerSetting = _appSettings['printer'] is Map<String, dynamic>
          ? _appSettings['printer'] as Map<String, dynamic>
          : <String, dynamic>{};

      List<Map<String, dynamic>> taxesList = [];
      try {
        final db = await DatabaseService.instance.database;
        taxesList = await db.query('pos_tax');
      } catch (_) {}

      if (mounted) {
        setState(() {
          _showImage = display['show_image'] ?? true;
          _showName = display['show_name'] ?? true;
          _showPrice = display['show_price'] ?? true;
          _showStock = display['show_stock'] ?? false;
          _compactGrid = display['compact_grid'] ?? false;
          _darkMode = display['dark_mode'] ?? false;
          _selectedTaxId = taxSetting['tax_id']?.toString();
          _autoTax = taxSetting['auto_tax'] ?? false;
          _autoPrint = printerSetting['auto_print'] ?? true;
          _taxesList = taxesList;
        });
      }
    } catch (e, st) {
      debugPrint('Error _loadSettings: $e\n$st');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _updateDisplaySetting(String key, bool value) {
    // Optimistic UI Update
    setState(() {
      final display = _appSettings['display'] is Map<String, dynamic>
          ? _appSettings['display'] as Map<String, dynamic>
          : <String, dynamic>{};
      
      display[key] = value;
      _appSettings['display'] = display;
      _isChanged = true;

      _showImage = display['show_image'] ?? true;
      _showName = display['show_name'] ?? true;
      _showPrice = display['show_price'] ?? true;
      _showStock = display['show_stock'] ?? false;
      _compactGrid = display['compact_grid'] ?? false;
      _darkMode = display['dark_mode'] ?? false;
    });

    _saveSettingsDebounced();
  }

  void _updatePrinterSetting(String key, bool value) {
    setState(() {
      final printer = _appSettings['printer'] is Map<String, dynamic>
          ? _appSettings['printer'] as Map<String, dynamic>
          : <String, dynamic>{};
      
      printer[key] = value;
      _appSettings['printer'] = printer;
      _isChanged = true;

      _autoPrint = printer['auto_print'] ?? true;
    });
    _saveSettingsDebounced();
  }

  void _saveSettingsDebounced() {
    // Eagerly update SQLite so that even if the dialog is closed immediately,
    // the state is saved locally.
    PosV2OptionsService.instance.updateOptionLocalOnly('pos_app_settings', _appSettings);

    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    
    _debounceTimer = Timer(const Duration(milliseconds: 1000), () async {
      final success = await PosV2OptionsService.instance.updateOption('pos_app_settings', _appSettings);
      if (mounted && !success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Gagal sinkronisasi pengaturan ke server. Pastikan koneksi internet stabil.'),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_isChanged ? _appSettings['display'] : null);
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          width: 700,
          height: 480,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Row(
              children: [
                // Left Sidebar Navigation
                Container(
                  width: 200,
                  color: const Color(0xFFF8FAFC),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.tune_rounded,
                                    color: AppColors.primary,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'Pengaturan',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Sesuaikan opsi POS',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          itemCount: _tabs.length,
                          itemBuilder: (context, index) {
                            final isSelected = _selectedIndex == index;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: InkWell(
                                onTap: () => setState(() => _selectedIndex = index),
                                borderRadius: BorderRadius.circular(10),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _getIconForTab(index),
                                        size: 16,
                                        color: isSelected ? AppColors.primary : const Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        _tabs[index],
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                          color: isSelected ? AppColors.primary : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1, color: Color(0xFFE2E8F0)),
                // Right Content Area
                Expanded(
                  child: Container(
                    color: Colors.white,
                    child: Stack(
                      children: [
                        Column(
                          children: [
                            // Header
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _tabs[_selectedIndex],
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      Navigator.of(context).pop(_isChanged ? _appSettings['display'] : null);
                                    },
                                    icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 20),
                                    splashRadius: 20,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ),
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          // Content
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              child: _buildContentForTab(_selectedIndex),
                            ),
                          ),
                        ],
                      ),
                      if (_isLoading)
                        Container(
                          color: Colors.white.withOpacity(0.6),
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ), // closes Row
        ), // closes ClipRRect
      ), // closes Container
    ), // closes Dialog
    ); // closes PopScope
  }

  IconData _getIconForTab(int index) {
    switch (index) {
      case 0: return Icons.desktop_windows_outlined;
      case 1: return Icons.receipt_long_outlined;
      case 2: return Icons.print_outlined;
      default: return Icons.settings_outlined;
    }
  }

  Widget _buildContentForTab(int index) {
    switch (index) {
      case 0:
        return _buildTampilanTab();
      case 1:
        return _buildPajakTab();
      case 2:
        return _buildStrukTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTampilanTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildSectionTitle('Kartu Produk'),
        _buildSettingToggle(
          title: 'Tampilkan Gambar',
          subtitle: 'Menampilkan gambar pada kartu produk (Wajib)',
          value: true,
          onChanged: null, // Dikunci
        ),
        _buildSettingToggle(
          title: 'Tampilkan Nama',
          subtitle: 'Menampilkan teks nama produk',
          value: _showName,
          onChanged: (v) => _updateDisplaySetting('show_name', v),
        ),
        _buildSettingToggle(
          title: 'Tampilkan Harga',
          subtitle: 'Menampilkan nominal harga produk',
          value: _showPrice,
          onChanged: (v) => _updateDisplaySetting('show_price', v),
        ),
        _buildSettingToggle(
          title: 'Tampilkan Stok',
          subtitle: 'Menampilkan sisa stok produk',
          value: _showStock,
          onChanged: (v) => _updateDisplaySetting('show_stock', v),
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('Tema & Navigasi'),
        _buildSettingToggle(
          title: 'Ukuran Grid Kompak',
          subtitle: 'Menampilkan lebih banyak produk dalam satu layar',
          value: _compactGrid,
          onChanged: (v) => _updateDisplaySetting('compact_grid', v),
        ),
        _buildSettingToggle(
          title: 'Mode Gelap (Dark Mode)',
          subtitle: 'Ganti tampilan kasir menjadi warna gelap',
          value: _darkMode,
          onChanged: (v) => _updateDisplaySetting('dark_mode', v),
        ),
      ],
    );
  }

  void _updateTaxSetting(String? taxId) {
    setState(() {
      _selectedTaxId = taxId;
      final tax = _appSettings['tax'] is Map<String, dynamic>
          ? _appSettings['tax'] as Map<String, dynamic>
          : <String, dynamic>{};
      tax['tax_id'] = taxId;
      _appSettings['tax'] = tax;
      _isChanged = true;
    });
    _saveSettingsDebounced();
  }

  void _updateAutoTaxSetting(bool value) {
    setState(() {
      _autoTax = value;
      final tax = _appSettings['tax'] is Map<String, dynamic>
          ? _appSettings['tax'] as Map<String, dynamic>
          : <String, dynamic>{};
      tax['auto_tax'] = value;
      _appSettings['tax'] = tax;
      _isChanged = true;
    });
    _saveSettingsDebounced();
  }

  Widget _buildPajakTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildSectionTitle('Pengaturan Pajak (PPN)'),
        _buildSettingToggle(
          title: 'Aktifkan Pajak Otomatis',
          subtitle: 'Tambahkan pajak secara otomatis pada transaksi',
          value: _autoTax,
          onChanged: _updateAutoTaxSetting,
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Pilih Jenis Pajak',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedTaxId,
                  hint: const Text('Pilih Pajak', style: TextStyle(fontSize: 13)),
                  icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF9CA3AF)),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Tidak Ada', style: TextStyle(fontSize: 13)),
                    ),
                    ..._taxesList.map((tax) {
                      final remoteId = tax['remote_id']?.toString() ?? '';
                      final name = tax['name']?.toString() ?? '';
                      final rate = tax['taxrate']?.toString() ?? '';
                      return DropdownMenuItem(
                        value: remoteId,
                        child: Text('$name ($rate%)', style: const TextStyle(fontSize: 13)),
                      );
                    }),
                  ],
                  onChanged: _updateTaxSetting,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('Biaya Layanan (Service Charge)'),
        _buildSettingToggle(
          title: 'Aktifkan Biaya Layanan',
          subtitle: 'Tambahkan biaya ekstra pada transaksi dine-in',
          value: _autoService,
          onChanged: (v) => setState(() => _autoService = v),
        ),
      ],
    );
  }

  Widget _buildStrukTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildSectionTitle('Pencetakan Otomatis'),
        _buildSettingToggle(
          title: 'Cetak Struk Setelah Bayar',
          subtitle: 'Otomatis mencetak struk ketika transaksi selesai',
          value: _autoPrint,
          onChanged: (v) => _updatePrinterSetting('auto_print', v),
        ),
        _buildSettingToggle(
          title: 'Cetak Tiket Dapur',
          subtitle: 'Otomatis mencetak pesanan ke printer dapur',
          value: _kitchenPrint,
          onChanged: (v) => setState(() => _kitchenPrint = v),
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('Informasi Struk'),
        _buildSettingToggle(
          title: 'Tampilkan Nama Kasir',
          subtitle: 'Mencantumkan nama staf yang melayani',
          value: _printCashier,
          onChanged: (v) => setState(() => _printCashier = v),
        ),
        _buildSettingToggle(
          title: 'Tampilkan Catatan Kaki',
          subtitle: 'Tampilkan pesan terima kasih di bawah struk',
          value: _printFooter,
          onChanged: (v) => setState(() => _printFooter = v),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF475569),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingToggle({
    required String title,
    required String subtitle,
    required bool value,
    ValueChanged<bool>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: value ? AppColors.secondary.withOpacity(0.5) : const Color(0xFFE5E7EB),
          ),
        ),
        child: SwitchListTile.adaptive(
          value: value,
          onChanged: onChanged,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: onChanged == null ? const Color(0xFF9CA3AF) : const Color(0xFF111827),
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: onChanged == null ? const Color(0xFFD1D5DB) : const Color(0xFF6B7280),
            ),
          ),
          activeTrackColor: onChanged == null ? const Color(0xFFE5E7EB) : AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildSettingField({
    required String title,
    required String value,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
          ),
          Container(
            width: 80,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
