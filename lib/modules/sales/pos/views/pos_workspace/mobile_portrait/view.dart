import 'package:flutter/material.dart';
import '../../../../../../../l10n/app_localizations.dart';
import '../../../../../../core/services/sync/pos_v2_customer_service.dart';
import '../../../../shared/models/pos_catalog_store.dart';
import 'package:intl/intl.dart';

import '../../../../orders/views/tablet_landscape/view.dart';
import '../../checkout/tablet_landscape/payment_flow_page.dart';

class PosWorkspaceMobileView extends StatefulWidget {
  const PosWorkspaceMobileView({
    super.key,
    this.isReadOnly = false,
  });

  final bool isReadOnly;

  @override
  State<PosWorkspaceMobileView> createState() => _PosWorkspaceMobileViewState();
}

class _PosWorkspaceMobileViewState extends State<PosWorkspaceMobileView> {
  final TextEditingController _searchController = TextEditingController();
  final List<Map<String, dynamic>> _cartItems = []; // {product: Map, qty: int}
  String? _selectedBrandName;
  PosCustomerRecord? _selectedCustomer;
  PosCatalogSnapshot _catalogSnapshot = const PosCatalogSnapshot();

  @override
  void initState() {
    super.initState();
    _catalogSnapshot = PosCatalogStore.instance.snapshotNotifier.value;
    PosCatalogStore.instance.snapshotNotifier.addListener(_handleCatalogChanged);
    _ensureDefaultCustomerSelected();
  }

  @override
  void dispose() {
    PosCatalogStore.instance.snapshotNotifier.removeListener(_handleCatalogChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _handleCatalogChanged() {
    if (mounted) {
      setState(() {
        _catalogSnapshot = PosCatalogStore.instance.snapshotNotifier.value;
      });
    }
  }

  void _ensureDefaultCustomerSelected() {
    _selectedCustomer = PosCustomerRecord(
      localId: null,
      remoteId: '',
      name: PosV2CustomerService.defaultWalkInName,
      phone: '',
      address: '',
      isDefaultWalkIn: true,
    );
  }

  int get _subtotalAmount {
    int total = 0;
    for (final item in _cartItems) {
      final product = item['product'] as Map<String, dynamic>;
      final qty = item['qty'] as int;
      final priceStr = product['discountedPrice'] ?? product['price'] ?? '0';
      total += (int.tryParse(priceStr.toString()) ?? 0) * qty;
    }
    return total;
  }

  int get _totalPay => _subtotalAmount;

  void _addProductToCart(Map<String, dynamic> product) {
    final remoteId = product['remoteId']?.toString();
    setState(() {
      final index = _cartItems.indexWhere(
        (item) => (item['product'] as Map<String, dynamic>)['remoteId']?.toString() == remoteId,
      );
      if (index >= 0) {
        _cartItems[index]['qty'] = (_cartItems[index]['qty'] as int) + 1;
      } else {
        _cartItems.add({'product': product, 'qty': 1});
      }
    });
  }

  void _removeProductFromCart(Map<String, dynamic> product) {
    final remoteId = product['remoteId']?.toString();
    setState(() {
      final index = _cartItems.indexWhere(
        (item) => (item['product'] as Map<String, dynamic>)['remoteId']?.toString() == remoteId,
      );
      if (index >= 0) {
        final qty = _cartItems[index]['qty'] as int;
        if (qty > 1) {
          _cartItems[index]['qty'] = qty - 1;
        } else {
          _cartItems.removeAt(index);
        }
      }
    });
  }

  List<String> _availableBrands(List<Map<String, dynamic>> products) {
    final set = <String>{};
    for (final p in products) {
      final b = p['brandName']?.toString();
      if (b != null && b.trim().isNotEmpty) {
        set.add(b.trim());
      }
    }
    return set.toList()..sort();
  }

  String _formatCurrency(int amount) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    final rawProducts = _catalogSnapshot.products;
    final products = rawProducts.map((p) => Map<String, dynamic>.from(p)).toList();
    final brandNames = _availableBrands(products);

    final query = _searchController.text.trim().toLowerCase();
    final visibleProducts = products.where((product) {
      if (_selectedBrandName != null && product['brandName']?.toString() != _selectedBrandName) {
        return false;
      }
      if (query.isNotEmpty) {
        final name = product['name']?.toString().toLowerCase() ?? '';
        final desc = product['description']?.toString().toLowerCase() ?? '';
        return name.contains(query) || desc.contains(query);
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          children: [
            // Search & Customer Picker
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: l10n.searchProduct,
                          prefixIcon: const Icon(Icons.search_rounded, size: 18),
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      _selectedCustomer?.isDefaultWalkIn == false
                          ? Icons.person_rounded
                          : Icons.person_outline_rounded,
                      color: primaryColor,
                    ),
                    onPressed: () {
                      // Buka customer picker
                    },
                  ),
                ],
              ),
            ),
            // Horizontal Brand Chips
            if (brandNames.isNotEmpty)
              SizedBox(
                height: 38,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: brandNames.length + 1,
                  itemBuilder: (context, index) {
                    final isAll = index == 0;
                    final brand = isAll ? null : brandNames[index - 1];
                    final selected = isAll
                        ? _selectedBrandName == null
                        : _selectedBrandName == brand;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(
                          isAll ? l10n.all : brand!,
                          style: TextStyle(
                            fontSize: 11,
                            color: selected ? Colors.white : Colors.grey.shade700,
                          ),
                        ),
                        selected: selected,
                        onSelected: (val) {
                          setState(() {
                            _selectedBrandName = val ? brand : null;
                          });
                        },
                        selectedColor: primaryColor,
                        backgroundColor: Colors.white,
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
            // Product Grid
            Expanded(
              child: visibleProducts.isEmpty
                  ? Center(
                      child: Text(
                        l10n.catalogEmptySubtitle,
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.82,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: visibleProducts.length,
                      itemBuilder: (context, index) {
                        final product = visibleProducts[index];
                        final remoteId = product['remoteId']?.toString();
                        final cartIdx = _cartItems.indexWhere(
                          (item) => (item['product'] as Map<String, dynamic>)['remoteId']?.toString() == remoteId,
                        );
                        final qty = cartIdx >= 0 ? _cartItems[cartIdx]['qty'] as int : 0;

                        final priceStr = product['discountedPrice'] ?? product['price'] ?? '0';
                        final price = int.tryParse(priceStr.toString()) ?? 0;

                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                  child: Image.network(
                                    product['imageUrl']?.toString() ?? '',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: Colors.grey.shade100,
                                      child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey),
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product['name']?.toString() ?? '',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatCurrency(price),
                                      style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 11),
                                    ),
                                    const SizedBox(height: 6),
                                    if (qty > 0)
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.remove_circle_outline, size: 18),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: () => _removeProductFromCart(product),
                                          ),
                                          Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                          IconButton(
                                            icon: const Icon(Icons.add_circle_outline, size: 18),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: () => _addProductToCart(product),
                                          ),
                                        ],
                                      )
                                    else
                                      SizedBox(
                                        width: double.infinity,
                                        height: 28,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: primaryColor,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: EdgeInsets.zero,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                          ),
                                          onPressed: () => _addProductToCart(product),
                                          child: const Text('Tambah', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            // Bottom Bar Summary
            if (_cartItems.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4)),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${_cartItems.length} Item', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            Text(_formatCurrency(_totalPay), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => _showMobileCartSheet(theme, primaryColor),
                        style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
                        child: const Text('Checkout', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showMobileCartSheet(ThemeData theme, Color primaryColor) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(
                        child: Text('Keranjang Belanja', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: _cartItems.length,
                          itemBuilder: (context, index) {
                            final item = _cartItems[index];
                            final product = item['product'] as Map<String, dynamic>;
                            final qty = item['qty'] as int;
                            final priceStr = product['discountedPrice'] ?? product['price'] ?? '0';
                            final price = int.tryParse(priceStr.toString()) ?? 0;

                            return ListTile(
                              title: Text(product['name']?.toString() ?? '', style: const TextStyle(fontSize: 12)),
                              subtitle: Text(_formatCurrency(price * qty), style: TextStyle(color: primaryColor, fontSize: 11)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove, size: 18),
                                    onPressed: () {
                                      _removeProductFromCart(product);
                                      setSheetState(() {});
                                      setState(() {});
                                    },
                                  ),
                                  Text('$qty'),
                                  IconButton(
                                    icon: const Icon(Icons.add, size: 18),
                                    onPressed: () {
                                      _addProductToCart(product);
                                      setSheetState(() {});
                                      setState(() {});
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Pembayaran', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(_formatCurrency(_totalPay), style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          // Lanjut pembayaran
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
                        child: const Text('Bayar Sekarang', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
