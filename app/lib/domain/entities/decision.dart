import '../ids.dart';

enum DecisionStatus {
  pending,
  resolved,
  cancelled,
  archived,
  deleted;

  static DecisionStatus fromString(String val) {
    return switch (val.toLowerCase().trim()) {
      'resolved' => DecisionStatus.resolved,
      'cancelled' => DecisionStatus.cancelled,
      'archived' => DecisionStatus.archived,
      'deleted' => DecisionStatus.deleted,
      _ => DecisionStatus.pending,
    };
  }
}

class Decision {
  final Id id;
  final Id ownerId;
  final String title;
  final String? content;
  final DecisionStatus status;
  final Id? goalId;
  final Id? projectId;
  final Id? lifeAreaId;
  final Id? categoryId;
  final DateTime? resolvedAt;
  final DateTime? deletedAt;
  final Id? deletedBy;
  final String? deletedReason;
  final String versionHlc;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Decision({
    required this.id,
    required this.ownerId,
    required this.title,
    this.content,
    this.status = DecisionStatus.pending,
    this.goalId,
    this.projectId,
    this.lifeAreaId,
    this.categoryId,
    this.resolvedAt,
    this.deletedAt,
    this.deletedBy,
    this.deletedReason,
    required this.versionHlc,
    required this.createdAt,
    required this.updatedAt,
  });
}
