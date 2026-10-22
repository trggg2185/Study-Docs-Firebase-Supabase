import 'package:flutter_test/flutter_test.dart';
import 'package:test_flutter/utils/tag_utils.dart';

void main() {
  group('formatTags', () {
    test('joins tags with commas and spaces', () {
      expect(
        formatTags(['flutter', 'dart', 'mobile']),
        'flutter, dart, mobile',
      );
    });

    test('returns an empty string for an empty list', () {
      expect(formatTags([]), '');
    });
  });

  group('normalizeTags', () {
    test(
      'trims values, lowercases them, and removes empty and duplicate tags',
      () {
        expect(normalizeTags(' Flutter, , DART, flutter, Mobile '), [
          'flutter',
          'dart',
          'mobile',
        ]);
      },
    );

    test('keeps at most five tags', () {
      expect(normalizeTags('a, b, c, d, e, f'), ['a', 'b', 'c', 'd', 'e']);
    });

    test('ignores tags longer than 30 characters', () {
      expect(normalizeTags('${'a' * 31}, valid'), ['valid']);
    });

    test('accepts tags that are exactly 30 characters long', () {
      final tag = 'a' * 30;

      expect(normalizeTags('$tag, valid'), [tag, 'valid']);
    });
  });
}
