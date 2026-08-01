import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

final RegExp _digitOnlyRegex = RegExp(r'[^0-9]');

/// Model data hasil pengisian form Kas Keluar
class KasKeluarInputData {
  final String nama;
  final int amount;
  final String catatan;
  final DateTime tanggal;
  final dynamic paymentModeId;
  final String? paymentModeName;

  const KasKeluarInputData({
    required this.nama,
    required this.amount,
    required this.catatan,
    required this.tanggal,
    this.paymentModeId,
    this.paymentModeName,
  });

  Map<String, dynamic> toJson() {
    return {
      'nama': nama,
      'amount': amount,
      'catatan': catatan,
      'tanggal': DateFormat('yyyy-MM-dd').format(tanggal),
      'payment_mode_id': paymentModeId,
      'payment_mode_name': paymentModeName,
      'created_at': tanggal.toIso8601String(),
    };
  }
}

/// Modal Dialog Form Kas Keluar Estetik
class KasKeluarDialog extends StatefulWidget {
  final KasKeluarInputData? initialData;
  final List<Map<String, dynamic>>? paymentModes;
  final ValueChanged<KasKeluarInputData>? onSubmit;
  final bool optimizeForMobileKeyboard;

  const KasKeluarDialog({
    super.key,
    this.initialData,
    this.paymentModes,
    this.onSubmit,
    this.optimizeForMobileKeyboard = false,
  });

  /// Helper statis untuk menampilkan dialog Kas Keluar dari mana saja
  static Future<KasKeluarInputData?> show(
    BuildContext context, {
    KasKeluarInputData? initialData,
    List<Map<String, dynamic>>? paymentModes,
    ValueChanged<KasKeluarInputData>? onSubmit,
    bool optimizeForMobileKeyboard = false,
  }) {
    if (optimizeForMobileKeyboard) {
      return showModalBottomSheet<KasKeluarInputData>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        builder: (context) {
          final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
          return RepaintBoundary(
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: KasKeluarDialog(
                initialData: initialData,
                paymentModes: paymentModes,
                onSubmit: onSubmit,
                optimizeForMobileKeyboard: true,
              ),
            ),
          );
        },
      );
    }
    return showDialog<KasKeluarInputData>(
      context: context,
      barrierDismissible: false,
      builder: (context) => KasKeluarDialog(
        initialData: initialData,
        paymentModes: paymentModes,
        onSubmit: onSubmit,
        optimizeForMobileKeyboard: false,
      ),
    );
  }

  @override
  State<KasKeluarDialog> createState() => _KasKeluarDialogState();
}

class _KasKeluarDialogState extends State<KasKeluarDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _namaController;
  late final TextEditingController _amountController;
  late final TextEditingController _catatanController;
  late DateTime _selectedDate;
  dynamic _selectedPaymentModeId;

  late final List<Map<String, dynamic>> _availablePaymentModes;
  String? _errorMessage;

  static const _presetAmounts = [10000, 20000, 50000, 100000, 200000];

  @override
  void initState() {
    super.initState();
    _namaController = TextEditingController(
      text: widget.initialData?.nama ?? '',
    );
    _amountController = TextEditingController(
      text: widget.initialData != null && widget.initialData!.amount > 0
          ? _formatCurrency(widget.initialData!.amount)
          : '',
    );
    _catatanController = TextEditingController(
      text: widget.initialData?.catatan ?? '',
    );
    _selectedDate = widget.initialData?.tanggal ?? DateTime.now();

    _availablePaymentModes =
        (widget.paymentModes != null && widget.paymentModes!.isNotEmpty)
        ? widget.paymentModes!
        : [
            {'id': 1, 'name': 'Cash / Tunai', 'icon': Icons.payments_rounded},
            {
              'id': 2,
              'name': 'Transfer Bank',
              'icon': Icons.account_balance_rounded,
            },
            {'id': 3, 'name': 'QRIS', 'icon': Icons.qr_code_2_rounded},
            {'id': 4, 'name': 'EDC / Kartu', 'icon': Icons.credit_card_rounded},
          ];

    _initDefaultPaymentMode();
  }

  void _initDefaultPaymentMode() {
    if (widget.initialData?.paymentModeId != null) {
      _selectedPaymentModeId = widget.initialData!.paymentModeId;
      return;
    }

    for (final mode in _availablePaymentModes) {
      final name = (mode['name'] ?? mode['payment_name'] ?? mode['title'] ?? '')
          .toString()
          .toLowerCase();
      final code = (mode['code'] ?? '').toString().toLowerCase();
      if (name.contains('cash') ||
          name.contains('tunai') ||
          code.contains('cash')) {
        _selectedPaymentModeId =
            mode['id'] ?? mode['remote_id'] ?? mode['payment_mode_id'];
        return;
      }
    }

    if (_availablePaymentModes.isNotEmpty) {
      final first = _availablePaymentModes.first;
      _selectedPaymentModeId =
          first['id'] ?? first['remote_id'] ?? first['payment_mode_id'];
    }
  }

  @override
  void dispose() {
    _namaController.dispose();
    _amountController.dispose();
    _catatanController.dispose();
    super.dispose();
  }

  String _formatCurrency(int value) {
    final fmt = NumberFormat.currency(
      locale: 'id_ID',
      symbol: '',
      decimalDigits: 0,
    );
    return fmt.format(value).trim();
  }

  int _parseAmount(String text) {
    final clean = text.replaceAll(_digitOnlyRegex, '');
    return int.tryParse(clean) ?? 0;
  }

  void _onAmountChanged(String val) {
    if (widget.optimizeForMobileKeyboard) return;
    final numeric = _parseAmount(val);
    if (numeric == 0) {
      _amountController.value = const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
      return;
    }
    final formatted = _formatCurrency(numeric);
    _amountController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  void _setPresetAmount(int amount) {
    final formatted = _formatCurrency(amount);
    setState(() {
      _amountController.text = formatted;
      _amountController.selection = TextSelection.collapsed(
        offset: formatted.length,
      );
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFE11D48),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF1F2937),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _handleSubmit() {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final amount = _parseAmount(_amountController.text);
    if (amount <= 0) {
      setState(() {
        _errorMessage = 'Nominal kas keluar harus lebih dari 0.';
      });
      return;
    }

    String? selectedModeName;
    for (final mode in _availablePaymentModes) {
      final id = mode['id'] ?? mode['remote_id'] ?? mode['payment_mode_id'];
      if (id == _selectedPaymentModeId) {
        selectedModeName =
            (mode['name'] ?? mode['payment_name'] ?? mode['title'])?.toString();
        break;
      }
    }

    final data = KasKeluarInputData(
      nama: _namaController.text.trim(),
      amount: amount,
      catatan: _catatanController.text.trim(),
      tanggal: _selectedDate,
      paymentModeId: _selectedPaymentModeId,
      paymentModeName: selectedModeName,
    );

    if (widget.onSubmit != null) {
      widget.onSubmit!(data);
    }

    Navigator.of(context).pop(data);
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMMM yyyy', 'id_ID');
    final screenSize = MediaQuery.sizeOf(context);

    final mainWidget = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 500,
        maxHeight: screenSize.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Banner Estetik
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFFF1F2), Color(0xFFFFE4E6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x26E11D48),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.outbox_rounded,
                    color: Color(0xFFE11D48),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Form Kas Keluar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                          letterSpacing: -0.2,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Catat rincian dan nominal pengeluaran kas tunai toko',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xCCFFFFFF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF64748B),
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Form Body
          Flexible(
            child: SingleChildScrollView(
              keyboardDismissBehavior: widget.optimizeForMobileKeyboard
                  ? ScrollViewKeyboardDismissBehavior.onDrag
                  : ScrollViewKeyboardDismissBehavior.manual,
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errorMessage != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: Color(0xFFDC2626),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFB91C1C),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Section: Hero Nominal (Amount)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text(
                                'NOMINAL KAS KELUAR *',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF64748B),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                'Nominal Tunai',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            inputFormatters: widget.optimizeForMobileKeyboard
                                ? [
                                    FilteringTextInputFormatter.digitsOnly,
                                    _CurrencyInputFormatter(),
                                  ]
                                : [FilteringTextInputFormatter.digitsOnly],
                            onChanged: _onAmountChanged,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFE11D48),
                              letterSpacing: -0.5,
                            ),
                            decoration: InputDecoration(
                              hintText: '0',
                              hintStyle: const TextStyle(
                                fontSize: 22,
                                color: Color(0xFFCBD5E1),
                                fontWeight: FontWeight.w600,
                              ),
                              prefixIcon: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                margin: const EdgeInsets.only(right: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFE4E6),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Rp',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFE11D48),
                                  ),
                                ),
                              ),
                              prefixIconConstraints: const BoxConstraints(
                                minWidth: 44,
                                minHeight: 38,
                              ),
                              isDense: true,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Nominal kas keluar wajib diisi';
                              }
                              if (_parseAmount(val) <= 0) {
                                return 'Nominal harus lebih dari 0';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),
                          const SizedBox(height: 10),
                          // Quick Amount Chips
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _presetAmounts.map((preset) {
                                final isSelected =
                                    _parseAmount(_amountController.text) ==
                                    preset;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: InkWell(
                                    onTap: () => _setPresetAmount(preset),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(0xFFE11D48)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isSelected
                                              ? const Color(0xFFE11D48)
                                              : const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: Text(
                                        '${preset ~/ 1000}rb',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected
                                              ? Colors.white
                                              : const Color(0xFF475569),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Row: Nama Penerima & Tanggal
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Field Nama
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'NAMA / PENERIMA *',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF475569),
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _namaController,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF1E293B),
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Penerima / Pengeluar',
                                  hintStyle: const TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.person_outline_rounded,
                                    size: 16,
                                    color: Color(0xFF64748B),
                                  ),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE11D48),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                validator: (val) =>
                                    (val == null || val.trim().isEmpty)
                                    ? 'Nama wajib diisi'
                                    : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Field Tanggal
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'TANGGAL *',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF475569),
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: _selectDate,
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8.5,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.white,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_today_rounded,
                                        size: 15,
                                        color: Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          dateFormat.format(_selectedDate),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1E293B),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Field Payment Mode (Estetik Dropdown)
                    const Text(
                      'METODE PEMBAYARAN (PAYMENT MODE) *',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569),
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<dynamic>(
                      initialValue: _selectedPaymentModeId,
                      isDense: true,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF1E293B),
                      ),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.payment_rounded,
                          size: 16,
                          color: Color(0xFF64748B),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFE11D48),
                            width: 1.5,
                          ),
                        ),
                      ),
                      items: _availablePaymentModes.map((mode) {
                        final id =
                            mode['id'] ??
                            mode['remote_id'] ??
                            mode['payment_mode_id'];
                        final name =
                            (mode['name'] ??
                                    mode['payment_name'] ??
                                    mode['title'] ??
                                    'Metode $id')
                                .toString();
                        final IconData icon = mode['icon'] is IconData
                            ? mode['icon']
                            : Icons.account_balance_wallet_rounded;
                        return DropdownMenuItem<dynamic>(
                          value: id,
                          child: Row(
                            children: [
                              Icon(
                                icon,
                                size: 15,
                                color: const Color(0xFFE11D48),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedPaymentModeId = val;
                        });
                      },
                      validator: (val) =>
                          val == null ? 'Pilih metode pembayaran' : null,
                    ),
                    const SizedBox(height: 14),

                    // Field Catatan
                    const Text(
                      'CATATAN / KEPERLUAN',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569),
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _catatanController,
                      maxLines: 2,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF1E293B),
                      ),
                      decoration: InputDecoration(
                        hintText:
                            'Rincian pengeluaran (misal: Beli galon, Biaya kebersihan)',
                        hintStyle: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF94A3B8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFE11D48),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Action Buttons Estetik
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Batal',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF43F5E), Color(0xFFE11D48)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x40E11D48),
                                blurRadius: 8,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: _handleSubmit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 11,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(
                              Icons.check_circle_rounded,
                              size: 16,
                            ),
                            label: const Text(
                              'Simpan Kas Keluar',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (widget.optimizeForMobileKeyboard) {
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        clipBehavior: Clip.antiAlias,
        child: mainWidget,
      );
    }

    return Dialog(
      insetAnimationDuration: const Duration(milliseconds: 100),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 12,
      clipBehavior: Clip.antiAlias,
      backgroundColor: Colors.white,
      child: mainWidget,
    );
  }
}

class _CurrencyInputFormatter extends TextInputFormatter {
  static final NumberFormat _formatter = NumberFormat('#,###', 'id_ID');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    final value =
        int.tryParse(newValue.text.replaceAll(_digitOnlyRegex, '')) ?? 0;
    if (value == 0) return const TextEditingValue();
    final text = _formatter.format(value);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
