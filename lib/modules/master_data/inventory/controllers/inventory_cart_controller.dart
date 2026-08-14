import 'package:flutter/foundation.dart';

import '../models/marketplace_item.dart';
import '../stores/inventory_read_stores.dart';

class InventoryCartController extends ChangeNotifier {
  final Map<String, int> _cartQty = <String, int>{};
  final Map<String, CartEntry> _cartEntries = <String, CartEntry>{};
  bool _submitting = false;

  Map<String, int> get cartQty => Map.unmodifiable(_cartQty);
  Map<String, CartEntry> get cartEntries => Map.unmodifiable(_cartEntries);
  bool get submitting => _submitting;
  bool get isEmpty => _cartQty.isEmpty;

  int get totalQty => _cartQty.values.fold(0, (sum, v) => sum + v);

  int get totalAmount {
    var total = 0;
    _cartQty.forEach((key, qty) {
      total += (_cartEntries[key]?.unitCost ?? 0) * qty;
    });
    return total;
  }

  int qtyFor(String key) => _cartQty[key] ?? 0;

  void addToCart(CartEntry entry) {
    _cartEntries[entry.key] = entry;
    _cartQty[entry.key] = (_cartQty[entry.key] ?? 0) + 1;
    notifyListeners();
  }

  void increment(String key) {
    _cartQty[key] = (_cartQty[key] ?? 0) + 1;
    notifyListeners();
  }

  void decrement(String key) {
    final current = _cartQty[key] ?? 0;
    if (current <= 1) {
      _cartQty.remove(key);
      _cartEntries.remove(key);
    } else {
      _cartQty[key] = current - 1;
    }
    notifyListeners();
  }

  void clearCart() {
    _cartQty.clear();
    _cartEntries.clear();
    notifyListeners();
  }

  Future<String> submitOrder() async {
    if (_submitting || _cartQty.isEmpty) {
      throw Exception('Keranjang masih kosong atau sedang diproses.');
    }
    _submitting = true;
    notifyListeners();

    try {
      final lines = <PurchaseOrderInputLine>[
        for (final entry in _cartEntries.entries)
          if ((_cartQty[entry.key] ?? 0) > 0)
            entry.value.toInputLine(_cartQty[entry.key]!),
      ];

      final poCode = await PurchaseOrderRequestStore.instance.createOrder(lines: lines);
      PurchaseOrderRequestStore.instance.refresh();
      PurchaseOrderStore.instance.refresh();

      _cartQty.clear();
      _cartEntries.clear();
      _submitting = false;
      notifyListeners();
      return poCode;
    } catch (e) {
      _submitting = false;
      notifyListeners();
      rethrow;
    }
  }
}
