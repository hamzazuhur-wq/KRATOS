/// Formatting utilities for Focus Time analytics and UI.
abstract final class FocusTimeFormatters {
  static const List<String> weekdaysShort = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  static const List<String> weekdaysFull = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  /// Formats milliseconds into human-readable e.g. "12h 45m", "2h 8m", "45m", "0m".
  static String formatDurationHhMm(int ms) {
    if (ms <= 0) return '0m';
    final totalMinutes = (ms / 60000).round();
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (hours > 0 && minutes > 0) {
      return '${hours}h ${minutes}m';
    } else if (hours > 0) {
      return '${hours}h';
    } else {
      return '${minutes}m';
    }
  }

  /// Formats milliseconds into short hours decimal e.g. "12.8h" or "45m".
  static String formatDurationShort(int ms) {
    if (ms <= 0) return '0m';
    final totalMinutes = (ms / 60000).round();
    if (totalMinutes < 60) return '${totalMinutes}m';
    final hours = totalMinutes / 60.0;
    return '${hours.toStringAsFixed(1)}h';
  }

  /// Formats a 0-based weekday index (0 = Monday, 6 = Sunday) to short abbreviation.
  static String weekdayShort(int index) {
    if (index < 0 || index >= weekdaysShort.length) return '';
    return weekdaysShort[index];
  }

  /// Formats a 0-based weekday index (0 = Monday, 6 = Sunday) to full name.
  static String weekdayFull(int index) {
    if (index < 0 || index >= weekdaysFull.length) return '';
    return weekdaysFull[index];
  }

  /// Formats start hour into 2-hour window e.g. "10:00 AM – 12:00 PM".
  static String formatHourWindow(int? startHour) {
    if (startHour == null) return 'No data';
    final sH = startHour % 24;
    final eH = (startHour + 2) % 24;

    String formatSingle(int h) {
      final period = h >= 12 ? 'PM' : 'AM';
      var dH = h % 12;
      if (dH == 0) dH = 12;
      return '$dH:00 $period';
    }

    return '${formatSingle(sH)} – ${formatSingle(eH)}';
  }

  /// Formats hour index (0..23) into compact label e.g. "12 AM", "6 AM", "12 PM", "6 PM".
  static String formatHour12(int hour) {
    final h = hour % 24;
    if (h == 0) return '12 AM';
    if (h == 12) return '12 PM';
    if (h < 12) return '$h AM';
    return '${h - 12} PM';
  }

  /// Formats a percentage trend with sign e.g. "↑ 24%" or "↓ 12%".
  static String formatTrend(double? trendPercent) {
    if (trendPercent == null) return '—';
    final isPos = trendPercent >= 0;
    final arrow = isPos ? '↑' : '↓';
    return '$arrow ${trendPercent.abs().toStringAsFixed(0)}%';
  }
}
