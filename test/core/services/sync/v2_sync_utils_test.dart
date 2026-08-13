import 'package:flinkpos_v2/core/services/sync/v2_sync_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('V2SyncUtils', () {
    test('normalizes nullable text and numeric values from API payloads', () {
      expect(V2SyncUtils.asString('  LOC01  '), 'LOC01');
      expect(V2SyncUtils.asString('   '), isNull);
      expect(V2SyncUtils.asInt('14'), 14);
      expect(V2SyncUtils.asInt(14.6), 15);
      expect(V2SyncUtils.asDouble('45.50'), 45.5);
    });

    test('converts money values without losing integer rupiah amounts', () {
      expect(V2SyncUtils.moneyToMinor('45,000.00'), 45000);
      expect(V2SyncUtils.moneyToMinor(12500), 12500);
      expect(V2SyncUtils.moneyToMinor('invalid'), 0);
    });

    test('handles backend boolean variants deterministically', () {
      for (final value in <Object>['1', 'true', 'yes', 'y', 'active', true]) {
        expect(V2SyncUtils.intToBoolFlag(value), isTrue);
      }
      expect(V2SyncUtils.intToBoolFlag('0'), isFalse);
      expect(V2SyncUtils.intToBoolFlag(null, defaultValue: true), isTrue);
    });

    test('normalizes maps and excludes invalid entries from map lists', () {
      expect(V2SyncUtils.asMap(<Object, Object>{1: 'value'}), <String, dynamic>{
        '1': 'value',
      });
      expect(
        V2SyncUtils.asMapList(<dynamic>[
          <String, dynamic>{'id': '1'},
          'bad',
        ]),
        <Map<String, dynamic>>[
          <String, dynamic>{'id': '1'},
        ],
      );
    });

    test(
      'accepts JSON arrays and comma-separated strings from legacy fields',
      () {
        expect(V2SyncUtils.asStringList('["cash", "qris"]'), <String>[
          'cash',
          'qris',
        ]);
        expect(V2SyncUtils.asStringList('cash, qris, '), <String>[
          'cash',
          'qris',
        ]);
        expect(V2SyncUtils.asStringList(null), isEmpty);
      },
    );

    test('preserves invalid JSON and falls back for non-encodable values', () {
      expect(V2SyncUtils.decodeLooseJson('{bad json'), '{bad json');
      expect(V2SyncUtils.decodeLooseJson('not-json'), 'not-json');
      expect(V2SyncUtils.encodeJson(<String, Object>{'id': 1}), '{"id":1}');
      expect(V2SyncUtils.encodeJson(Object()), isNotEmpty);
    });
  });
}
