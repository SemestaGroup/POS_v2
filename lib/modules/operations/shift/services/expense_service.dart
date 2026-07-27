import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../widgets/kas_keluar_dialog.dart';

class ExpenseService {
  final String baseUrl;
  final String authToken;

  ExpenseService({
    required this.baseUrl,
    required this.authToken,
  });

  /// 1. Fetch payment modes from /api/v2/pos-payment-modes
  Future<List<Map<String, dynamic>>> getPaymentModes() async {
    final normalizedBase = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    final uri = Uri.parse('${normalizedBase}api/v2/pos-payment-modes');

    try {
      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          if (authToken.trim().isNotEmpty) 'authtoken': authToken.trim(),
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['data'] is List) {
          return List<Map<String, dynamic>>.from(decoded['data']);
        } else if (decoded is List) {
          return List<Map<String, dynamic>>.from(decoded);
        }
      }
    } catch (_) {}
    return [];
  }

  /// 2. Get Cash Payment Mode ID automatically
  Future<dynamic> getDefaultCashPaymentModeId() async {
    try {
      final modes = await getPaymentModes();
      for (final mode in modes) {
        final name = (mode['name'] ?? mode['payment_name'] ?? mode['title'] ?? '').toString().toLowerCase();
        final code = (mode['code'] ?? '').toString().toLowerCase();
        if (name.contains('cash') || name.contains('tunai') || code.contains('cash')) {
          return mode['id'] ?? mode['remote_id'] ?? mode['payment_mode_id'];
        }
      }
      if (modes.isNotEmpty) {
        return modes.first['id'] ?? modes.first['remote_id'];
      }
    } catch (_) {}
    return 1; // Default fallback ID if not found
  }

  /// 3. Submit Kas Keluar (POST /api/expenses)
  Future<Map<String, dynamic>> postExpense({
    required KasKeluarInputData inputData,
    dynamic paymentModeId,
  }) async {
    final effectivePaymentModeId = paymentModeId ?? await getDefaultCashPaymentModeId();
    final dateStr = DateFormat('yyyy-MM-dd').format(inputData.tanggal);

    final payload = {
      'expense_name': inputData.nama,
      'note': inputData.catatan,
      'category': 1, // Mandatory 1
      'amount': inputData.amount,
      'date': dateStr, // Default YYYY-MM-DD
      'currency': 3, // Mandatory 3
      'paymentmode': effectivePaymentModeId,
    };

    final normalizedBase = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    final uri = Uri.parse('${normalizedBase}api/expenses');

    final response = await http.post(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (authToken.trim().isNotEmpty) 'authtoken': authToken.trim(),
      },
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200 || response.statusCode == 201) {
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : {'status': 'success', 'data': decoded};
    } else {
      throw Exception('Gagal mencatat kas keluar (${response.statusCode}): ${response.body}');
    }
  }
}
