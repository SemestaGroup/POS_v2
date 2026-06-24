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
      onUpgrade: (db, oldVersion, newVersion) => _applySchema(db),
    );
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

  Future<int?> resolveLatestActiveTenantId() async {
    final rows = await rawQuery('''
      SELECT app_session.tenant_id
      FROM app_session
      WHERE app_session.status = 'active'
      ORDER BY COALESCE(app_session.updated_at, app_session.logged_in_at) DESC
      LIMIT 1
      ''');
    if (rows.isEmpty) {
      return null;
    }
    final value = rows.first['tenant_id'];
    if (value is int) {
      return value;
    }
    return int.tryParse(value.toString());
  }
}
