import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

DatabaseConnection connect(String name) {
  return driftDatabase(name: name);
}
