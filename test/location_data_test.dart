import 'package:flutter_test/flutter_test.dart';
import 'package:test_flutter/struct/location_data.dart';

void main() {
  group('LocationSelection validation', () {
    test('accepts a valid coordinate pair', () {
      expect(
        LocationSelection.validate(
          locationName: 'Kệ A3 - Phòng 201',
          latitude: 21.0285,
          longitude: 105.8542,
        ),
        isNull,
      );
    });

    test('requires both coordinates or neither', () {
      expect(
        LocationSelection.validate(
          locationName: '',
          latitude: 21,
          longitude: null,
        ),
        isNotNull,
      );
    });

    test('rejects coordinates outside their valid ranges', () {
      expect(
        LocationSelection.validate(
          locationName: '',
          latitude: 91,
          longitude: 0,
        ),
        isNotNull,
      );
      expect(
        LocationSelection.validate(
          locationName: '',
          latitude: 0,
          longitude: -181,
        ),
        isNotNull,
      );
    });

    test('rejects non-finite coordinates', () {
      expect(
        LocationSelection.validate(
          locationName: '',
          latitude: double.nan,
          longitude: 0,
        ),
        isNotNull,
      );
    });

    test('limits the location name to 100 characters', () {
      expect(
        LocationSelection.validate(
          locationName: 'a' * 101,
          latitude: null,
          longitude: null,
        ),
        isNotNull,
      );
    });
  });
}
