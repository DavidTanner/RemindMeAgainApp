import 'package:flutter/material.dart';

/// Represents the current status of a [Task].
enum TaskStatus {
  active,
  completed;

  String get label {
    switch (this) {
      case TaskStatus.active:
        return 'Active';
      case TaskStatus.completed:
        return 'Completed';
    }
  }
}

/// Filter options for viewing tasks on the main screen.
enum TaskFilter {
  all,
  active,
  completed;

  String get label {
    switch (this) {
      case TaskFilter.all:
        return 'All';
      case TaskFilter.active:
        return 'Active';
      case TaskFilter.completed:
        return 'Completed';
    }
  }
}

/// Date-based grouping sections for organizing tasks.
enum TaskDateGroup {
  overdue,
  today,
  tomorrow,
  upcoming,
  noDueDate,
  completed;

  String get title {
    switch (this) {
      case TaskDateGroup.overdue:
        return 'Overdue';
      case TaskDateGroup.today:
        return 'Today';
      case TaskDateGroup.tomorrow:
        return 'Tomorrow';
      case TaskDateGroup.upcoming:
        return 'Upcoming';
      case TaskDateGroup.noDueDate:
        return 'No Due Date';
      case TaskDateGroup.completed:
        return 'Completed';
    }
  }

  IconData get icon {
    switch (this) {
      case TaskDateGroup.overdue:
        return Icons.warning_amber_rounded;
      case TaskDateGroup.today:
        return Icons.today_rounded;
      case TaskDateGroup.tomorrow:
        return Icons.wb_sunny_outlined;
      case TaskDateGroup.upcoming:
        return Icons.calendar_month_rounded;
      case TaskDateGroup.noDueDate:
        return Icons.inbox_rounded;
      case TaskDateGroup.completed:
        return Icons.task_alt_rounded;
    }
  }
}

/// Immutable model representing a task in Remind Me Again.
@immutable
class Task {
  const Task({
    required this.id,
    required this.title,
    this.notes = '',
    this.status = TaskStatus.active,
    this.completedAt,
    this.dueDate,
    this.isAllDay = true,
    bool? hasAlarm,
    this.snoozedUntil,
    this.snoozeDurationMinutes = defaultSnoozeMinutes,
    this.snoozeCount = 0,
    this.alarmDismissed = false,
  }) : hasAlarm = hasAlarm ?? (!isAllDay && dueDate != null);

  /// Default snooze duration in minutes when an alarm is snoozed.
  static const int defaultSnoozeMinutes = 10;

  /// Standard preset snooze durations in minutes available to the user.
  static const List<int> presetSnoozeMinutes = <int>[5, 10, 15, 30, 60];

  final String id;
  final String title;
  final String notes;
  final TaskStatus status;
  final DateTime? completedAt;
  final DateTime? dueDate;
  final bool isAllDay;
  final bool hasAlarm;
  final DateTime? snoozedUntil;
  final int snoozeDurationMinutes;
  final int snoozeCount;
  final bool alarmDismissed;

  bool get isCompleted => status == TaskStatus.completed;

  /// Configured snooze [Duration] for this task's alarm.
  Duration get snoozeDuration => Duration(minutes: snoozeDurationMinutes);

  /// The scheduled [DateTime] when this task's alarm should trigger,
  /// accounting for any active snooze.
  DateTime? get effectiveAlarmTime {
    if (!hasAlarm || isCompleted) {
      return null;
    }
    if (snoozedUntil != null) {
      return snoozedUntil;
    }
    if (dueDate == null) {
      return null;
    }
    if (isAllDay) {
      return DateTime(dueDate!.year, dueDate!.month, dueDate!.day, 9, 0);
    }
    return dueDate;
  }

  /// Returns true if the task has an active snooze scheduled in the future
  /// relative to [now].
  bool isSnoozed(DateTime now) {
    return !isCompleted &&
        hasAlarm &&
        snoozedUntil != null &&
        snoozedUntil!.isAfter(now);
  }

  /// Returns true if the task's alarm is enabled, not dismissed, and its
  /// [effectiveAlarmTime] has been reached or passed relative to [now].
  bool isAlarmRinging(DateTime now) {
    if (isCompleted || !hasAlarm || alarmDismissed) {
      return false;
    }
    final DateTime? alarmTime = effectiveAlarmTime;
    if (alarmTime == null) {
      return false;
    }
    return !alarmTime.isAfter(now);
  }

  /// Returns true if the task is active and its due date/time has passed
  /// relative to [now].
  bool isOverdue(DateTime now) {
    if (isCompleted || dueDate == null) {
      return false;
    }
    if (isSnoozed(now)) {
      return false;
    }
    final DateTime due = dueDate!;
    if (isAllDay) {
      final DateTime todayStart = DateTime(now.year, now.month, now.day);
      final DateTime dueDayStart = DateTime(due.year, due.month, due.day);
      return dueDayStart.isBefore(todayStart);
    }
    return due.isBefore(now);
  }

  /// Determines which [TaskDateGroup] this task belongs to relative to [now].
  TaskDateGroup dateGroup(DateTime now) {
    if (isCompleted) {
      return TaskDateGroup.completed;
    }
    if (dueDate == null && snoozedUntil == null) {
      return TaskDateGroup.noDueDate;
    }
    if (isOverdue(now)) {
      return TaskDateGroup.overdue;
    }
    final DateTime referenceDate = (isSnoozed(now) ? snoozedUntil : dueDate)!;
    final DateTime todayStart = DateTime(now.year, now.month, now.day);
    final DateTime tomorrowStart = todayStart.add(const Duration(days: 1));
    final DateTime dayAfterTomorrowStart = todayStart.add(
      const Duration(days: 2),
    );
    final DateTime dueDay = DateTime(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day,
    );

    if (dueDay.isAtSameMomentAs(todayStart)) {
      return TaskDateGroup.today;
    }
    if (dueDay.isAtSameMomentAs(tomorrowStart)) {
      return TaskDateGroup.tomorrow;
    }
    if (!dueDay.isBefore(dayAfterTomorrowStart)) {
      return TaskDateGroup.upcoming;
    }
    return TaskDateGroup.today;
  }

  /// Creates a copy of this [Task] with the given fields updated.
  Task copyWith({
    String? id,
    String? title,
    String? notes,
    TaskStatus? status,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    DateTime? dueDate,
    bool clearDueDate = false,
    bool? isAllDay,
    bool? hasAlarm,
    DateTime? snoozedUntil,
    bool clearSnoozedUntil = false,
    int? snoozeDurationMinutes,
    int? snoozeCount,
    bool? alarmDismissed,
  }) {
    final bool updatedIsAllDay = isAllDay ?? this.isAllDay;
    final DateTime? updatedDueDate = clearDueDate
        ? null
        : (dueDate ?? this.dueDate);
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      dueDate: updatedDueDate,
      isAllDay: updatedIsAllDay,
      hasAlarm: hasAlarm ?? this.hasAlarm,
      snoozedUntil: clearSnoozedUntil
          ? null
          : (snoozedUntil ?? this.snoozedUntil),
      snoozeDurationMinutes:
          snoozeDurationMinutes ?? this.snoozeDurationMinutes,
      snoozeCount: snoozeCount ?? this.snoozeCount,
      alarmDismissed: alarmDismissed ?? this.alarmDismissed,
    );
  }

  /// Snoozes the task's alarm by [duration] (or [snoozeDuration] if omitted)
  /// relative to [now], scheduling a new [snoozedUntil] timestamp.
  Task snooze({Duration? duration, DateTime? now}) {
    final DateTime timestamp = now ?? DateTime.now();
    final Duration effectiveDuration = duration ?? snoozeDuration;
    final int minutes = effectiveDuration.inMinutes > 0
        ? effectiveDuration.inMinutes
        : snoozeDurationMinutes;
    return copyWith(
      hasAlarm: true,
      snoozedUntil: timestamp.add(effectiveDuration),
      snoozeDurationMinutes: minutes,
      snoozeCount: snoozeCount + 1,
      alarmDismissed: false,
    );
  }

  /// Dismisses the currently ringing or snoozed alarm without completing the task.
  Task dismissAlarm() {
    return copyWith(alarmDismissed: true, clearSnoozedUntil: true);
  }

  /// Toggles the task between [TaskStatus.active] and [TaskStatus.completed],
  /// updating [completedAt] accordingly.
  Task toggleStatus({DateTime? now}) {
    final DateTime timestamp = now ?? DateTime.now();
    if (isCompleted) {
      return copyWith(
        status: TaskStatus.active,
        clearCompletedAt: true,
        alarmDismissed: false,
      );
    } else {
      return copyWith(
        status: TaskStatus.completed,
        completedAt: timestamp,
        clearSnoozedUntil: true,
        alarmDismissed: false,
      );
    }
  }
}
