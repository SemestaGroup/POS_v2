import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'v2_sqlite_schema.dart';

class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  Database? _database;

  Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError(
        'SQLite source of truth is not enabled for web builds yet.',
      );
    }

    final current = _database;
    if (current != null && current.isOpen) {
      return current;
    }

    _database = await _openDatabase();
    return _database!;
  }

  Future<Database> _openDatabase() async {
    final path = join(
      await getDatabasesPath(),
      'flinkpos_v2_source_of_truth.db',
    );

    return openDatabase(
      path,
      version: V2SqliteSchema.version,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) => _applySchema(db),
      onUpgrade: (db, oldVersion, newVersion) async {
        await _upgradeSchema(db, oldVersion, newVersion);
        await _applySchema(db);
      },
    );
  }

  Future<void> _upgradeSchema(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await _addColumnIfMissing(db, 'device_session', 'register_id', 'TEXT');
      await _addColumnIfMissing(db, 'shift_session', 'register_id', 'TEXT');
      await _addColumnIfMissing(db, 'app_session', 'register_id', 'TEXT');
      await _addColumnIfMissing(db, 'pos_order', 'location_id', 'TEXT');
      await _addColumnIfMissing(db, 'pos_order', 'register_id', 'TEXT');
      await _addColumnIfMissing(db, 'approval_request', 'register_id', 'TEXT');
    }
    if (oldVersion < 3) {
      // printer_device table will be created by schema application
    }
    if (oldVersion < 4) {
      // pos_role table will be created by schema application
    }
    if (oldVersion < 5) {
      await _addColumnIfMissing(db, 'shift_session', 'eod_group_id', 'TEXT');
      // shift_eod_archive will be created by schema application
    }
    if (oldVersion < 6) {
      // pos_cash_flow table will be created by schema application
    }
    if (oldVersion < 8) {
      await _addColumnIfMissing(db, 'pos_cash_flow', 'shift_session_id', 'INTEGER');
    }
    if (oldVersion < 11) {
      await _addColumnIfMissing(db, 'marketplace_item', 'sku_code', 'TEXT');
      await _addColumnIfMissing(db, 'marketplace_item', 'image_url', 'TEXT');
      await _addColumnIfMissing(db, 'marketplace_item', 'can_be_inventory', 'TEXT');
      await _addColumnIfMissing(db, 'marketplace_item', 'images_json', 'TEXT');
    }
    if (oldVersion < 12) {
      await _addColumnIfMissing(
        db,
        'purchase_order_request',
        'purchase_order_id',
        'INTEGER',
      );
      await _addColumnIfMissing(
        db,
        'purchase_order_request',
        'unit_cost_amount',
        'INTEGER NOT NULL DEFAULT 0',
      );
      // Rebuild the table to relax product_id (NOT NULL + FK to product)
      // so marketplace items without a local product can still be ordered.
      await _rebuildPurchaseOrderRequestTable(db);
      // purchase_order table will be created by schema application
    }
  }

  Future<void> _rebuildPurchaseOrderRequestTable(Database db) async {
    final tableExists = await _tableExists(db, 'purchase_order_request');
    if (!tableExists) {
      return;
    }
    await db.execute(
      'ALTER TABLE purchase_order_request RENAME TO purchase_order_request_v11',
    );
    await db.execute('''
CREATE TABLE IF NOT EXISTS purchase_order_request (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tenant_id INTEGER NOT NULL,
  purchase_order_id INTEGER,
  product_id INTEGER,
  product_remote_id TEXT,
  product_name TEXT,
  product_sku TEXT,
  quantity REAL NOT NULL DEFAULT 0,
  unit_cost_amount INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending',
  sync_state TEXT NOT NULL DEFAULT 'dirty',
  last_synced_at TEXT,
  created_at TEXT,
  updated_at TEXT,
  deleted_at TEXT,
  FOREIGN KEY (tenant_id) REFERENCES app_tenant(id) ON DELETE CASCADE,
  FOREIGN KEY (purchase_order_id) REFERENCES purchase_order(id) ON DELETE CASCADE
)
''');
    await db.execute('''
INSERT INTO purchase_order_request (
  id, tenant_id, purchase_order_id, product_id, product_remote_id,
  product_name, product_sku, quantity, unit_cost_amount, status,
  sync_state, last_synced_at, created_at, updated_at, deleted_at
)
SELECT
  id, tenant_id, NULL, product_id, product_remote_id,
  product_name, product_sku, quantity, 0, status,
  sync_state, last_synced_at, created_at, updated_at, deleted_at
FROM purchase_order_request_v11
''');
    await db.execute('DROP TABLE purchase_order_request_v11');
  }

  Future<bool> _tableExists(Database db, String table) async {
    final rows = await db.rawQuery(
      'SELECT name FROM sqlite_master WHERE type = ? AND name = ?',
      <Object?>['table', table],
    );
    return rows.isNotEmpty;
  }

  Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    if (rows.isEmpty) {
      return;
    }

    final exists = rows.any((row) => row['name']?.toString() == column);
    if (exists) {
      return;
    }

    await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
  }

  Future<void> _applySchema(DatabaseExecutor executor) async {
    for (final statement in V2SqliteSchema.createStatements) {
      await executor.execute(statement);
    }
  }

  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return db.transaction(action);
  }

  Future<int?> findLocalId(
    DatabaseExecutor executor,
    String table, {
    required String where,
    required List<Object?> whereArgs,
    String idColumn = 'id',
  }) async {
    final rows = await executor.query(
      table,
      columns: <String>[idColumn],
      where: where,
      whereArgs: whereArgs,
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    final value = rows.first[idColumn];
    if (value is int) {
      return value;
    }
    return int.tryParse(value.toString());
  }

  Future<int> upsertByUnique(
    DatabaseExecutor executor,
    String table, {
    required String where,
    required List<Object?> whereArgs,
    required Map<String, Object?> insertValues,
    required Map<String, Object?> updateValues,
    String idColumn = 'id',
  }) async {
    final existingId = await findLocalId(
      executor,
      table,
      where: where,
      whereArgs: whereArgs,
      idColumn: idColumn,
    );

    if (existingId != null) {
      await executor.update(
        table,
        updateValues,
        where: '$idColumn = ?',
        whereArgs: <Object?>[existingId],
      );
      return existingId;
    }

    return executor.insert(table, insertValues);
  }

  Future<void> replaceChildren(
    DatabaseExecutor executor,
    String table, {
    required String where,
    required List<Object?> whereArgs,
    required List<Map<String, Object?>> rows,
  }) async {
    await executor.delete(table, where: where, whereArgs: whereArgs);
    for (final row in rows) {
      await executor.insert(
        table,
        row,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> close() async {
    final db = _database;
    _database = null;
    await db?.close();
  }

  Future<void> resetDatabase() async {
    final db = await database;
    await db.execute('PRAGMA foreign_keys = OFF');
    try {
      final tableRows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
      );
      final tableNames = tableRows
          .map((row) => row['name']?.toString())
          .whereType<String>()
          .where((name) => name.isNotEmpty)
          .toList(growable: false);

      for (final tableName in tableNames) {
        await db.delete(tableName);
      }

      await db.execute("DELETE FROM sqlite_sequence");
    } finally {
      await db.execute('PRAGMA foreign_keys = ON');
    }
  }

  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    final db = await database;
    final rows = await db.rawQuery(sql, arguments);
    return rows
        .map((row) => row.map((key, value) => MapEntry(key, value)))
        .toList(growable: false);
  }

  Future<int> rawInsert(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    final db = await database;
    return db.rawInsert(sql, arguments);
  }

  Future<List<Map<String, Object?>>> query(
    String table, {
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    final db = await database;
    final rows = await db.query(
      table,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
    );
    return rows
        .map((row) => row.map((key, value) => MapEntry(key, value)))
        .toList(growable: false);
  }
}
