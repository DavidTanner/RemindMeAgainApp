import 'dart:convert';

import 'package:googleapis/tasks/v1.dart' as gtasks;
import 'package:http/http.dart' as http;

import '../models/task.dart';
import 'task_repository.dart';

/// Off-device [TaskRepository] implementation backed by the Google Tasks REST API.
class GoogleTasksRepository implements TaskRepository {
  GoogleTasksRepository({
    required this.tasksApi,
    this.taskListId = defaultTaskListId,
    this.httpClient,
    this.rootUrl = defaultRootUrl,
  });

  /// Identifier for the authenticated user's default Google Tasks list.
  static const String defaultTaskListId = '@default';

  /// Base URL of the Google Tasks REST API.
  static const String defaultRootUrl = 'https://tasks.googleapis.com/';

  static final RegExp _dueTimeTagPattern = RegExp(
    r'(?:\r?\n)*\[remind_me_again:due_time=(\d{2}):(\d{2})\]\s*$',
  );

  final gtasks.TasksApi tasksApi;
  final String taskListId;

  /// Optional authenticated HTTP client. When provided, [fetchTaskJson]
  /// performs a verbatim `GET` against the REST endpoint so the debug view
  /// shows exactly what Google returned, including any fields the generated
  /// [gtasks.Task] model does not know about.
  final http.Client? httpClient;
  final String rootUrl;

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

  @override
  Future<Map<String, dynamic>?> fetchTaskJson(String taskId) async {
    final http.Client? client = httpClient;
    if (client == null) {
      final gtasks.Task remote = await tasksApi.tasks.get(taskListId, taskId);
      return remote.toJson();
    }

    final Uri uri = Uri.parse(
      '${rootUrl}tasks/v1/lists/${Uri.encodeComponent(taskListId)}'
      '/tasks/${Uri.encodeComponent(taskId)}',
    );
    final http.Response response = await client.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Google Tasks API returned HTTP ${response.statusCode}: '
        '${response.body}',
        uri,
      );
    }
    final Object? decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw const FormatException(
      'Google Tasks API response was not a JSON object',
    );
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

    final DecodedDue decoded = decodeNotesAndDueDate(
      rawNotes: remote.notes,
      rawDue: remote.due,
    );

    return Task(
      id: remote.id ?? fallbackId ?? '',
      title: remote.title ?? '',
      notes: decoded.notes,
      status: isCompleted ? TaskStatus.completed : TaskStatus.active,
      completedAt: completedAt,
      dueDate: decoded.dueDate,
      isAllDay: decoded.isAllDay,
      dueTimeSource: decoded.dueTimeSource,
      rawJson: remote.toJson(),
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
  ///
  /// Precedence for the time-of-day:
  /// 1. A non-midnight (UTC) time inside the `due` timestamp. The Google Tasks
  ///    API documents that it discards the time portion, so today this is
  ///    always `T00:00:00.000Z`, but if Google ever starts returning the time
  ///    set in Google Calendar it is honoured here automatically.
  /// 2. The `[remind_me_again:due_time=HH:mm]` tag this app writes to notes.
  /// 3. Otherwise the task is treated as all-day on the `due` calendar date.
  static DecodedDue decodeNotesAndDueDate({
    required String? rawNotes,
    required String? rawDue,
  }) {
    final String sourceNotes = rawNotes ?? '';
    final RegExpMatch? match = _dueTimeTagPattern.firstMatch(sourceNotes);

    final String cleanNotes = match != null
        ? sourceNotes.substring(0, match.start).trim()
        : sourceNotes.trim();

    if (rawDue == null || rawDue.isEmpty) {
      return DecodedDue(notes: cleanNotes);
    }

    final DateTime? parsedDue = DateTime.tryParse(rawDue)?.toUtc();
    if (parsedDue == null) {
      return DecodedDue(notes: cleanNotes);
    }

    final bool dueCarriesTime =
        parsedDue.hour != 0 ||
        parsedDue.minute != 0 ||
        parsedDue.second != 0 ||
        parsedDue.millisecond != 0;
    if (dueCarriesTime) {
      final DateTime local = parsedDue.toLocal();
      return DecodedDue(
        notes: cleanNotes,
        dueDate: DateTime(
          local.year,
          local.month,
          local.day,
          local.hour,
          local.minute,
        ),
        isAllDay: false,
        dueTimeSource: DueTimeSource.dueTimestamp,
      );
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
        return DecodedDue(
          notes: cleanNotes,
          dueDate: DateTime(
            parsedDue.year,
            parsedDue.month,
            parsedDue.day,
            hour,
            minute,
          ),
          isAllDay: false,
          dueTimeSource: DueTimeSource.notesTag,
        );
      }
    }

    return DecodedDue(
      notes: cleanNotes,
      dueDate: DateTime(parsedDue.year, parsedDue.month, parsedDue.day),
    );
  }
}

/// Result of [GoogleTasksRepository.decodeNotesAndDueDate].
class DecodedDue {
  const DecodedDue({
    required this.notes,
    this.dueDate,
    this.isAllDay = true,
    this.dueTimeSource = DueTimeSource.none,
  });

  final String notes;
  final DateTime? dueDate;
  final bool isAllDay;
  final DueTimeSource dueTimeSource;
}
