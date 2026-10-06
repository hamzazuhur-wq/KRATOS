import 'package:flutter/material.dart';
import '../../data/calendar_repository.dart';

class CalendarDayView extends StatelessWidget {
  final DateTime date;
  final List<CalendarEvent> events;

  const CalendarDayView({super.key, required this.date, required this.events});

  @override
  Widget build(BuildContext context) {
    const double hourHeight = 60.0;
    
    return SingleChildScrollView(
      child: Stack(
        children: [
          // Background grid
          Column(
            children: List.generate(24, (hour) {
              return Container(
                height: hourHeight,
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.white12)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 50,
                      child: Text(
                        '${hour.toString().padLeft(2, '0')}:00',
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const Expanded(child: SizedBox()),
                  ],
                ),
              );
            }),
          ),
          
          // Events overlay
          ...events.where((e) => e.startTime.day == date.day && e.startTime.month == date.month && e.startTime.year == date.year).map((e) {
            final startMinuteOfDay = e.startTime.hour * 60 + e.startTime.minute;
            int durationMinutes = 30; // default for goals/tasks
            if (e.endTime != null) {
              durationMinutes = e.endTime!.difference(e.startTime).inMinutes;
            }
            if (durationMinutes < 15) durationMinutes = 15;

            final topOffset = (startMinuteOfDay / 60.0) * hourHeight;
            final eventHeight = (durationMinutes / 60.0) * hourHeight;

            return Positioned(
              top: topOffset,
              left: 54, // past the time column
              right: 4,
              height: eventHeight,
              child: _buildEventCard(e),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEventCard(CalendarEvent event) {
    Color accent = Colors.white24;
    if (event.type == CalendarEventType.session) accent = const Color(0xFFC6F135);
    if (event.type == CalendarEventType.goal) accent = Colors.orangeAccent;
    if (event.type == CalendarEventType.task) accent = Colors.blueAccent;

    return Container(
      decoration: BoxDecoration(
        color: accent.withOpacity(0.1),
        border: Border(left: BorderSide(color: accent, width: 3)),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            event.title,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (event.subtitle != null)
            Text(
              event.subtitle!,
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
        ],
      ),
    );
  }
}
