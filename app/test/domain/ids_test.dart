import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/domain/ids.dart';

void main() {
  group('Id (UUID v7 wrapper)', () {
    test('fromString parses valid v7', () {
      // Generated locally: any RFC-9562 v7 string is fine.
      final id = Id.fromString('018e5e9a-7c00-7000-8000-1234567890ab');
      expect(id.value, '018e5e9a-7c00-7000-8000-1234567890ab');
    });

    test('fromString rejects malformed input', () {
      expect(() => Id.fromString('not-a-uuid'), throwsFormatException);
      expect(() => Id.fromString(''), throwsFormatException);
    });

    test('uuidV7 returns unique monotonic-ish ids', () {
      final a = Id.uuidV7();
      final b = Id.uuidV7();
      expect(a.value, isNot(b.value));
    });

    test('equality + hashCode', () {
      const a = Id('018e5e9a-7c00-7000-8000-1234567890ab');
      const b = Id('018e5e9a-7c00-7000-8000-1234567890ab');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
