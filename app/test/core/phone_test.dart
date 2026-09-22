import 'package:flutter_test/flutter_test.dart';
import 'package:hostels/core/phone.dart';

void main() {
  group('isValidPhoneE164', () {
    test('accepts a well-formed +91 number', () {
      expect(isValidPhoneE164('+919876500001'), isTrue);
    });

    test('rejects a number missing the country code', () {
      expect(isValidPhoneE164('9876500001'), isFalse);
    });

    test('rejects a number with the wrong digit count', () {
      expect(isValidPhoneE164('+91987650000'), isFalse);
      expect(isValidPhoneE164('+9198765000011'), isFalse);
    });

    test('rejects a non-Indian country code', () {
      expect(isValidPhoneE164('+11234567890'), isFalse);
    });
  });
}
