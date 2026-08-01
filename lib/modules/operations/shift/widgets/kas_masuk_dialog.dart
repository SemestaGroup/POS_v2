import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Model data hasil pengisian form Kas Masuk
class KasMasukInputData {
  final String nama;
  final int amount;
  final String catatan;
  final DateTime tanggal;
  final dynamic paymentModeId;
  final String? paymentModeName;

  const KasMasukInputData({
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

final RegExp _digitOnlyRegex = RegExp(r'[^0-9]');

/// Modal Dialog Form Kas Masuk Estetik (Petty Cash In)
class KasMasukDialog extends StatefulWidget {
  final KasMasukInputData? initialData;
  final List<Map<String, dynamic>>? paymentModes;
  final ValueChanged<KasMasukInputData>? onSubmit;
  final bool optimizeForMobileKeyboard;

  const KasMasukDialog({
    super.key,
    this.initialData,
    this.paymentModes,
    this.onSubmit,
    this.optimizeForMobileKeyboard = false,
  });

  /// Helper statis untuk menampilkan dialog Kas Masuk dari mana saja
  static Future<KasMasukInputData?> show(
    BuildContext context, {
    KasMasukInputData? initialData,
    List<Map<String, dynamic>>? paymentModes,
    ValueChanged<KasMasukInputData>? onSubmit,
    bool optimizeForMobileKeyboard = false,
  }) {
    if (optimizeForMobileKeyboard) {
      return showModalBottomSheet<KasMasukInputData>(
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
              child: KasMasukDialog(
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
    return showDialog<KasMasukInputData>(
      context: context,
      barrierDismissible: false,
      builder: (context) => KasMasukDialog(
        initialData: initialData,
        paymentModes: paymentModes,
        onSubmit: onSubmit,
        optimizeForMobileKeyboard: false,
      ),
    );
  }

  @override
  State<KasMasukDialog> createState() => _KasMasukDialogState();
}

class _KasMasukDialogState extends State<KasMasukDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _namaController;
  late TextEditingController _amountController;
  late TextEditingController _catatanController;

  late DateTime _selectedDate;
  dynamic _selectedPaymentModeId;

  bool _isSubmitting = false;
  String? _errorMessage;

  static final NumberFormat _currencyFormatter = NumberFormat('#,###', 'id_ID');
  static final DateFormat _dateFormat = DateFormat('dd MMMM yyyy', 'id_ID');
  static const List<int> _presetAmounts = [10000, 20000, 50000, 100000, 200000];

  late final List<Map<String, dynamic>> _availablePaymentModes;

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;

    _namaController = TextEditingController(
      text: data?.nama ?? 'Tambah Petty Cash',
    );
    _catatanController = TextEditingController(text: data?.catatan ?? '');
    _selectedDate = data?.tanggal ?? DateTime.now();

    _availablePaymentModes =
        (widget.paymentModes != null && widget.paymentModes!.isNotEmpty)
        ? widget.paymentModes!
        : [
            {'id': 1, 'name': 'Kas / Tunai', 'type': 'cash'},
          ];

    final initialAmount = data?.amount ?? 0;
    _amountController = TextEditingController(
      text: initialAmount > 0 ? _formatCurrency(initialAmount) : '',
    );

    final modes = _availablePaymentModes;
    if (data?.paymentModeId != null) {
      _selectedPaymentModeId = data!.paymentModeId;
    } else {
      final cashMode = modes.firstWhere((m) {
        final name = (m['name'] ?? m['payment_name'] ?? m['title'] ?? '')
            .toString()
            .toLowerCase();
        return name.contains('cash') || name.contains('tunai');
      }, orElse: () => modes.first);
      _selectedPaymentModeId =
          cashMode['id'] ??
          cashMode['remote_id'] ??
          cashMode['payment_mode_id'];
    }
  }

  @override
  void dispose() {
    _namaController.dispose();
    _amountController.dispose();
    _catatanController.dispose();
    super.dispose();
  }

  String _formatCurrency(int val) {
    return _currencyFormatter.format(val);
  }

  int _parseAmount(String text) {
    final clean = text.replaceAll(_digitOnlyRegex, '');
    return int.tryParse(clean) ?? 0;
  }

  int get _parsedAmount => _parseAmount(_amountController.text);

  void _onAmountChanged(String val) {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
  }

  void _setPresetAmount(int amount) {
    final formatted = _formatCurrency(amount);
    setState(() {
      _amountController.text = formatted;
      _amountController.selection = TextSelection.collapsed(
        offset: formatted.length,
      );
      _errorMessage = null;
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
              primary: Color(0xFF10B981),
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
        _errorMessage = 'Nominal kas masuk harus lebih dari 0.';
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

    final data = KasMasukInputData(
      nama: _namaController.text.trim().isEmpty
          ? 'Kas Masuk'
          : _namaController.text.trim(),
      amount: amount,
      catatan: _catatanController.text.trim(),
      tanggal: _selectedDate,
      paymentModeId: _selectedPaymentModeId,
      paymentModeName: selectedModeName,
    );

    setState(() => _isSubmitting = true);

    if (widget.onSubmit != null) {
      widget.onSubmit!(data);
    }

    Navigator.of(context).pop(data);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);

    final mainWidget = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 500,
        maxHeight: screenSize.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Banner Estetik Emerald Green
          RepaintBoundary(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFECFDF5), Color(0xD1D1FAE5)],
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
                          color: Color(0x2610B981),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.move_to_inbox_rounded,
                      color: Color(0xFF10B981),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Form Kas Masuk (Petty Cash)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                            letterSpacing: -0.2,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Catat rincian dan nominal penambahan kas tunai toko',
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
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Hero Card Input Nominal
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
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
                                'NOMINAL KAS MASUK *',
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
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              _CurrencyInputFormatter(),
                            ],
                            onChanged: _onAmountChanged,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF10B981),
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
                                  color: const Color(0xFFD1FAE5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Rp',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF10B981),
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
                                return 'Nominal kas masuk wajib diisi';
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
                                final isSelected = _parsedAmount == preset;
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
                                            ? const Color(0xFF10B981)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isSelected
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: Text(
                                        '${preset ~/ 1000}rb',
                                        style: TextStyle(
                                          fontSize: 11.5,
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

                    const SizedBox(height: 18),

                    // Responsive Layout: 1 Kolom untuk Mobile, 2 Kolom untuk Tablet
                    if (widget.optimizeForMobileKeyboard) ...[
                      const Text(
                        'Nama / Sumber Uang *',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _namaController,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1E293B),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Misal: Tambah Petty Cash',
                          hintStyle: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0xFFCBD5E1),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0xFFCBD5E1),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0xFF10B981),
                              width: 1.5,
                            ),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Nama wajib diisi';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Tanggal',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: _selectDate,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                                size: 16,
                                color: Color(0xFF64748B),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _dateFormat.format(_selectedDate),
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E293B),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      // Grid 2 Kolom (Nama & Tanggal)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Nama / Sumber Uang Field
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Nama / Sumber Uang *',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _namaController,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF1E293B),
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Misal: Tambah Petty Cash',
                                    hintStyle: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 12,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFCBD5E1),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFCBD5E1),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF10B981),
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Nama wajib diisi';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 14),

                          // Tanggal Field
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Tanggal',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: _selectDate,
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 11,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(0xFFCBD5E1),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.calendar_today_rounded,
                                          size: 16,
                                          color: Color(0xFF64748B),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _dateFormat.format(_selectedDate),
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF1E293B),
                                            ),
                                            overflow: TextOverflow.ellipsis,
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
                    ],

                    const SizedBox(height: 14),

                    // Dropdown Metode Pembayaran
                    const Text(
                      'Metode Pembayaran',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<dynamic>(
                      initialValue: _selectedPaymentModeId,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF1E293B),
                      ),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFCBD5E1),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFCBD5E1),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFF10B981),
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
                                    'Kas/Tunai')
                                .toString();
                        return DropdownMenuItem<dynamic>(
                          value: id,
                          child: Row(
                            children: [
                              Icon(
                                name.toLowerCase().contains('cash') ||
                                        name.toLowerCase().contains('tunai')
                                    ? Icons.payments_rounded
                                    : Icons.account_balance_wallet_rounded,
                                size: 16,
                                color: const Color(0xFF10B981),
                              ),
                              const SizedBox(width: 8),
                              Text(name),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedPaymentModeId = val;
                        });
                      },
                    ),
                    const SizedBox(height: 14),

                    // Catatan / Keperluan Field
                    const Text(
                      'Catatan / Keperluan',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _catatanController,
                      maxLines: 2,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF1E293B),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Opsional: Berikan catatan kas masuk',
                        hintStyle: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFCBD5E1),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFCBD5E1),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFF10B981),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    // Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 11,
                            ),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            foregroundColor: const Color(0xFF475569),
                          ),
                          child: const Text(
                            'Batal',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF10B981), Color(0xFF059669)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x4010B981),
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
                            icon: _isSubmitting
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.check_circle_rounded,
                                    size: 16,
                                  ),
                            label: Text(
                              _isSubmitting
                                  ? 'Menyimpan...'
                                  : 'Simpan Kas Masuk',
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
