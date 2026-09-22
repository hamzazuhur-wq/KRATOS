// ignore_for_file: public_member_api_docs

import '../entities/life_area.dart';
import '../hlc.dart';
import '../ids.dart';

abstract interface class LifeAreaRepository {
  Future<LifeArea?> findById(Id id);
  Future<List<LifeArea>> findByOwner(Id ownerId);
  Future<List<LifeArea>> findActiveByOwner(Id ownerId);
  Future<void> save(LifeArea area);
  Future<void> archive(Id id, Hlc newHlc);
}
