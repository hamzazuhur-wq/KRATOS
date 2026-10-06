import 'package:flutter/material.dart';

import '../../../../app/kratos_theme.dart';
import '../../../../app/kratos_visuals.dart';
import '../../../../data/drift/app_database.dart';
import '../data/calendar_repository.dart';
import 'views/calendar_day_view.dart';
import 'views/calendar_week_view.dart';
import 'views/calendar_month_view.dart';

enum CalendarViewType { day, week, month }

class CalendarScreen extends StatefulWidget {
  final AppDatabase database;
  final String ownerId;

  const CalendarScreen({
    super.key,
    required this.database,
    required this.ownerId,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late final CalendarRepository _repository;
  CalendarViewType _currentView = CalendarViewType.week;
  DateTime _currentDate = DateTime.now();
  List<CalendarEvent> _events = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _repository = CalendarRepository(database: widget.database);
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    
    // Load a window based on view type
    DateTime start;
    DateTime end;
    
    if (_currentView == CalendarViewType.day) {
      start = DateTime(_currentDate.year, _currentDate.month, _currentDate.day);
      end = start.add(const Duration(days: 1));
    } else if (_currentView == CalendarViewType.week) {
      // Find Monday
      int diff = _currentDate.weekday - 1;
      start = DateTime(_currentDate.year, _currentDate.month, _currentDate.day - diff);
      end = start.add(const Duration(days: 7));
    } else {
      start = DateTime(_currentDate.year, _currentDate.month, 1);
      end = DateTime(_currentDate.year, _currentDate.month + 1, 1);
      // add some buffer for week grid
      start = start.subtract(Duration(days: start.weekday - 1));
      end = end.add(Duration(days: 7 - (end.weekday == 7 ? 0 : end.weekday)));
    }

    final events = await _repository.fetchEvents(widget.ownerId, start, end);
    if (mounted) {
      setState(() {
        _events = events;
        _isLoading = false;
      });
    }
  }

  void _changeDate(int delta) {
    setState(() {
      if (_currentView == CalendarViewType.day) {
        _currentDate = _currentDate.add(Duration(days: delta));
      } else if (_currentView == CalendarViewType.week) {
        _currentDate = _currentDate.add(Duration(days: 7 * delta));
      } else {
        _currentDate = DateTime(_currentDate.year, _currentDate.month + delta, _currentDate.day);
      }
    });
    _loadEvents();
  }
  
  void _jumpToToday() {
    setState(() {
      _currentDate = DateTime.now();
    });
    _loadEvents();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Parent handles background
      body: Column(
        children: [
          _buildHeader(),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator(color: Color(0xFFC6F135))))
          else if (_currentView == CalendarViewType.day)
            Expanded(child: CalendarDayView(date: _currentDate, events: _events))
          else if (_currentView == CalendarViewType.week)
            Expanded(child: CalendarWeekView(date: _currentDate, events: _events))
          else
            Expanded(child: CalendarMonthView(date: _currentDate, events: _events)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    String dateLabel = '';
    if (_currentView == CalendarViewType.day) {
      dateLabel = '${_currentDate.year}-${_currentDate.month.toString().padLeft(2, '0')}-${_currentDate.day.toString().padLeft(2, '0')}';
    } else if (_currentView == CalendarViewType.week) {
      int diff = _currentDate.weekday - 1;
      final start = _currentDate.subtract(Duration(days: diff));
      dateLabel = 'Week of ${start.month}/${start.day}';
    } else {
      dateLabel = '${_currentDate.year} - ${_currentDate.month.toString().padLeft(2, '0')}';
    }

    return KratosGlassCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: Colors.white70),
                  onPressed: () => _changeDate(-1),
                ),
                Text(
                  dateLabel,
                  style: const TextStyle(
                    fontFamily: 'Mona Sans',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: Colors.white70),
                  onPressed: () => _changeDate(1),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _jumpToToday,
                  child: const Text('Today', style: TextStyle(color: Color(0xFFC6F135))),
                )
              ],
            ),
            Row(
              children: [
                _buildViewToggle(CalendarViewType.day, 'Day'),
                const SizedBox(width: 8),
                _buildViewToggle(CalendarViewType.week, 'Week'),
                const SizedBox(width: 8),
                _buildViewToggle(CalendarViewType.month, 'Month'),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildViewToggle(CalendarViewType type, String label) {
    final isActive = _currentView == type;
    return GestureDetector(
      onTap: () {
        if (_currentView != type) {
          setState(() => _currentView = type);
          _loadEvents();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFC6F135).withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive ? const Color(0xFFC6F135).withOpacity(0.5) : Colors.white12,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isActive ? const Color(0xFFC6F135) : Colors.white54,
          ),
        ),
      ),
    );
  }
}

