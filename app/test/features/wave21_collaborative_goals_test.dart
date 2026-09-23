// Wave 21: Unit tests for Collaborative Goals & Accountability.

import 'package:drift/native.dart';
import 'package:test/test.dart';
import '../../lib/data/drift/app_database.dart';
import '../../lib/features/collaboration/domain/collaboration_models.dart';

void main() {
  group('Partner Roles and Collaboration Models', () {
    test('PartnerRole enum covers viewer, partner, and coach', () {
      expect(PartnerRole.values.length, equals(3));
      expect(PartnerRole.values, contains(PartnerRole.accountabilityPartner));
      expect(PartnerRole.values, contains(PartnerRole.coach));
      expect(PartnerRole.values, contains(PartnerRole.viewer));
    });

    test('SharedGoalEntity instantiates with valid parameters', () {
      final shared = SharedGoalEntity(
        id: 'sg_01',
        goalId: 'goal_100',
        ownerId: 'usr_owner',
        partnerId: 'usr_partner',
        role: PartnerRole.coach,
        canComment: true,
        canVerify: true,
        versionHlc: '0191ebc4-test',
        createdAt: DateTime.now().toUtc(),
      );

      expect(shared.role, equals(PartnerRole.coach));
      expect(shared.canVerify, isTrue);
    });

    test('GoalCommentEntity validates body text', () {
      final comment = GoalCommentEntity(
        id: 'cmt_01',
        goalId: 'goal_100',
        authorId: 'usr_partner',
        bodyText: 'Keep up the great work! Halfway to the goal.',
        versionHlc: '0191ebc4-test',
        createdAt: DateTime.now().toUtc(),
      );

      expect(comment.bodyText.isNotEmpty, isTrue);
      expect(comment.authorId, equals('usr_partner'));
    });
  });
}
