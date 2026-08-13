import 'package:flinkpos_v2/core/services/local/v2_sqlite_schema.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SQLite schema contains the core offline and sync tables', () {
    final schema = V2SqliteSchema.createStatements.join('\n');

    expect(V2SqliteSchema.version, greaterThan(0));
    expect(schema, contains('CREATE TABLE IF NOT EXISTS app_session'));
    expect(schema, contains('CREATE TABLE IF NOT EXISTS pos_order'));
    expect(schema, contains('CREATE TABLE IF NOT EXISTS pos_order_payment'));
    expect(schema, contains('CREATE TABLE IF NOT EXISTS sync_queue'));
    expect(schema, contains('CREATE TABLE IF NOT EXISTS sync_checkpoint'));
  });
}
