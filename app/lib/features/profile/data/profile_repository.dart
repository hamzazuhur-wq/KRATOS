// KRATOS Profile & Account Repository.
// Unites Drift SQLite persistence, Supabase Auth user metadata, Supabase Storage for avatars,
// and real progression metrics (Leading XP Domain & Highest Level reached).

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' as drift;
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../../../data/drift/app_database.dart';
import '../../../domain/ids.dart';
import '../../auth/domain/auth_service.dart';
import '../../levels/data/levels_dashboard_repository.dart';
import '../../xp/data/xp_analytics_dao.dart';
import '../domain/profile_models.dart';

class ProfileRepository {
  final AppDatabase database;
  final AuthService? authService;
  final supa.SupabaseClient? supabaseClient;

  ProfileRepository({
    required this.database,
    this.authService,
    supa.SupabaseClient? supabaseClient,
  }) : supabaseClient = supabaseClient ?? _getSafeSupabaseClient();

  static supa.SupabaseClient? _getSafeSupabaseClient() {
    try {
      return supa.Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Watch live profile with reactive updates from local Drift SQLite, XP ledger, and Levels.
  Stream<UserProfileData> watchProfile(String userId) async* {
    final levelsRepo = LevelsDashboardRepository(database);
    final xpDao = XpAnalyticsDao(database);

    // Watch users table row
    final userStream = (database.select(database.users)
          ..where((u) => u.id.equals(userId)))
        .watchSingleOrNull();

    // Yield initial or reactive combination
    await for (final userRow in userStream) {
      final authUser = authService?.currentUser;
      final supaUser = supabaseClient?.auth.currentUser;

      // Extract details
      final displayName = userRow?.displayName ??
          authUser?.displayName ??
          supaUser?.userMetadata?['full_name'] as String? ??
          'Operative';

      final caption = userRow?.caption ??
          supaUser?.userMetadata?['caption'] as String?;

      final avatarUrl = userRow?.avatarUrl ??
          authUser?.avatarUrl ??
          supaUser?.userMetadata?['avatar_url'] as String?;

      final email = userRow?.email ??
          authUser?.email ??
          supaUser?.email ??
          'user@kratos.local';

      final createdAt = userRow?.createdAt ??
          authUser?.createdAt ??
          DateTime.now().toUtc();

      // Calculate Leading Life Area / XP Domain
      final xpMap = await xpDao.xpByLifeArea(userId);
      final activeAreas = await (database.select(database.lifeAreas)
            ..where((a) =>
                a.ownerId.equals(userId) &
                a.archivedAt.isNull() &
                a.deletedAt.isNull())
            ..orderBy([(a) => drift.OrderingTerm.asc(a.sortOrder)]))
          .get();

      String primaryXpDomain = 'General Mastery';
      int maxAreaXp = -1;
      int totalXp = 0;

      for (final area in activeAreas) {
        final areaXp = xpMap[area.id] ?? 0;
        totalXp += areaXp;
        if (areaXp > maxAreaXp) {
          maxAreaXp = areaXp;
          primaryXpDomain = area.name;
        }
      }

      if (activeAreas.isEmpty) {
        primaryXpDomain = 'General Development';
      }

      // Calculate Highest Level reached from real Progression
      String highestLevel = 'Bronze I';
      try {
        final progressions = await levelsRepo.getProgressions(userId);
        if (progressions.isNotEmpty) {
          progressions.sort((a, b) {
            final levelCmp = b.progression.level.compareTo(a.progression.level);
            if (levelCmp != 0) return levelCmp;
            return b.progression.totalXp.compareTo(a.progression.totalXp);
          });
          final top = progressions.first;
          highestLevel = '${top.progression.tier} Level ${top.progression.level}';
        }
      } catch (_) {
        // Fallback to default Bronze I
      }

      yield UserProfileData(
        userId: Id(userId),
        displayName: displayName,
        caption: caption,
        avatarUrl: avatarUrl,
        email: email,
        timezone: userRow?.timezone ?? 'UTC',
        createdAt: createdAt,
        primaryXpDomain: primaryXpDomain,
        highestLevel: highestLevel,
        totalXp: totalXp,
      );
    }
  }

  /// One-shot fetch of profile snapshot.
  Future<UserProfileData> getProfile(String userId) async {
    return watchProfile(userId).first;
  }

  /// Update profile identity metadata locally and in Supabase if connected.
  Future<void> updateProfile({
    required String userId,
    required String displayName,
    String? caption,
    String? avatarUrl,
  }) async {
    final now = DateTime.now().toUtc();

    // 1. Update local Drift SQLite database
    final existing = await (database.select(database.users)
          ..where((u) => u.id.equals(userId)))
        .getSingleOrNull();

    if (existing != null) {
      await (database.update(database.users)..where((u) => u.id.equals(userId))).write(
        UsersCompanion(
          displayName: drift.Value(displayName),
          caption: drift.Value(caption),
          avatarUrl: avatarUrl != null ? drift.Value(avatarUrl) : const drift.Value.absent(),
          updatedAt: drift.Value(now),
        ),
      );
    } else {
      await database.into(database.users).insert(
            UsersCompanion.insert(
              id: userId,
              deviceId: 'device-local',
              displayName: drift.Value(displayName),
              caption: drift.Value(caption),
              avatarUrl: drift.Value(avatarUrl),
              timezone: 'UTC',
              createdAt: now,
              updatedAt: now,
            ),
          );
    }

    // 2. Sync to Supabase user metadata if available
    try {
      final client = supabaseClient;
      if (client != null && client.auth.currentUser != null) {
        await client.auth.updateUser(
          supa.UserAttributes(
            data: {
              'full_name': displayName,
              'caption': ?caption,
              'avatar_url': ?avatarUrl,
            },
          ),
        );
      }
    } catch (_) {
      // Local-first: continues smoothly even if offline
    }
  }

  /// Upload avatar image to Supabase Storage (bucket: 'avatars') or encode fallback.
  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String fileExt,
  }) async {
    final client = supabaseClient;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename = '$userId/avatar_$timestamp.$fileExt';

    if (client != null && client.auth.currentUser != null) {
      try {
        await client.storage.from('avatars').uploadBinary(
              filename,
              bytes,
              fileOptions: const supa.FileOptions(upsert: true),
            );
        final publicUrl = client.storage.from('avatars').getPublicUrl(filename);
        await updateProfile(
          userId: userId,
          displayName: (await getProfile(userId)).displayName,
          caption: (await getProfile(userId)).caption,
          avatarUrl: publicUrl,
        );
        return publicUrl;
      } catch (_) {
        // Fallback to local data URI if storage offline
      }
    }

    // Offline / Local fallback: data URI representation
    final base64String = base64Encode(bytes);
    final dataUri = 'data:image/$fileExt;base64,$base64String';
    await updateProfile(
      userId: userId,
      displayName: (await getProfile(userId)).displayName,
      caption: (await getProfile(userId)).caption,
      avatarUrl: dataUri,
    );
    return dataUri;
  }

  /// Update password through Supabase Auth.
  Future<void> updatePassword(String newPassword) async {
    if (authService != null) {
      await authService!.updatePassword(newPassword);
      return;
    }
    final client = supabaseClient;
    if (client != null) {
      await client.auth.updateUser(supa.UserAttributes(password: newPassword));
    }
  }

  /// Sign out current session.
  Future<void> signOut() async {
    if (authService != null) {
      await authService!.signOut();
      return;
    }
    final client = supabaseClient;
    if (client != null) {
      await client.auth.signOut();
    }
  }
}
