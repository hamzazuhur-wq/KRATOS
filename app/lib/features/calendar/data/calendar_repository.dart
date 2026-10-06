import 'package:drift/drift.dart';
import '../../../../data/drift/app_database.dart';

enum CalendarEventType { session, task, goal }

class CalendarEvent {
  final String id;
  final String title;
  final CalendarEventType type;
  final DateTime startTime;
  final DateTime? endTime;
  final String? lifeAreaId;
  final String? subtitle;
  
  const CalendarEvent({
    required this.id,
    required this.title,
    required this.type,
    required this.startTime,
    this.endTime,
    this.lifeAreaId,
    this.subtitle,
  });
}

class CalendarRepository {
  final AppDatabase database;

  CalendarRepository({required this.database});

  Future<List<CalendarEvent>> fetchEvents(String ownerId, DateTime start, DateTime end) async {
    final tasksQuery = database.select(database.tasks)..where((t) => 
      t.ownerId.equals(ownerId) & 
      t.deletedAt.isNull() & 
      t.dueDate.isNotNull() &
      t.dueDate.isBetweenValues(start, end)
    );
    final tasks = await tasksQuery.get();

    final goalsQuery = database.select(database.goals)..where((g) => 
      g.ownerId.equals(ownerId) & 
      g.deletedAt.isNull() & 
      g.dueDate.isNotNull() &
      g.dueDate.isBetweenValues(start, end)
    );
    final goals = await goalsQuery.get();

    final sessionsQuery = database.select(database.sessions)..where((s) => 
      s.ownerId.equals(ownerId) & 
      s.deletedAt.isNull() & 
      s.startedAt.isBetweenValues(start, end)
    );
    final sessions = await sessionsQuery.get();

    final events = <CalendarEvent>[];
    
    for (final task in tasks) {
      events.add(CalendarEvent(
        id: task.id,
        title: task.title,
        type: CalendarEventType.task,
        startTime: task.dueDate!.toLocal(),
        endTime: null,
        lifeAreaId: null, // tasks don't always have direct life area without join
        subtitle: 'Task',
      ));
    }
    
    for (final goal in goals) {
      events.add(CalendarEvent(
        id: goal.id,
        title: goal.title,
        type: CalendarEventType.goal,
        startTime: goal.dueDate!.toLocal(),
        endTime: null,
        lifeAreaId: goal.lifeAreaId,
        subtitle: 'Goal Deadline',
      ));
    }
    
    for (final session in sessions) {
      final sTime = session.startedAt.toLocal();
      DateTime? eTime;
      if (session.endedAt != null) {
        eTime = session.endedAt!.toLocal();
      } else if (session.durationMs != null) {
        eTime = sTime.add(Duration(milliseconds: session.durationMs!));
      }
      events.add(CalendarEvent(
        id: session.id,
        title: session.note ?? 'Session',
        type: CalendarEventType.session,
        startTime: sTime,
        endTime: eTime,
        lifeAreaId: session.lifeAreaId,
        subtitle: 'Session',
      ));
    }

    events.sort((a, b) => a.startTime.compareTo(b.startTime));
    return events;
  }
}
