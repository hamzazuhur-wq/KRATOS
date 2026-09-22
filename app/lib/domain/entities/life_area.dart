// ignore_for_file: public_member_api_docs

import '../errors.dart';
import '../hlc.dart';
import '../ids.dart';
import '../timestamps.dart';

/// Pure-Dart LifeArea entity.
class LifeArea {
  final Id id;
  final Id ownerId;
  final String name;
  final String? description;
  final String? color;
  final String? icon;
  final int sortOrder;
  final Iso8601Timestamp? archivedAt;
  final Iso8601Timestamp? deletedAt;
  final Hlc versionHlc;
  final Iso8601Timestamp createdAt;
  final Iso8601Timestamp updatedAt;

  const LifeArea({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.versionHlc,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.color,
    this.icon,
    this.sortOrder = 0,
    this.archivedAt,
    this.deletedAt,
  });

  bool get isArchived => archivedAt != null;
  bool get isDeleted => deletedAt != null;
  bool get isActive => !isArchived && !isDeleted;

  LifeArea rename(String newName, Hlc newHlc) {
    _requireActive();
    return LifeArea(
      id: id,
      ownerId: ownerId,
      name: newName,
      description: description,
      color: color,
      icon: icon,
      sortOrder: sortOrder,
      archivedAt: archivedAt,
      deletedAt: deletedAt,
      versionHlc: newHlc,
      createdAt: createdAt,
      updatedAt: Iso8601Timestamp.now(),
    );
  }

  LifeArea archive(Hlc newHlc) {
    _requireActive();
    return LifeArea(
      id: id,
      ownerId: ownerId,
      name: name,
      description: description,
      color: color,
      icon: icon,
      sortOrder: sortOrder,
      archivedAt: Iso8601Timestamp.now(),
      deletedAt: deletedAt,
      versionHlc: newHlc,
      createdAt: createdAt,
      updatedAt: Iso8601Timestamp.now(),
    );
  }

  void _requireActive() {
    if (isDeleted) {
      throw ConflictError('Cannot modify a deleted LifeArea');
    }
    if (isArchived) {
      throw ConflictError('Cannot modify an archived LifeArea');
    }
  }
}
