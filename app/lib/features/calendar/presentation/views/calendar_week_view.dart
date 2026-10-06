import 'package:flutter/material.dart';
import '../../data/calendar_repository.dart';
import 'calendar_day_view.dart';

class CalendarWeekView extends StatelessWidget {
  final DateTime date;
  final List<CalendarEvent> events;

  const CalendarWeekView({super.key, required this.date, required this.events});

  @override
  Widget build(BuildContext context) {
    // Find Monday
    int diff = date.weekday - 1;
    final monday = date.subtract(Duration(days: diff));

    return Column(
      children: [
        Row(
          children: List.generate(7, (i) {
            final day = monday.add(Duration(days: i));
            return Expanded(
              child: Container(
                padding: const EdgeInsets.all(8.0),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.white12)),
                ),
                child: Column(
                  children: [
                    Text(
                      _weekdayInitial(day.weekday),
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    Text(
                      day.day.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
        Expanded(
          child: Row(
            children: List.generate(7, (i) {
              final day = monday.add(Duration(days: i));
              return Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(right: i < 6 ? const BorderSide(color: Colors.white12) : BorderSide.none),
                  ),
                  child: CalendarDayView(
                    date: day,
                    events: events,
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  String _weekdayInitial(int weekday) {
    switch (weekday) {
      case 1: return 'M';
      case 2: return 'T';
      case 3: return 'W';
      case 4: return 'T';
      case 5: return 'F';
      case 6: return 'S';
      case 7: return 'S';
      default: return '';
    }
  }
}
