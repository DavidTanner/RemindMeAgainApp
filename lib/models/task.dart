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
/// Declaration order determines the order of the filter chips on screen.
enum TaskFilter {
  active,
  completed,
  all;

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

/// Where the time-of-day portion of a timed task's [Task.dueDate] came from.
///
/// Useful when debugging what Google Tasks actually returned for a task that
/// was given a time in Google Calendar.
enum DueTimeSource {
  /// The task is all-day; no time-of-day is known.
  none,

  /// The time was reconstructed from the `[remind_me_again:due_time=HH:mm]`
  /// tag this app stores in the task notes.
  notesTag,

  /// The Google Tasks API `due` timestamp itself carried a non-midnight
  /// time-of-day.
  dueTimestamp;

  String get label {
    switch (this) {
      case DueTimeSource.none:
        return 'None (all-day)';
      case DueTimeSource.notesTag:
        return 'Notes tag [remind_me_again:due_time]';
      case DueTimeSource.dueTimestamp:
        return 'API "due" timestamp';
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
    this.dueTimeSource = DueTimeSource.none,
    this.rawJson,
  });

  final String id;
  final String title;
  final String notes;
  final TaskStatus status;
  final DateTime? completedAt;
  final DateTime? dueDate;
  final bool isAllDay;

  /// Where the time-of-day in [dueDate] was sourced from (see [DueTimeSource]).
  final DueTimeSource dueTimeSource;

  /// The most recent raw Google Tasks API JSON for this task, if it came from
  /// the API. Kept for the in-app debug view; `null` for local-only tasks.
  final Map<String, dynamic>? rawJson;

  bool get isCompleted => status == TaskStatus.completed;

  /// The moment this task should start showing up as active.
  ///
  /// For timed tasks this is the due date-time itself. For all-day tasks it is
  /// the start of the due day. Tasks without a due date are active immediately
  /// and return `null`.
  DateTime? get activatesAt {
    final DateTime? due = dueDate;
    if (due == null) {
      return null;
    }
    if (isAllDay) {
      return DateTime(due.year, due.month, due.day);
    }
    return due;
  }

  /// Returns true if the task is active but its [activatesAt] moment is still
  /// in the future relative to [now].
  bool isPendingActivation(DateTime now) {
    final DateTime? activation = activatesAt;
    if (isCompleted || activation == null) {
      return false;
    }
    return now.isBefore(activation);
  }

  /// Returns true if the task is active and its due date/time has passed
  /// relative to [now].
  bool isOverdue(DateTime now) {
    if (isCompleted || dueDate == null) {
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
    if (dueDate == null) {
      return TaskDateGroup.noDueDate;
    }
    if (isOverdue(now)) {
      return TaskDateGroup.overdue;
    }
    final DateTime todayStart = DateTime(now.year, now.month, now.day);
    final DateTime tomorrowStart = todayStart.add(const Duration(days: 1));
    final DateTime dayAfterTomorrowStart = todayStart.add(
      const Duration(days: 2),
    );
    final DateTime dueDay = DateTime(
      dueDate!.year,
      dueDate!.month,
      dueDate!.day,
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
    DueTimeSource? dueTimeSource,
    Map<String, dynamic>? rawJson,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      isAllDay: isAllDay ?? this.isAllDay,
      dueTimeSource: dueTimeSource ?? this.dueTimeSource,
      rawJson: rawJson ?? this.rawJson,
    );
  }

  /// Toggles the task between [TaskStatus.active] and [TaskStatus.completed],
  /// updating [completedAt] accordingly.
  Task toggleStatus({DateTime? now}) {
    final DateTime timestamp = now ?? DateTime.now();
    if (isCompleted) {
      return copyWith(status: TaskStatus.active, clearCompletedAt: true);
    } else {
      return copyWith(status: TaskStatus.completed, completedAt: timestamp);
    }
  }
}
