import 'package:flutter/foundation.dart';

import '../../../core/services/local/database_service.dart';
import '../../../core/services/sync/pos_v2_runtime_session_store.dart';

class MasterDataListSnapshot<T> {
  const MasterDataListSnapshot({
    required this.isLoading,
    required this.records,
    this.errorMessage,
    this.session,
  });

  final bool isLoading;
  final List<T> records;
  final String? errorMessage;
  final PosV2RuntimeSession? session;

  MasterDataListSnapshot<T> copyWith({
    bool? isLoading,
    List<T>? records,
    String? errorMessage,
    bool clearError = false,
    PosV2RuntimeSession? session,
  }) {
    return MasterDataListSnapshot<T>(
      isLoading: isLoading ?? this.isLoading,
      records: records ?? this.records,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      session: session ?? this.session,
    );
  }
}

abstract class _BaseMasterDataStore<T> {
  _BaseMasterDataStore() {
    PosV2RuntimeSessionStore.instance.sessionNotifier.addListener(_onSessionChanged);
  }

  final ValueNotifier<MasterDataListSnapshot<T>> snapshotNotifier =
      ValueNotifier<MasterDataListSnapshot<T>>(
    MasterDataListSnapshot<T>(
      isLoading: false,
      records: <T>[],
    ),
  );

  void _onSessionChanged() {
    refresh(silent: true);
  }

  Future<void> refresh({bool silent = false}) async {
    final session = PosV2RuntimeSessionStore.instance.currentSession ??
        await PosV2RuntimeSessionStore.instance.restoreFromDatabase();

    if (!silent) {
      snapshotNotifier.value = snapshotNotifier.value.copyWith(
        isLoading: true,
        session: session,
        clearError: true,
      );
    }

    if (session == null) {
      snapshotNotifier.value = MasterDataListSnapshot<T>(
        isLoading: false,
        records: <T>[],
        errorMessage: 'No active session found.',
        session: null,
      );
      return;
    }

    try {
      final records = await loadRecords(session);
      snapshotNotifier.value = snapshotNotifier.value.copyWith(
        isLoading: false,
        session: session,
        records: records,
        clearError: true,
      );
    } catch (error) {
      snapshotNotifier.value = snapshotNotifier.value.copyWith(
        isLoading: false,
        session: session,
        errorMessage: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<List<T>> loadRecords(PosV2RuntimeSession session);
}

class ProductListRecord {
  const ProductListRecord({
    required this.id,
    required this.name,
    required this.sku,
    required this.categoryName,
    required this.priceAmount,
    required this.stock,
    required this.status,
    required this.isAvailable,
    this.imageUrl,
  });

  final int id;
  final String name;
  final String sku;
  final String categoryName;
  final int priceAmount;
  final int stock;
  final String status;
  final bool isAvailable;
  final String? imageUrl;
}

class CategoryListRecord {
  const CategoryListRecord({
    required this.id,
    required this.name,
    required this.productCount,
    this.brandName,
    this.code,
  });

  final int id;
  final String name;
  final String? brandName;
  final String? code;
  final int productCount;
}

class BrandListRecord {
  const BrandListRecord({
    required this.id,
    required this.name,
    required this.displayFlag,
    this.code,
  });

  final int id;
  final String name;
  final String? code;
  final bool displayFlag;
}

class PromoListRecord {
  const PromoListRecord({
    required this.id,
    required this.name,
    this.promoType,
    this.description,
    this.startAt,
    this.endAt,
    this.status,
  });

  final int id;
  final String name;
  final String? promoType;
  final String? description;
  final DateTime? startAt;
  final DateTime? endAt;
  final String? status;
}

class StaffListRecord {
  const StaffListRecord({
    required this.id,
    required this.fullName,
    required this.isActive,
    this.roleName,
    this.roleCode,
    this.email,
    this.phoneNumber,
    this.lastLoginAt,
  });

  final int id;
  final String fullName;
  final String? roleName;
  final String? roleCode;
  final String? email;
  final String? phoneNumber;
  final bool isActive;
  final DateTime? lastLoginAt;
}

class CustomerListRecord {
  const CustomerListRecord({
    required this.id,
    required this.displayName,
    required this.pointsBalance,
    this.phoneNumber,
    this.email,
    this.city,
  });

  final int id;
  final String displayName;
  final String? phoneNumber;
  final String? email;
  final String? city;
  final int pointsBalance;
}

class ProductListStore extends _BaseMasterDataStore<ProductListRecord> {
  ProductListStore._();

  static final ProductListStore instance = ProductListStore._();

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  int? _categoryId;
  int? get categoryId => _categoryId;

  int? _brandId;
  int? get brandId => _brandId;

  void setSearchQuery(String query) {
    if (_searchQuery != query) {
      _searchQuery = query;
      refresh();
    }
  }

  void setFilter({int? categoryId, int? brandId, bool clearBrand = false, bool clearCategory = false}) {
    bool changed = false;
    if (clearCategory) {
      if (_categoryId != null) changed = true;
      _categoryId = null;
    } else if (categoryId != null && _categoryId != categoryId) {
      _categoryId = categoryId;
      changed = true;
    }

    if (clearBrand) {
      if (_brandId != null) changed = true;
      _brandId = null;
    } else if (brandId != null && _brandId != brandId) {
      _brandId = brandId;
      changed = true;
    }

    if (changed) {
      refresh();
    }
  }

  @override
  Future<List<ProductListRecord>> loadRecords(PosV2RuntimeSession session) async {
    final tenantId = session.tenantId;
    String query = '''
      SELECT p.id, p.name, p.sku, p.price_amount,
             p.stock_quantity, p.status, p.image_url,
             p.is_available, c.name as category_name
      FROM product p
      LEFT JOIN category c ON c.id = p.category_id
      WHERE p.tenant_id = ?
        AND p.deleted_at IS NULL
    ''';
    List<Object?> args = [tenantId];

    if (_searchQuery.isNotEmpty) {
      query += ' AND (p.name LIKE ? OR p.sku LIKE ?)';
      args.add('%$_searchQuery%');
      args.add('%$_searchQuery%');
    }

    if (_categoryId != null) {
      query += ' AND p.category_id = ?';
      args.add(_categoryId);
    }

    if (_brandId != null) {
      query += ' AND p.brand_id = ?';
      args.add(_brandId);
    }

    query += ' ORDER BY p.name ASC LIMIT 200';

    final rows = await DatabaseService.instance.rawQuery(query, args);

    return rows
        .map(
          (r) => ProductListRecord(
            id: _asInt(r['id']) ?? 0,
            name: r['name']?.toString() ?? '-',
            sku: r['sku']?.toString() ?? '',
            categoryName: r['category_name']?.toString() ?? '—',
            priceAmount: _asInt(r['price_amount']) ?? 0,
            stock: _asDouble(r['stock_quantity']).round(),
            status: r['status']?.toString() ?? 'active',
            imageUrl: r['image_url']?.toString(),
            isAvailable: _isTruthyFlag(r['is_available']),
          ),
        )
        .toList(growable: false);
  }
}

class CategoryListStore extends _BaseMasterDataStore<CategoryListRecord> {
  CategoryListStore._();

  static final CategoryListStore instance = CategoryListStore._();

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  void setSearchQuery(String query) {
    if (_searchQuery != query) {
      _searchQuery = query;
      refresh();
    }
  }

  @override
  Future<List<CategoryListRecord>> loadRecords(PosV2RuntimeSession session) async {
    final tenantId = session.tenantId;
    String query = '''
      SELECT c.id, c.name, c.brand_name, c.code,
             COUNT(p.id) as product_count
      FROM category c
      LEFT JOIN product p ON p.category_id = c.id
          AND p.deleted_at IS NULL AND p.status = 'active'
      WHERE c.tenant_id = ?
        AND c.deleted_at IS NULL
    ''';
    List<Object?> args = [tenantId];

    if (_searchQuery.isNotEmpty) {
      query += ' AND (c.name LIKE ? OR c.brand_name LIKE ? OR c.code LIKE ?)';
      args.add('%$_searchQuery%');
      args.add('%$_searchQuery%');
      args.add('%$_searchQuery%');
    }

    query += ' GROUP BY c.id, c.name, c.brand_name, c.code ORDER BY c.name ASC LIMIT 200';

    final rows = await DatabaseService.instance.rawQuery(query, args);

    return rows
        .map(
          (r) => CategoryListRecord(
            id: _asInt(r['id']) ?? 0,
            name: r['name']?.toString() ?? '-',
            brandName: r['brand_name']?.toString(),
            code: r['code']?.toString(),
            productCount: _asInt(r['product_count']) ?? 0,
          ),
        )
        .toList(growable: false);
  }
}

class BrandListStore extends _BaseMasterDataStore<BrandListRecord> {
  BrandListStore._();

  static final BrandListStore instance = BrandListStore._();

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  void setSearchQuery(String query) {
    if (_searchQuery != query) {
      _searchQuery = query;
      refresh();
    }
  }

  @override
  Future<List<BrandListRecord>> loadRecords(PosV2RuntimeSession session) async {
    final tenantId = session.tenantId;
    String query = '''
      SELECT id, name, code, display_flag
      FROM brand
      WHERE tenant_id = ?
        AND deleted_at IS NULL
    ''';
    List<Object?> args = [tenantId];

    if (_searchQuery.isNotEmpty) {
      query += ' AND (name LIKE ? OR code LIKE ?)';
      args.add('%$_searchQuery%');
      args.add('%$_searchQuery%');
    }

    query += ' ORDER BY sort_order ASC, name ASC LIMIT 200';

    final rows = await DatabaseService.instance.rawQuery(query, args);

    return rows
        .map(
          (r) => BrandListRecord(
            id: _asInt(r['id']) ?? 0,
            name: r['name']?.toString() ?? '-',
            code: r['code']?.toString(),
            displayFlag: _isTruthyFlag(r['display_flag']),
          ),
        )
        .toList(growable: false);
  }
}

class PromoListStore extends _BaseMasterDataStore<PromoListRecord> {
  PromoListStore._();

  static final PromoListStore instance = PromoListStore._();

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  void setSearchQuery(String query) {
    if (_searchQuery != query) {
      _searchQuery = query;
      refresh();
    }
  }

  @override
  Future<List<PromoListRecord>> loadRecords(PosV2RuntimeSession session) async {
    final tenantId = session.tenantId;
    final locationId = session.locationId;
    
    String query = '''
      SELECT p.id, p.name, p.promo_type, p.description, p.start_at, p.end_at, p.status
      FROM promotion p
      INNER JOIN promotion_location pl ON pl.promotion_id = p.id
      WHERE p.tenant_id = ? AND pl.location_id = ?
        AND p.deleted_at IS NULL
    ''';
    List<Object?> args = [tenantId, locationId];

    if (_searchQuery.isNotEmpty) {
      query += ' AND p.name LIKE ?';
      args.add('%$_searchQuery%');
    }

    query += ' ORDER BY p.start_at DESC, p.name ASC LIMIT 200';

    final rows = await DatabaseService.instance.rawQuery(query, args);

    return rows
        .map(
          (r) => PromoListRecord(
            id: _asInt(r['id']) ?? 0,
            name: r['name']?.toString() ?? 'Promo',
            promoType: r['promo_type']?.toString(),
            description: r['description']?.toString(),
            startAt: _parseDateTime(r['start_at']),
            endAt: _parseDateTime(r['end_at']),
            status: r['status']?.toString(),
          ),
        )
        .toList(growable: false);
  }
}

class StaffListStore extends _BaseMasterDataStore<StaffListRecord> {
  StaffListStore._();

  static final StaffListStore instance = StaffListStore._();

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  String? _roleCode;
  String? get roleCode => _roleCode;

  void setSearchQuery(String query) {
    if (_searchQuery != query) {
      _searchQuery = query;
      refresh();
    }
  }

  void setRoleCode(String? code) {
    if (_roleCode != code) {
      _roleCode = code;
      refresh();
    }
  }

  @override
  Future<List<StaffListRecord>> loadRecords(PosV2RuntimeSession session) async {
    final tenantId = session.tenantId;
    
    String query = '''
      SELECT id, full_name, role_name, role_code, email, phone_number, is_active, last_login_at
      FROM staff
      WHERE tenant_id = ?
        AND deleted_at IS NULL
    ''';
    List<Object?> args = [tenantId];

    if (_searchQuery.isNotEmpty) {
      query += ' AND (full_name LIKE ? OR email LIKE ? OR phone_number LIKE ?)';
      args.add('%$_searchQuery%');
      args.add('%$_searchQuery%');
      args.add('%$_searchQuery%');
    }

    if (_roleCode != null) {
      query += ' AND role_code = ?';
      args.add(_roleCode);
    }

    query += ' ORDER BY is_active DESC, full_name ASC LIMIT 200';

    final rows = await DatabaseService.instance.rawQuery(query, args);

    return rows
        .map(
          (r) => StaffListRecord(
            id: _asInt(r['id']) ?? 0,
            fullName: r['full_name']?.toString() ?? 'Staff',
            roleName: r['role_name']?.toString(),
            roleCode: r['role_code']?.toString(),
            email: r['email']?.toString(),
            phoneNumber: r['phone_number']?.toString(),
            isActive: _isTruthyFlag(r['is_active']),
            lastLoginAt: _parseDateTime(r['last_login_at']),
          ),
        )
        .toList(growable: false);
  }
}

class CustomerListStore extends _BaseMasterDataStore<CustomerListRecord> {
  CustomerListStore._();

  static final CustomerListStore instance = CustomerListStore._();

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  void setSearchQuery(String query) {
    if (_searchQuery != query) {
      _searchQuery = query;
      refresh();
    }
  }

  @override
  Future<List<CustomerListRecord>> loadRecords(PosV2RuntimeSession session) async {
    final tenantId = session.tenantId;
    
    String query = '''
      SELECT id, display_name, phone_number, email, city, points_balance
      FROM customer
      WHERE tenant_id = ?
        AND deleted_at IS NULL
    ''';
    List<Object?> args = [tenantId];

    if (_searchQuery.isNotEmpty) {
      query += ' AND (display_name LIKE ? OR phone_number LIKE ? OR email LIKE ?)';
      args.add('%$_searchQuery%');
      args.add('%$_searchQuery%');
      args.add('%$_searchQuery%');
    }

    query += ' ORDER BY display_name ASC LIMIT 200';

    final rows = await DatabaseService.instance.rawQuery(query, args);


    return rows
        .map(
          (r) => CustomerListRecord(
            id: _asInt(r['id']) ?? 0,
            displayName: r['display_name']?.toString() ?? 'Customer',
            phoneNumber: r['phone_number']?.toString(),
            email: r['email']?.toString(),
            city: r['city']?.toString(),
            pointsBalance: _asInt(r['points_balance']) ?? 0,
          ),
        )
        .toList(growable: false);
  }
}

int? _asInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(value.toString().split('.').first);
}

double _asDouble(Object? value) {
  if (value == null) return 0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

bool _isTruthyFlag(Object? value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is int) return value == 1;
  final normalized = value.toString().trim().toLowerCase();
  return normalized == '1' || normalized == 'true' || normalized == 'yes';
}

DateTime? _parseDateTime(Object? raw) {
  final text = raw?.toString();
  if (text == null || text.isEmpty) {
    return null;
  }

  return DateTime.tryParse(text.replaceFirst(' ', 'T'));
}
