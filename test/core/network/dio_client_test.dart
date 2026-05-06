import 'package:flutter_test/flutter_test.dart';

import 'package:admin_console/core/network/dio_client.dart';

void main() {
  group('DioClient.assertValidSchoolId', () {
    test('rejects malformed UUIDs', () {
      expect(
        () => DioClient.assertValidSchoolId('not-a-uuid'),
        throwsA(isA<FormatException>()),
      );
    });

    test('allows empty values as omitted', () {
      expect(() => DioClient.assertValidSchoolId(''), returnsNormally);
      expect(() => DioClient.assertValidSchoolId('   '), returnsNormally);
      expect(() => DioClient.assertValidSchoolId(null), returnsNormally);
    });
  });
}
