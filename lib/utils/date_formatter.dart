/// Utilities for formatting task due dates, times, and completion timestamps.
class TaskDateFormatter {
  const TaskDateFormatter._();

  static const List<String> _weekdays = <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  static const List<String> _months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// Formats a [DateTime] into a short calendar date string relative to [now].
  /// Examples: "Today", "Tomorrow", "Yesterday", "Mon, Oct 12", "Oct 12, 2027".
  static String formatRelativeDate(DateTime date, {DateTime? now}) {
    final DateTime reference = now ?? DateTime.now();
    final DateTime today = DateTime(
      reference.year,
      reference.month,
      reference.day,
    );
    final DateTime target = DateTime(date.year, date.month, date.day);
    final int dayDiff = target.difference(today).inDays;

    if (dayDiff == 0) {
      return 'Today';
    } else if (dayDiff == 1) {
      return 'Tomorrow';
    } else if (dayDiff == -1) {
      return 'Yesterday';
    }

    final String weekday = _weekdays[date.weekday - 1];
    final String month = _months[date.month - 1];
    if (date.year == reference.year) {
      return '$weekday, $month ${date.day}';
    }
    return '$month ${date.day}, ${date.year}';
  }

  /// Formats a [DateTime] into a 12-hour time string (e.g., "2:30 PM").
  static String formatTime(DateTime dateTime) {
    final int hour24 = dateTime.hour;
    final int minute = dateTime.minute;
    final String period = hour24 >= 12 ? 'PM' : 'AM';
    final int hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final String minutePadded = minute.toString().padLeft(2, '0');
    return '$hour12:$minutePadded $period';
  }

  /// Formats a task's due date, indicating either "All day" or the specific time.
  /// Examples:
  /// - "Today • All day"
  /// - "Today • 5:00 PM"
  /// - "Tomorrow • 9:30 AM"
  /// - "Fri, Oct 9 • All day"
  static String formatDueDate(
    DateTime dueDate, {
    required bool isAllDay,
    DateTime? now,
  }) {
    final String datePart = formatRelativeDate(dueDate, now: now);
    if (isAllDay) {
      return '$datePart • All day';
    }
    final String timePart = formatTime(dueDate);
    return '$datePart • $timePart';
  }

  /// Formats a completion timestamp including both the date and time.
  /// Example: "Completed Today at 2:15 PM" or "Completed Yesterday at 4:00 PM".
  static String formatCompletedTimestamp(
    DateTime completedAt, {
    DateTime? now,
  }) {
    final String datePart = formatRelativeDate(completedAt, now: now);
    final String timePart = formatTime(completedAt);
    return 'Completed $datePart at $timePart';
  }

  /// Formats an explicit calendar date (e.g., "Mon, Oct 5, 2026") for form pickers.
  static String formatFullDate(DateTime date) {
    final String weekday = _weekdays[date.weekday - 1];
    final String month = _months[date.month - 1];
    return '$weekday, $month ${date.day}, ${date.year}';
  }
}
