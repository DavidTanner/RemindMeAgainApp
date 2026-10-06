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
  });

  final String id;
  final String title;
  final String notes;
  final TaskStatus status;
  final DateTime? completedAt;
  final DateTime? dueDate;
  final bool isAllDay;

  bool get isCompleted => status == TaskStatus.completed;

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
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      isAllDay: isAllDay ?? this.isAllDay,
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
