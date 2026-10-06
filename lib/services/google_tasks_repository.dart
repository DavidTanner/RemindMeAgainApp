import 'package:googleapis/tasks/v1.dart' as gtasks;

import '../models/task.dart';
import 'task_repository.dart';

/// Off-device [TaskRepository] implementation backed by the Google Tasks REST API.
class GoogleTasksRepository implements TaskRepository {
  GoogleTasksRepository({
    required this.tasksApi,
    this.taskListId = defaultTaskListId,
  });

  /// Identifier for the authenticated user's default Google Tasks list.
  static const String defaultTaskListId = '@default';

  static final RegExp _dueTimeTagPattern = RegExp(
    r'(?:\r?\n)*\[remind_me_again:due_time=(\d{2}):(\d{2})\]\s*$',
  );

  final gtasks.TasksApi tasksApi;
  final String taskListId;

  @override
  Future<List<Task>> fetchTasks() async {
    final List<Task> results = <Task>[];
    String? pageToken;

    do {
      final gtasks.Tasks response = await tasksApi.tasks.list(
        taskListId,
        maxResults: 100,
        pageToken: pageToken,
        showCompleted: true,
        showHidden: true,
        showDeleted: false,
      );

      final List<gtasks.Task>? items = response.items;
      if (items != null) {
        for (final gtasks.Task item in items) {
          if (item.deleted == true || item.id == null || item.id!.isEmpty) {
            continue;
          }
          results.add(fromGoogleTask(item));
        }
      }

      pageToken = response.nextPageToken;
    } while (pageToken != null && pageToken.isNotEmpty);

    return results;
  }

  @override
  Future<Task> createTask(Task task) async {
    final gtasks.Task request = toGoogleTask(task, includeId: false);
    final gtasks.Task created = await tasksApi.tasks.insert(
      request,
      taskListId,
    );
    return fromGoogleTask(created, fallbackId: task.id);
  }

  @override
  Future<Task> updateTask(Task task) async {
    final gtasks.Task request = toGoogleTask(task, includeId: true);
    final gtasks.Task updated = await tasksApi.tasks.update(
      request,
      taskListId,
      task.id,
    );
    return fromGoogleTask(updated, fallbackId: task.id);
  }

  @override
  Future<void> deleteTask(String taskId) async {
    await tasksApi.tasks.delete(taskListId, taskId);
  }

  /// Converts a domain [Task] into a Google Tasks API [gtasks.Task].
  ///
  /// Because the Google Tasks API `due` field only persists the calendar date
  /// (discarding the time-of-day portion), timed tasks (`isAllDay == false`)
  /// also embed a `[remind_me_again:due_time=HH:mm]` metadata tag in `notes`.
  static gtasks.Task toGoogleTask(Task task, {bool includeId = true}) {
    final String? dueRfc3339 = task.dueDate != null
        ? DateTime.utc(
            task.dueDate!.year,
            task.dueDate!.month,
            task.dueDate!.day,
          ).toIso8601String()
        : null;

    final String? completedRfc3339 =
        task.isCompleted && task.completedAt != null
        ? task.completedAt!.toUtc().toIso8601String()
        : null;

    final String encodedNotes = encodeNotes(
      task.notes,
      dueDate: task.dueDate,
      isAllDay: task.isAllDay,
    );

    return gtasks.Task(
      id: includeId ? task.id : null,
      title: task.title,
      notes: encodedNotes,
      status: task.isCompleted ? 'completed' : 'needsAction',
      due: dueRfc3339,
      completed: completedRfc3339,
    );
  }

  /// Converts a Google Tasks API [gtasks.Task] into a domain [Task].
  static Task fromGoogleTask(gtasks.Task remote, {String? fallbackId}) {
    final bool isCompleted = remote.status == 'completed';
    final DateTime? completedAt = isCompleted && remote.completed != null
        ? DateTime.tryParse(remote.completed!)?.toLocal()
        : null;

    final ({String notes, DateTime? dueDate, bool isAllDay}) decoded =
        decodeNotesAndDueDate(rawNotes: remote.notes, rawDue: remote.due);

    return Task(
      id: remote.id ?? fallbackId ?? '',
      title: remote.title ?? '',
      notes: decoded.notes,
      status: isCompleted ? TaskStatus.completed : TaskStatus.active,
      completedAt: completedAt,
      dueDate: decoded.dueDate,
      isAllDay: decoded.isAllDay,
    );
  }

  /// Encodes user [notes] with an optional due-time metadata footer when
  /// [dueDate] is non-null and [isAllDay] is false.
  static String encodeNotes(
    String notes, {
    required DateTime? dueDate,
    required bool isAllDay,
  }) {
    final String cleanNotes = notes.replaceAll(_dueTimeTagPattern, '').trim();
    if (dueDate == null || isAllDay) {
      return cleanNotes;
    }

    final String hh = dueDate.hour.toString().padLeft(2, '0');
    final String mm = dueDate.minute.toString().padLeft(2, '0');
    final String tag = '[remind_me_again:due_time=$hh:$mm]';

    if (cleanNotes.isEmpty) {
      return tag;
    }
    return '$cleanNotes\n\n$tag';
  }

  /// Extracts user-visible notes and reconstructs [dueDate] and [isAllDay]
  /// from the Google Tasks `notes` and `due` fields.
  static ({String notes, DateTime? dueDate, bool isAllDay})
  decodeNotesAndDueDate({required String? rawNotes, required String? rawDue}) {
    final String sourceNotes = rawNotes ?? '';
    final RegExpMatch? match = _dueTimeTagPattern.firstMatch(sourceNotes);

    final String cleanNotes = match != null
        ? sourceNotes.substring(0, match.start).trim()
        : sourceNotes.trim();

    if (rawDue == null || rawDue.isEmpty) {
      return (notes: cleanNotes, dueDate: null, isAllDay: true);
    }

    final DateTime? parsedDue = DateTime.tryParse(rawDue)?.toUtc();
    if (parsedDue == null) {
      return (notes: cleanNotes, dueDate: null, isAllDay: true);
    }

    if (match != null) {
      final int? hour = int.tryParse(match.group(1)!);
      final int? minute = int.tryParse(match.group(2)!);
      if (hour != null &&
          minute != null &&
          hour >= 0 &&
          hour <= 23 &&
          minute >= 0 &&
          minute <= 59) {
        return (
          notes: cleanNotes,
          dueDate: DateTime(
            parsedDue.year,
            parsedDue.month,
            parsedDue.day,
            hour,
            minute,
          ),
          isAllDay: false,
        );
      }
    }

    return (
      notes: cleanNotes,
      dueDate: DateTime(parsedDue.year, parsedDue.month, parsedDue.day),
      isAllDay: true,
    );
  }
}
