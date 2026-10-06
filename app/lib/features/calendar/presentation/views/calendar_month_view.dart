import 'package:flutter/material.dart';
import '../../data/calendar_repository.dart';

class CalendarMonthView extends StatelessWidget {
  final DateTime date;
  final List<CalendarEvent> events;

  const CalendarMonthView({super.key, required this.date, required this.events});

  @override
  Widget build(BuildContext context) {
    final firstDayOfMonth = DateTime(date.year, date.month, 1);
    final daysInMonth = DateTime(date.year, date.month + 1, 0).day;
    final firstWeekday = firstDayOfMonth.weekday; // 1 = Monday, 7 = Sunday
    
    // offset so Monday is the first column
    final offset = firstWeekday - 1;
    final totalCells = ((daysInMonth + offset) / 7).ceil() * 7;

    return Column(
      children: [
        _buildDaysOfWeek(),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.0,
            ),
            itemCount: totalCells,
            itemBuilder: (context, index) {
              if (index < offset || index >= daysInMonth + offset) {
                return Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white12, width: 0.5),
                    color: Colors.black12,
                  ),
                );
              }
              final day = index - offset + 1;
              final cellDate = DateTime(date.year, date.month, day);
              final dayEvents = events.where((e) => e.startTime.day == day && e.startTime.month == date.month).toList();
              
              return Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white12, width: 0.5),
                ),
                padding: const EdgeInsets.all(4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      day.toString(),
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    ...dayEvents.take(3).map((e) => _buildEventIndicator(e)),
                    if (dayEvents.length > 3)
                      Text('+${dayEvents.length - 3} more', style: const TextStyle(color: Colors.white38, fontSize: 10)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDaysOfWeek() {
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      children: days.map((d) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(d, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ),
      )).toList(),
    );
  }

  Widget _buildEventIndicator(CalendarEvent event) {
    Color accent = Colors.white24;
    if (event.type == CalendarEventType.session) accent = const Color(0xFFC6F135);
    if (event.type == CalendarEventType.goal) accent = Colors.orangeAccent;
    if (event.type == CalendarEventType.task) accent = Colors.blueAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.2),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        event.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: accent, fontSize: 9),
      ),
    );
  }
}
