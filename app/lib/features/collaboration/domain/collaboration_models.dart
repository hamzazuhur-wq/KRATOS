// ignore_for_file: public_member_api_docs
// Wave 21: Collaborative Goals & Accountability Domain Models.

enum PartnerRole {
  viewer,
  accountabilityPartner,
  coach,
}

class SharedGoalEntity {
  final String id;
  final String goalId;
  final String ownerId;
  final String partnerId;
  final PartnerRole role;
  final bool canComment;
  final bool canVerify;
  final String versionHlc;
  final DateTime createdAt;

  const SharedGoalEntity({
    required this.id,
    required this.goalId,
    required this.ownerId,
    required this.partnerId,
    required this.role,
    this.canComment = true,
    this.canVerify = false,
    required this.versionHlc,
    required this.createdAt,
  });
}

class GoalCommentEntity {
  final String id;
  final String goalId;
  final String authorId;
  final String bodyText;
  final String versionHlc;
  final DateTime createdAt;

  const GoalCommentEntity({
    required this.id,
    required this.goalId,
    required this.authorId,
    required this.bodyText,
    required this.versionHlc,
    required this.createdAt,
  });
}
