import 'dart:io';

import 'package:flinkpos_v2/core/services/local/database_service.dart';

/// Closes the shared SQLite file and deletes it so a test starts from an empty
/// schema. Windows can hold the file for a few milliseconds after `close()`
/// returns, so deletion is retried instead of failing the test.
Future<void> resetDatabaseFile() async {
  await DatabaseService.instance.close();
  final path = await DatabaseService.instance.databasePath;

  for (final suffix in const ['', '-wal', '-shm', '-journal']) {
    final file = File('$path$suffix');
    for (var attempt = 0; ; attempt++) {
      try {
        if (await file.exists()) await file.delete();
        break;
      } on FileSystemException {
        if (attempt >= 20) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
  }
}
