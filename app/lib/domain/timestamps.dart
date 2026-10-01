// ignore_for_file: public_member_api_docs
//
// UTC-only timestamp wrapper.

class Iso8601Timestamp {
  final DateTime value;
  Iso8601Timestamp(int ms)
    : value = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);

  Iso8601Timestamp.fromDateTime(DateTime utc) : value = utc.toUtc();

  static Iso8601Timestamp utc(int ms) => Iso8601Timestamp(ms);

  static Iso8601Timestamp now() =>
      Iso8601Timestamp.fromDateTime(DateTime.now().toUtc());

  String toIso8601() => value.toIso8601String();

  @override
  bool operator ==(Object other) =>
      other is Iso8601Timestamp && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => toIso8601();
}
