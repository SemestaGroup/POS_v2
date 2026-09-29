import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../sync/pos_v2_runtime_session_store.dart';
import 'database_service.dart';
import 'v2_sqlite_schema.dart';

class DatabaseBackupException implements Exception {
  const DatabaseBackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BackupTenantInfo {
  const BackupTenantInfo({
    required this.tenantKey,
    this.tenantName,
    this.tenantCode,
    this.locationId,
  });

  final String tenantKey;
  final String? tenantName;
  final String? tenantCode;
  final String? locationId;

  String get label {
    final name = (tenantName ?? '').trim();
    if (name.isNotEmpty) return name;
    final code = (tenantCode ?? '').trim();
    return code.isNotEmpty ? code : tenantKey;
  }
}

/// What a candidate backup file contains, read without touching live data.
class BackupInspection {
  const BackupInspection({
    required this.path,
    required this.fileSizeBytes,
    required this.schemaVersion,
    required this.tenants,
    required this.orderCount,
    required this.pendingSyncCount,
    required this.latestOrderAt,
  });

  final String path;
  final int fileSizeBytes;
  final int schemaVersion;
  final List<BackupTenantInfo> tenants;
  final int orderCount;
  final int pendingSyncCount;
  final String? latestOrderAt;
}

/// State of the live database that decides whether a restore is safe.
class LocalDataStatus {
  const LocalDataStatus({
    required this.openShiftCount,
    required this.pendingSyncCount,
  });

  final int openShiftCount;
  final int pendingSyncCount;
}

class DatabaseBackupService {
  DatabaseBackupService({
    DatabaseService? databaseService,
    Future<Directory> Function()? temporaryDirectory,
    Future<Directory> Function()? documentsDirectory,
  }) : _databaseService = databaseService ?? DatabaseService.instance,
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory;

  static final DatabaseBackupService instance = DatabaseBackupService();

  static const int emergencyBackupRetention = 5;
  static const String _emergencyDirName = 'emergency_backups';
  static const String _sqliteHeader = 'SQLite format 3';

  final DatabaseService _databaseService;
  final Future<Directory> Function() _temporaryDirectory;
  final Future<Directory> Function() _documentsDirectory;

  /// Writes a consistent copy of the live database to a temp file and returns
  /// it. Login tokens are cleared from the copy, never from the live database.
  Future<File> createBackup() async {
    final tenantLabel = await _currentTenantLabel();
    final stamp = _timestamp(DateTime.now());
    final tempDir = await _temporaryDirectory();
    final target = File(
      p.join(tempDir.path, 'flinkpos_backup_${tenantLabel}_$stamp.db'),
    );
    if (await target.exists()) {
      await target.delete();
    }

    await _databaseService.runExclusive((livePath) async {
      await File(livePath).copy(target.path);
    });

    final copy = await openDatabase(target.path, singleInstance: false);
    try {
      await copy.execute(
        'UPDATE app_session SET auth_token = NULL, refresh_token = NULL',
      );
    } finally {
      await copy.close();
    }
    return target;
  }

  Future<BackupInspection> inspect(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw const DatabaseBackupException('File backup tidak ditemukan.');
    }
    if (!await _hasSqliteHeader(file)) {
      throw const DatabaseBackupException(
        'File yang dipilih bukan backup FlinkPOS yang valid.',
      );
    }

    Database? candidate;
    try {
      candidate = await openDatabase(
        path,
        readOnly: true,
        singleInstance: false,
      );

      final schemaVersion =
          Sqflite.firstIntValue(
            await candidate.rawQuery('PRAGMA user_version'),
          ) ??
          0;

      final integrity = await candidate.rawQuery('PRAGMA quick_check');
      if (integrity.isEmpty || integrity.first.values.first != 'ok') {
        throw const DatabaseBackupException(
          'File backup rusak dan tidak dapat dipulihkan.',
        );
      }

      final tenantRows = await candidate.rawQuery(
        'SELECT tenant_key, tenant_name, tenant_code, location_id FROM app_tenant',
      );
      final tenants = tenantRows
          .map(
            (row) => BackupTenantInfo(
              tenantKey: row['tenant_key']?.toString() ?? '',
              tenantName: row['tenant_name']?.toString(),
              tenantCode: row['tenant_code']?.toString(),
              locationId: row['location_id']?.toString(),
            ),
          )
          .where((tenant) => tenant.tenantKey.isNotEmpty)
          .toList(growable: false);

      return BackupInspection(
        path: path,
        fileSizeBytes: await file.length(),
        schemaVersion: schemaVersion,
        tenants: tenants,
        orderCount: await _count(candidate, 'SELECT COUNT(*) FROM pos_order'),
        pendingSyncCount: await _count(candidate, _pendingSyncSql),
        latestOrderAt: await _scalarString(
          candidate,
          'SELECT MAX(COALESCE(updated_at, created_at)) FROM pos_order',
        ),
      );
    } on DatabaseBackupException {
      rethrow;
    } catch (_) {
      throw const DatabaseBackupException(
        'File yang dipilih bukan backup FlinkPOS yang valid.',
      );
    } finally {
      await candidate?.close();
    }
  }

  /// Returns why [inspection] cannot be restored here, or null when it can.
  String? blockingReason(BackupInspection inspection) {
    if (inspection.schemaVersion > V2SqliteSchema.version) {
      return 'Backup dibuat oleh versi aplikasi yang lebih baru '
          '(skema ${inspection.schemaVersion}, aplikasi ini '
          '${V2SqliteSchema.version}). Perbarui aplikasi terlebih dahulu.';
    }
    if (inspection.tenants.isEmpty) {
      return 'Backup tidak berisi data outlet.';
    }
    final session = PosV2RuntimeSessionStore.instance.currentSession;
    if (session != null &&
        !inspection.tenants.any((t) => t.tenantKey == session.tenantKey)) {
      final owner = inspection.tenants.map((t) => t.label).join(', ');
      return 'Backup ini milik outlet lain ($owner), bukan outlet '
          '${session.tenantName ?? session.tenantKey}.';
    }
    return null;
  }

  Future<LocalDataStatus> currentLocalStatus() async {
    final shifts = await _databaseService.rawQuery(
      "SELECT COUNT(*) AS c FROM shift_session "
      "WHERE status = 'open' AND closed_at IS NULL",
    );
    final pending = await _databaseService.rawQuery(_pendingSyncSql);
    return LocalDataStatus(
      openShiftCount: _asInt(shifts.first['c']),
      pendingSyncCount: _asInt(pending.first.values.first),
    );
  }

  /// Replaces the live database with [inspection]'s file. The current data is
  /// kept as an emergency backup and put back if the restored file fails to
  /// open, migrate or pass an integrity check.
  Future<void> restore(BackupInspection inspection) async {
    final reason = blockingReason(inspection);
    if (reason != null) {
      throw DatabaseBackupException(reason);
    }

    final emergency = await _emergencyFile();
    await _swapDatabaseFile(
      emergencyCopy: emergency,
      replacement: File(inspection.path),
    );

    try {
      final db = await _databaseService.database;
      final check = await db.rawQuery('PRAGMA quick_check');
      if (check.isEmpty || check.first.values.first != 'ok') {
        throw const DatabaseBackupException(
          'Integritas data hasil restore gagal.',
        );
      }
      // Tokens do not survive a restore: the operator signs in again so the
      // restored data is never paired with a stale server session.
      await db.execute(
        "UPDATE app_session SET status = 'logged_out', auth_token = NULL, "
        "refresh_token = NULL WHERE status = 'active'",
      );
      PosV2RuntimeSessionStore.instance.setSession(null);
    } catch (error) {
      await _swapDatabaseFile(emergencyCopy: null, replacement: emergency);
      await _databaseService.database;
      PosV2RuntimeSessionStore.instance.setSession(null);
      throw DatabaseBackupException(
        'Restore gagal dan data semula sudah dikembalikan. '
        '(${error.toString().replaceFirst('Exception: ', '')})',
      );
    }
    await _pruneEmergencyBackups();
  }

  Future<void> _swapDatabaseFile({
    required File? emergencyCopy,
    required File replacement,
  }) {
    return _databaseService.runExclusive((livePath) async {
      if (emergencyCopy != null) {
        await File(livePath).copy(emergencyCopy.path);
      }
      final staging = File('$livePath.restoring');
      if (await staging.exists()) {
        await staging.delete();
      }
      await replacement.copy(staging.path);
      for (final suffix in const ['-wal', '-shm', '-journal']) {
        final sidecar = File('$livePath$suffix');
        if (await sidecar.exists()) {
          await sidecar.delete();
        }
      }
      await staging.rename(livePath);
    });
  }

  Future<File> _emergencyFile() async {
    final dir = await _emergencyDir();
    return File(
      p.join(dir.path, 'pre_restore_${_timestamp(DateTime.now())}.db'),
    );
  }

  Future<Directory> _emergencyDir() async {
    final base = await _documentsDirectory();
    return Directory(
      p.join(base.path, _emergencyDirName),
    ).create(recursive: true);
  }

  Future<void> _pruneEmergencyBackups() async {
    final dir = await _emergencyDir();
    final files = await dir
        .list()
        .where((e) => e is File && e.path.endsWith('.db'))
        .cast<File>()
        .toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    for (final stale in files.skip(emergencyBackupRetention)) {
      await stale.delete();
    }
  }

  Future<String> _currentTenantLabel() async {
    final session = PosV2RuntimeSessionStore.instance.currentSession;
    final raw = session?.tenantCode ?? session?.tenantName ?? 'pos';
    final safe = raw.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    return safe.isEmpty ? 'pos' : safe;
  }

  static const String _pendingSyncSql =
      "SELECT COUNT(*) FROM sync_queue "
      "WHERE status IN ('pending', 'failed', 'deferred', 'syncing')";

  Future<bool> _hasSqliteHeader(File file) async {
    final raf = await file.open();
    try {
      final head = await raf.read(_sqliteHeader.length);
      return String.fromCharCodes(head) == _sqliteHeader;
    } finally {
      await raf.close();
    }
  }

  Future<int> _count(Database db, String sql) async {
    try {
      return Sqflite.firstIntValue(await db.rawQuery(sql)) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<String?> _scalarString(Database db, String sql) async {
    try {
      final rows = await db.rawQuery(sql);
      final value = rows.isEmpty ? null : rows.first.values.first;
      final text = value?.toString();
      return (text == null || text.isEmpty) ? null : text;
    } catch (_) {
      return null;
    }
  }

  int _asInt(Object? value) =>
      value is int ? value : int.tryParse('$value') ?? 0;

  String _timestamp(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}${two(t.month)}${two(t.day)}_'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}';
  }
}
