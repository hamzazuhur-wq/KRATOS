import 'package:flutter/material.dart';
import '../../../../app/kratos_theme.dart';
import '../../../../app/kratos_visuals.dart';
import '../calendar/presentation/views/calendar_day_view.dart';
import '../calendar/presentation/views/calendar_week_view.dart';
import '../calendar/presentation/views/calendar_month_view.dart';
import '../calendar/data/calendar_repository.dart';

class Wave10CalendarStorybookScreen extends StatelessWidget {
  const Wave10CalendarStorybookScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mockEvents = [
      CalendarEvent(
        id: '1',
        title: 'Review product architecture',
        type: CalendarEventType.task,
        startTime: DateTime.now().add(const Duration(hours: 1)),
        subtitle: 'Project / KRATOS',
      ),
      CalendarEvent(
        id: '2',
        title: 'Deep focus',
        type: CalendarEventType.session,
        startTime: DateTime.now().add(const Duration(hours: 3)),
        endTime: DateTime.now().add(const Duration(hours: 4)),
        subtitle: 'Activity',
      ),
      CalendarEvent(
        id: '3',
        title: 'Quarterly OKRs',
        type: CalendarEventType.goal,
        startTime: DateTime.now().add(const Duration(days: 2)),
        subtitle: 'Goal Deadline',
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.black, // Dark volcanic undertones
      appBar: AppBar(
        title: const Text('Wave 10 - Calendar Previews'),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Day View', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Container(
                height: 400,
                decoration: BoxDecoration(border: Border.all(color: Colors.white12)),
                child: CalendarDayView(date: DateTime.now(), events: mockEvents),
              ),
              const SizedBox(height: 32),

              const Text('Week View', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Container(
                height: 400,
                decoration: BoxDecoration(border: Border.all(color: Colors.white12)),
                child: CalendarWeekView(date: DateTime.now(), events: mockEvents),
              ),
              const SizedBox(height: 32),

              const Text('Month View', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Container(
                height: 400,
                decoration: BoxDecoration(border: Border.all(color: Colors.white12)),
                child: CalendarMonthView(date: DateTime.now(), events: mockEvents),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
