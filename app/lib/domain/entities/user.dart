// ignore_for_file: public_member_api_docs

import '../hlc.dart';
import '../ids.dart';
import '../timestamps.dart';

/// Pure-Dart User entity. Auth is external (Supabase); this represents
/// the per-device profile row only.
class User {
  final Id id;
  final String deviceId;
  final String displayName;
  final String? caption;
  final String? avatarUrl;
  final String? email;
  final String timezone;
  final Hlc versionHlc;
  final Iso8601Timestamp createdAt;
  final Iso8601Timestamp updatedAt;

  const User({
    required this.id,
    required this.deviceId,
    required this.displayName,
    this.caption,
    this.avatarUrl,
    this.email,
    required this.timezone,
    required this.versionHlc,
    required this.createdAt,
    required this.updatedAt,
  });

  User rename(String newName, Hlc newHlc) => User(
        id: id,
        deviceId: deviceId,
        displayName: newName,
        caption: caption,
        avatarUrl: avatarUrl,
        email: email,
        timezone: timezone,
        versionHlc: newHlc,
        createdAt: createdAt,
        updatedAt: Iso8601Timestamp.now(),
      );

  User updateProfile({
    String? newName,
    String? newCaption,
    String? newAvatarUrl,
    required Hlc newHlc,
  }) =>
      User(
        id: id,
        deviceId: deviceId,
        displayName: newName ?? displayName,
        caption: newCaption ?? caption,
        avatarUrl: newAvatarUrl ?? avatarUrl,
        email: email,
        timezone: timezone,
        versionHlc: newHlc,
        createdAt: createdAt,
        updatedAt: Iso8601Timestamp.now(),
      );
}
