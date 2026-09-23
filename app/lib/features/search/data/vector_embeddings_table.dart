// ignore_for_file: public_member_api_docs
// Wave 19: Vector Embeddings Drift Table Definition.

import 'package:drift/drift.dart';

@DataClassName('VectorEmbeddingData')
class VectorEmbeddings extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get entityKind => text()();
  TextColumn get entityId => text()();
  TextColumn get embeddingJson => text()();
  IntColumn get dimensions => integer().withDefault(const Constant(384))();
  TextColumn get modelId => text().withDefault(const Constant('bge-small-en-v1.5'))();
  TextColumn get versionHlc => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
