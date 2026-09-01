import 'package:flinkpos_v2/core/services/sync/pos_v2_customer_service.dart';
import 'package:flutter_test/flutter_test.dart';
void main() {
  group('PosV2CustomerService Phone Normalization & Query Detection', () {
    test('extractPhoneCore strips prefixes and formatting correctly', () {
      expect(PosV2CustomerService.extractPhoneCore('082112345678'), '82112345678');
      expect(PosV2CustomerService.extractPhoneCore('6282112345678'), '82112345678');
      expect(PosV2CustomerService.extractPhoneCore('+6282112345678'), '82112345678');
      expect(PosV2CustomerService.extractPhoneCore('+62 821-1234-5678'), '82112345678');
      expect(PosV2CustomerService.extractPhoneCore('0812-3456-7890'), '81234567890');
      expect(PosV2CustomerService.extractPhoneCore('8123456789'), '8123456789');
    });

    test('isLikelyPhoneNumber distinguishes phone numbers from names', () {
      // Valid phone queries
      expect(PosV2CustomerService.isLikelyPhoneNumber('082112345678'), isTrue);
      expect(PosV2CustomerService.isLikelyPhoneNumber('6282112345678'), isTrue);
      expect(PosV2CustomerService.isLikelyPhoneNumber('+62 821-1234-5678'), isTrue);
      expect(PosV2CustomerService.isLikelyPhoneNumber('08123'), isTrue);
      expect(PosV2CustomerService.isLikelyPhoneNumber('0857-1234-567'), isTrue);

      // Name queries
      expect(PosV2CustomerService.isLikelyPhoneNumber('Budi Santoso'), isFalse);
      expect(PosV2CustomerService.isLikelyPhoneNumber('Budi 08'), isFalse);
      expect(PosV2CustomerService.isLikelyPhoneNumber('John Doe 123'), isFalse);
      expect(PosV2CustomerService.isLikelyPhoneNumber('PT Maju Bersama'), isFalse);
      expect(PosV2CustomerService.isLikelyPhoneNumber(''), isFalse);
      expect(PosV2CustomerService.isLikelyPhoneNumber('12'), isFalse); // too short
    });
  });
}
