// ignore_for_file: public_member_api_docs
// Wave 9: Session, Activity, and Project domain entities.
// Sessions are time-block records that trigger XP awards on completion.
// Activities are named templates; Projects are goal-linked work containers.

import 'dart:convert';

import '../../../domain/errors.dart';
import '../../../domain/hlc.dart';
import '../../../domain/ids.dart';
import '../../../domain/timestamps.dart';

// ---------------------------------------------------------------------------
// ActivityXpRule — describes how a session earns XP for this activity
// ---------------------------------------------------------------------------

/// Describes how XP is calculated for a completed session of this Activity.
///
/// Two modes:
/// - [perMinuteXp]: earn XP proportional to session duration.
/// - [flatXp]: earn a fixed amount regardless of duration.
///
/// If both are set, perMinute takes precedence.
class ActivityXpRule {
  final int? perMinuteXp;
  final int? flatXp;

  const ActivityXpRule({this.perMinuteXp, this.flatXp});

  factory ActivityXpRule.fromJson(String jsonStr) {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    return ActivityXpRule(
      perMinuteXp: map['per_minute_xp'] as int?,
      flatXp: map['flat_xp'] as int?,
    );
  }

  String toJson() => jsonEncode({
        if (perMinuteXp != null) 'per_minute_xp': perMinuteXp,
        if (flatXp != null) 'flat_xp': flatXp,
      });

  /// Compute XP earned for [durationMs] milliseconds of session time.
  int computeXp(int durationMs) {
    if (perMinuteXp != null) {
      final minutes = durationMs / 60000;
      return (perMinuteXp! * minutes).round();
    }
    return flatXp ?? 0;
  }
}

// ---------------------------------------------------------------------------
// ActivityEntity — reusable session template
// ---------------------------------------------------------------------------

class ActivityEntity {
  final Id id;
  final Id ownerId;
  final Id? lifeAreaId;
  final String name;
  final String? description;
  final ActivityXpRule? xpRule;
  final Iso8601Timestamp? archivedAt;
  final Iso8601Timestamp? deletedAt;
  final Hlc versionHlc;
  final Iso8601Timestamp createdAt;
  final Iso8601Timestamp updatedAt;

  ActivityEntity({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.versionHlc,
    required this.createdAt,
    required this.updatedAt,
    this.lifeAreaId,
    this.description,
    this.xpRule,
    this.archivedAt,
    this.deletedAt,
  }) {
    if (name.trim().isEmpty) {
      throw ValidationError('name', 'Activity name must not be blank');
    }
  }

  bool get isArchived => archivedAt != null;
  bool get isDeleted => deletedAt != null;
  bool get isActive => !isArchived && !isDeleted;

  ActivityEntity rename(String newName, Hlc newHlc) {
    _requireActive();
    return ActivityEntity(
      id: id,
      ownerId: ownerId,
      lifeAreaId: lifeAreaId,
      name: newName,
      description: description,
      xpRule: xpRule,
      archivedAt: archivedAt,
      deletedAt: deletedAt,
      versionHlc: newHlc,
      createdAt: createdAt,
      updatedAt: Iso8601Timestamp.now(),
    );
  }

  void _requireActive() {
    if (isDeleted) throw ConflictError('Cannot modify a deleted Activity');
    if (isArchived) throw ConflictError('Cannot modify an archived Activity');
  }
}

// ---------------------------------------------------------------------------
// SessionStatus — lifecycle of a time-block
// ---------------------------------------------------------------------------

enum SessionStatus {
  /// Timer is running; endedAt is null.
  running,

  /// Session completed normally.
  completed,

  /// Session was abandoned without awarding XP.
  abandoned;

  static SessionStatus fromDurations(int? durationMs) =>
      durationMs != null ? SessionStatus.completed : SessionStatus.running;
}

// ---------------------------------------------------------------------------
// SessionEntity — single time-block record
// ---------------------------------------------------------------------------

/// Represents a completed or in-progress time block.
///
/// XP is awarded through [XpLedgerWriter] after the session ends.
/// The XP amount is calculated from the linked Activity's [ActivityXpRule]
/// or the Task's xpReward.
class SessionEntity {
  final Id id;
  final Id ownerId;
  final Id? taskId;
  final Id? activityId;
  final Id? lifeAreaId;
  final Iso8601Timestamp startedAt;
  final Iso8601Timestamp? endedAt;

  /// Duration in milliseconds; null while session is still running.
  final int? durationMs;
  final String? note;
  final Iso8601Timestamp? deletedAt;
  final Hlc versionHlc;
  final Iso8601Timestamp createdAt;
  final Iso8601Timestamp updatedAt;

  SessionEntity({
    required this.id,
    required this.ownerId,
    required this.startedAt,
    required this.versionHlc,
    required this.createdAt,
    required this.updatedAt,
    this.taskId,
    this.activityId,
    this.lifeAreaId,
    this.endedAt,
    this.durationMs,
    this.note,
    this.deletedAt,
  }) {
    if (taskId == null && activityId == null) {
      throw ValidationError(
        'context',
        'Session must be linked to a Task or an Activity',
      );
    }
    if (durationMs != null && durationMs! < 0) {
      throw ValidationError('durationMs', 'durationMs must be >= 0');
    }
  }

  bool get isRunning => endedAt == null && deletedAt == null;
  bool get isCompleted => endedAt != null && deletedAt == null;
  bool get isDeleted => deletedAt != null;

  /// Duration as a human-readable string (e.g. "1h 23m").
  String get formattedDuration {
    final ms = durationMs ?? 0;
    final minutes = (ms ~/ 60000) % 60;
    final hours = ms ~/ 3600000;
    if (hours > 0) return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    return '${minutes}m';
  }

  SessionEntity end(Iso8601Timestamp endTime, Hlc newHlc) {
    if (isDeleted) throw ConflictError('Cannot end a deleted Session');
    if (isCompleted) throw ConflictError('Session is already completed');
    final duration = endTime.value.difference(startedAt.value).inMilliseconds;
    if (duration < 0) {
      throw ValidationError('endedAt', 'endedAt must be after startedAt');
    }
    return SessionEntity(
      id: id,
      ownerId: ownerId,
      taskId: taskId,
      activityId: activityId,
      lifeAreaId: lifeAreaId,
      startedAt: startedAt,
      endedAt: endTime,
      durationMs: duration,
      note: note,
      deletedAt: deletedAt,
      versionHlc: newHlc,
      createdAt: createdAt,
      updatedAt: Iso8601Timestamp.now(),
    );
  }
}

// ---------------------------------------------------------------------------
// ProjectStatus — lifecycle of a project
// ---------------------------------------------------------------------------

enum ProjectStatus {
  active,
  completed,
  paused,
  cancelled;

  static ProjectStatus fromString(String s) =>
      ProjectStatus.values.firstWhere((v) => v.name == s);
}

// ---------------------------------------------------------------------------
// ProjectEntity — goal-linked work container
// ---------------------------------------------------------------------------

class ProjectEntity {
  final Id id;
  final Id ownerId;
  final Id? goalId;
  final Id? lifeAreaId;
  final String title;
  final String? description;
  final ProjectStatus status;
  final Iso8601Timestamp? dueDate;
  final Iso8601Timestamp? deletedAt;
  final Hlc versionHlc;
  final Iso8601Timestamp createdAt;
  final Iso8601Timestamp updatedAt;

  ProjectEntity({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.versionHlc,
    required this.createdAt,
    required this.updatedAt,
    this.goalId,
    this.lifeAreaId,
    this.description,
    this.status = ProjectStatus.active,
    this.dueDate,
    this.deletedAt,
  }) {
    if (title.trim().isEmpty) {
      throw ValidationError('title', 'Project title must not be blank');
    }
  }

  bool get isActive => status == ProjectStatus.active && deletedAt == null;
  bool get isCompleted => status == ProjectStatus.completed;
  bool get isDeleted => deletedAt != null;

  ProjectEntity complete(Hlc newHlc) {
    _requireNotDeleted();
    if (isCompleted) throw ConflictError('Project is already completed');
    return ProjectEntity(
      id: id,
      ownerId: ownerId,
      goalId: goalId,
      lifeAreaId: lifeAreaId,
      title: title,
      description: description,
      status: ProjectStatus.completed,
      dueDate: dueDate,
      deletedAt: deletedAt,
      versionHlc: newHlc,
      createdAt: createdAt,
      updatedAt: Iso8601Timestamp.now(),
    );
  }

  ProjectEntity rename(String newTitle, Hlc newHlc) {
    _requireActive();
    return ProjectEntity(
      id: id,
      ownerId: ownerId,
      goalId: goalId,
      lifeAreaId: lifeAreaId,
      title: newTitle,
      description: description,
      status: status,
      dueDate: dueDate,
      deletedAt: deletedAt,
      versionHlc: newHlc,
      createdAt: createdAt,
      updatedAt: Iso8601Timestamp.now(),
    );
  }

  void _requireActive() {
    _requireNotDeleted();
    if (status == ProjectStatus.completed) {
      throw ConflictError('Cannot modify a completed Project');
    }
  }

  void _requireNotDeleted() {
    if (isDeleted) throw ConflictError('Cannot modify a deleted Project');
  }
}
