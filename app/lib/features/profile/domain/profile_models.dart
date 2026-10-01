// KRATOS Profile & Account Domain Models.
// Encapsulates user identity, personal statement ("Who you are and who you want to be"),
// avatar metadata, leading XP domain, and highest Level reached.

import '../../../domain/ids.dart';

class UserProfileData {
  final Id userId;
  final String displayName;
  final String? caption;
  final String? avatarUrl;
  final String? email;
  final String timezone;
  final DateTime createdAt;
  final String primaryXpDomain;
  final String highestLevel;
  final int totalXp;
  final bool isSynced;

  const UserProfileData({
    required this.userId,
    required this.displayName,
    this.caption,
    this.avatarUrl,
    this.email,
    required this.timezone,
    required this.createdAt,
    required this.primaryXpDomain,
    required this.highestLevel,
    required this.totalXp,
    this.isSynced = true,
  });

  UserProfileData copyWith({
    String? displayName,
    String? caption,
    String? avatarUrl,
    String? email,
    String? primaryXpDomain,
    String? highestLevel,
    int? totalXp,
    bool? isSynced,
  }) {
    return UserProfileData(
      userId: userId,
      displayName: displayName ?? this.displayName,
      caption: caption ?? this.caption,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      email: email ?? this.email,
      timezone: timezone,
      createdAt: createdAt,
      primaryXpDomain: primaryXpDomain ?? this.primaryXpDomain,
      highestLevel: highestLevel ?? this.highestLevel,
      totalXp: totalXp ?? this.totalXp,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
