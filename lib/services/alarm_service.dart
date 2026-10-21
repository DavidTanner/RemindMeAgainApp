import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/task.dart';

/// Types of user actions triggered from an alarm notification.
enum AlarmNotificationActionType {
  /// User tapped the notification body to open the alarm in the app.
  open,

  /// User tapped a snooze action button on the notification.
  snooze,

  /// User tapped the dismiss action button on the notification.
  dismiss,

  /// User tapped the complete/mark-done action button on the notification.
  complete,
}

/// Event emitted when the user interacts with an alarm notification.
@immutable
class AlarmActionEvent {
  const AlarmActionEvent({
    required this.taskId,
    required this.actionType,
    this.snoozeDuration,
  });

  final String taskId;
  final AlarmNotificationActionType actionType;
  final Duration? snoozeDuration;
}

/// Snapshot of a scheduled or active alarm tracked by [AlarmService].
@immutable
class ScheduledAlarmRecord {
  const ScheduledAlarmRecord({
    required this.notificationId,
    required this.taskId,
    required this.title,
    required this.body,
    required this.scheduledAt,
    required this.snoozeDurationMinutes,
    this.isRinging = false,
  });

  final int notificationId;
  final String taskId;
  final String title;
  final String body;
  final DateTime scheduledAt;
  final int snoozeDurationMinutes;
  final bool isRinging;

  ScheduledAlarmRecord copyWith({
    int? notificationId,
    String? taskId,
    String? title,
    String? body,
    DateTime? scheduledAt,
    int? snoozeDurationMinutes,
    bool? isRinging,
  }) {
    return ScheduledAlarmRecord(
      notificationId: notificationId ?? this.notificationId,
      taskId: taskId ?? this.taskId,
      title: title ?? this.title,
      body: body ?? this.body,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      snoozeDurationMinutes:
          snoozeDurationMinutes ?? this.snoozeDurationMinutes,
      isRinging: isRinging ?? this.isRinging,
    );
  }
}

/// Top-level background callback for handling notification actions when the
/// application is in the background or terminated.
@pragma('vm:entry-point')
Future<void> onBackgroundAlarmNotificationResponse(
  NotificationResponse response,
) async {
  await AlarmService.instance.handleNotificationResponse(
    response,
    isBackground: true,
  );
}

/// Service responsible for initializing local notifications, scheduling task
/// alarms, presenting immediate alarm notifications, and handling snooze,
/// dismiss, and completion actions.
class AlarmService {
  AlarmService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// Shared singleton instance used across the application.
  static AlarmService instance = AlarmService();

  /// Android notification channel identifier for high-priority task alarms.
  static const String alarmChannelId = 'remind_me_again_alarm_channel';

  /// Android notification channel display name.
  static const String alarmChannelName = 'Task Alarms';

  /// Android notification channel description.
  static const String alarmChannelDescription =
      'High-priority alarm notifications for scheduled tasks and reminders';

  /// Darwin (iOS/macOS) notification category identifier for alarms.
  static const String alarmCategoryId = 'remind_me_again_alarm_category';

  /// Notification action ID for snoozing an alarm by its default duration.
  static const String actionSnoozeId = 'snooze_alarm';

  /// Notification action ID prefix for preset snooze durations (e.g. snooze_5).
  static const String actionSnoozePrefix = 'snooze_';

  /// Notification action ID for dismissing an alarm.
  static const String actionDismissId = 'dismiss_alarm';

  /// Notification action ID for marking a task completed from the alarm.
  static const String actionCompleteId = 'complete_alarm';

  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<AlarmActionEvent> _actionController =
      StreamController<AlarmActionEvent>.broadcast();
  final Map<String, ScheduledAlarmRecord> _scheduledAlarms =
      <String, ScheduledAlarmRecord>{};

  bool _isInitialized = false;

  /// Stream of [AlarmActionEvent]s emitted when the user interacts with a
  /// system notification or notification action button.
  Stream<AlarmActionEvent> get actionStream => _actionController.stream;

  /// Read-only view of currently scheduled or ringing alarms keyed by task ID.
  Map<String, ScheduledAlarmRecord> get scheduledAlarms =>
      Map<String, ScheduledAlarmRecord>.unmodifiable(_scheduledAlarms);

  /// Whether the service has completed initialization.
  bool get isInitialized => _isInitialized;

  /// Computes a deterministic 31-bit positive notification ID for a [taskId].
  static int notificationIdForTask(String taskId) {
    int hash = 0;
    for (int i = 0; i < taskId.length; i++) {
      hash = (31 * hash + taskId.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    return hash == 0 ? 1 : hash;
  }

  /// Initializes timezone data and the underlying local notifications plugin.
  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }
    tz_data.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final List<DarwinNotificationCategory> darwinCategories =
        <DarwinNotificationCategory>[
          DarwinNotificationCategory(
            alarmCategoryId,
            actions: <DarwinNotificationAction>[
              DarwinNotificationAction.plain(
                actionSnoozeId,
                'Snooze',
                options: <DarwinNotificationActionOption>{
                  DarwinNotificationActionOption.foreground,
                },
              ),
              DarwinNotificationAction.plain(
                actionCompleteId,
                'Complete',
                options: <DarwinNotificationActionOption>{
                  DarwinNotificationActionOption.foreground,
                },
              ),
              DarwinNotificationAction.plain(
                actionDismissId,
                'Dismiss',
                options: <DarwinNotificationActionOption>{
                  DarwinNotificationActionOption.destructive,
                },
              ),
            ],
          ),
        ];

    final DarwinInitializationSettings darwinSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
          notificationCategories: darwinCategories,
        );

    const LinuxInitializationSettings linuxSettings =
        LinuxInitializationSettings(defaultActionName: 'Open alarm');

    final InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
      linux: linuxSettings,
    );

    try {
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          unawaited(handleNotificationResponse(response));
        },
        onDidReceiveBackgroundNotificationResponse:
            onBackgroundAlarmNotificationResponse,
      );
    } catch (_) {
      // Safe fallback when running in widget test environments without a
      // registered FlutterLocalNotificationsPlatform instance.
    }

    _isInitialized = true;
  }

  /// Requests runtime notification and exact alarm permissions from the OS.
  Future<bool> requestPermissions() async {
    if (!_isInitialized) {
      await initialize();
    }
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final AndroidFlutterLocalNotificationsPlugin? androidImpl = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        final bool? notifGranted = await androidImpl
            ?.requestNotificationsPermission();
        await androidImpl?.requestExactAlarmsPermission();
        return notifGranted ?? true;
      } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        final IOSFlutterLocalNotificationsPlugin? iosImpl = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        final bool? granted = await iosImpl?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? true;
      } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
        final MacOSFlutterLocalNotificationsPlugin? macImpl = _plugin
            .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin
            >();
        final bool? granted = await macImpl?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? true;
      }
    } catch (_) {
      return true;
    }
    return true;
  }

  /// Builds platform-specific [NotificationDetails] for a task alarm,
  /// including Snooze, Complete, and Dismiss action buttons.
  NotificationDetails _buildNotificationDetails({
    required int snoozeDurationMinutes,
  }) {
    final String snoozeLabel = 'Snooze ($snoozeDurationMinutes min)';

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          alarmChannelId,
          alarmChannelName,
          channelDescription: alarmChannelDescription,
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: true,
          playSound: true,
          enableVibration: true,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          visibility: NotificationVisibility.public,
          ticker: 'Task alarm',
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction(
              actionSnoozeId,
              snoozeLabel,
              showsUserInterface: true,
              cancelNotification: true,
            ),
            const AndroidNotificationAction(
              actionCompleteId,
              'Complete',
              showsUserInterface: true,
              cancelNotification: true,
            ),
            const AndroidNotificationAction(
              actionDismissId,
              'Dismiss',
              showsUserInterface: false,
              cancelNotification: true,
            ),
          ],
        );

    const DarwinNotificationDetails darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBanner: true,
      presentList: true,
      presentSound: true,
      categoryIdentifier: alarmCategoryId,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    return NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );
  }

  /// Encodes task metadata into a JSON payload string for notification actions.
  static String encodePayload({
    required String taskId,
    required String title,
    required String notes,
    required int snoozeMinutes,
  }) {
    return jsonEncode(<String, Object>{
      'taskId': taskId,
      'title': title,
      'notes': notes,
      'snoozeMinutes': snoozeMinutes,
    });
  }

  /// Decodes a notification payload string into its structured fields.
  static Map<String, Object?>? decodePayload(String? payload) {
    if (payload == null || payload.trim().isEmpty) {
      return null;
    }
    try {
      final Object? decoded = jsonDecode(payload);
      if (decoded is Map<String, Object?>) {
        return decoded;
      }
      if (decoded is Map<Object?, Object?>) {
        return decoded.map(
          (Object? key, Object? value) =>
              MapEntry<String, Object?>('$key', value),
        );
      }
    } on FormatException {
      return <String, Object?>{'taskId': payload};
    }
    return null;
  }

  /// Synchronizes the alarm notification schedule for a single [task].
  Future<void> scheduleTaskAlarm(Task task, {DateTime? now}) async {
    if (!_isInitialized) {
      await initialize();
    }

    final int notificationId = notificationIdForTask(task.id);
    if (!task.hasAlarm || task.isCompleted || task.alarmDismissed) {
      await cancelTaskAlarm(task.id);
      return;
    }

    final DateTime? alarmTime = task.effectiveAlarmTime;
    if (alarmTime == null) {
      await cancelTaskAlarm(task.id);
      return;
    }

    final DateTime referenceNow = now ?? DateTime.now();
    final String bodyText = task.notes.trim().isNotEmpty
        ? task.notes.trim()
        : 'Tap to open or snooze this reminder.';

    _scheduledAlarms[task.id] = ScheduledAlarmRecord(
      notificationId: notificationId,
      taskId: task.id,
      title: task.title,
      body: bodyText,
      scheduledAt: alarmTime,
      snoozeDurationMinutes: task.snoozeDurationMinutes,
      isRinging: !alarmTime.isAfter(referenceNow),
    );

    if (!alarmTime.isAfter(referenceNow)) {
      return;
    }

    final String payload = encodePayload(
      taskId: task.id,
      title: task.title,
      notes: task.notes,
      snoozeMinutes: task.snoozeDurationMinutes,
    );

    try {
      final tz.TZDateTime tzScheduled = _toTZDateTime(alarmTime);
      await _plugin.zonedSchedule(
        id: notificationId,
        title: 'Alarm: ${task.title}',
        body: bodyText,
        scheduledDate: tzScheduled,
        notificationDetails: _buildNotificationDetails(
          snoozeDurationMinutes: task.snoozeDurationMinutes,
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
    } catch (_) {
      // Ignored in test environments without native plugin implementation.
    }
  }

  /// Immediately displays a high-priority alarm notification for [task] and
  /// triggers system alert sound and haptic feedback.
  Future<void> triggerImmediateAlarm(Task task) async {
    if (!_isInitialized) {
      await initialize();
    }

    final int notificationId = notificationIdForTask(task.id);
    final String bodyText = task.notes.trim().isNotEmpty
        ? task.notes.trim()
        : 'Alarm is ringing now. Tap to snooze or complete.';

    _scheduledAlarms[task.id] = ScheduledAlarmRecord(
      notificationId: notificationId,
      taskId: task.id,
      title: task.title,
      body: bodyText,
      scheduledAt: task.effectiveAlarmTime ?? DateTime.now(),
      snoozeDurationMinutes: task.snoozeDurationMinutes,
      isRinging: true,
    );

    final String payload = encodePayload(
      taskId: task.id,
      title: task.title,
      notes: task.notes,
      snoozeMinutes: task.snoozeDurationMinutes,
    );

    try {
      await SystemSound.play(SystemSoundType.alert);
      await HapticFeedback.heavyImpact();
    } catch (_) {
      // Safe fallback in environments without sound/haptics channel.
    }

    try {
      await _plugin.show(
        id: notificationId,
        title: 'Alarm: ${task.title}',
        body: bodyText,
        notificationDetails: _buildNotificationDetails(
          snoozeDurationMinutes: task.snoozeDurationMinutes,
        ),
        payload: payload,
      );
    } catch (_) {
      // Safe fallback in widget tests.
    }
  }

  /// Cancels any scheduled or active alarm notification for [taskId].
  Future<void> cancelTaskAlarm(String taskId) async {
    _scheduledAlarms.remove(taskId);
    if (!_isInitialized) {
      return;
    }
    final int notificationId = notificationIdForTask(taskId);
    try {
      await _plugin.cancel(id: notificationId);
    } catch (_) {
      // Safe fallback in widget tests.
    }
  }

  /// Synchronizes scheduled notifications for all provided [tasks].
  Future<void> syncTaskAlarms(Iterable<Task> tasks, {DateTime? now}) async {
    if (!_isInitialized) {
      await initialize();
    }
    final Set<String> activeTaskIds = <String>{};
    for (final Task task in tasks) {
      activeTaskIds.add(task.id);
      await scheduleTaskAlarm(task, now: now);
    }
    final List<String> removedIds = _scheduledAlarms.keys
        .where((String id) => !activeTaskIds.contains(id))
        .toList();
    for (final String removedId in removedIds) {
      await cancelTaskAlarm(removedId);
    }
  }

  /// Processes a [NotificationResponse] from either a notification tap or
  /// an action button (Snooze, Complete, Dismiss).
  Future<void> handleNotificationResponse(
    NotificationResponse response, {
    bool isBackground = false,
  }) async {
    final Map<String, Object?>? data = decodePayload(response.payload);
    final Object? rawTaskId = data?['taskId'];
    if (rawTaskId is! String || rawTaskId.isEmpty) {
      return;
    }

    final Object? rawSnoozeMinutes = data?['snoozeMinutes'];
    final int defaultSnooze = rawSnoozeMinutes is int
        ? rawSnoozeMinutes
        : Task.defaultSnoozeMinutes;

    final String? actionId = response.actionId;
    AlarmNotificationActionType actionType = AlarmNotificationActionType.open;
    Duration? snoozeDuration;

    if (actionId == actionSnoozeId) {
      actionType = AlarmNotificationActionType.snooze;
      snoozeDuration = Duration(minutes: defaultSnooze);
    } else if (actionId != null && actionId.startsWith(actionSnoozePrefix)) {
      actionType = AlarmNotificationActionType.snooze;
      final int? parsedMinutes = int.tryParse(
        actionId.substring(actionSnoozePrefix.length),
      );
      snoozeDuration = Duration(minutes: parsedMinutes ?? defaultSnooze);
    } else if (actionId == actionDismissId) {
      actionType = AlarmNotificationActionType.dismiss;
    } else if (actionId == actionCompleteId) {
      actionType = AlarmNotificationActionType.complete;
    }

    // If snoozed in the background isolate, immediately schedule the snoozed
    // OS notification so it still fires even if the main UI isolate is not active.
    if (isBackground && actionType == AlarmNotificationActionType.snooze) {
      final Object? rawTitle = data?['title'];
      final Object? rawNotes = data?['notes'];
      final Task tempTask = Task(
        id: rawTaskId,
        title: rawTitle is String ? rawTitle : 'Reminder',
        notes: rawNotes is String ? rawNotes : '',
        hasAlarm: true,
        snoozedUntil: DateTime.now().add(
          snoozeDuration ?? Duration(minutes: defaultSnooze),
        ),
        snoozeDurationMinutes:
            (snoozeDuration ?? Duration(minutes: defaultSnooze)).inMinutes,
      );
      await scheduleTaskAlarm(tempTask);
    } else if (isBackground &&
        (actionType == AlarmNotificationActionType.dismiss ||
            actionType == AlarmNotificationActionType.complete)) {
      await cancelTaskAlarm(rawTaskId);
    }

    if (!_actionController.isClosed) {
      _actionController.add(
        AlarmActionEvent(
          taskId: rawTaskId,
          actionType: actionType,
          snoozeDuration: snoozeDuration,
        ),
      );
    }
  }

  /// Emits a simulated or in-app [AlarmActionEvent] for testing or UI triggers.
  void dispatchAction(AlarmActionEvent event) {
    if (!_actionController.isClosed) {
      _actionController.add(event);
    }
  }

  tz.TZDateTime _toTZDateTime(DateTime dateTime) {
    try {
      return tz.TZDateTime.from(dateTime, tz.local);
    } catch (_) {
      return tz.TZDateTime.utc(
        dateTime.year,
        dateTime.month,
        dateTime.day,
        dateTime.hour,
        dateTime.minute,
        dateTime.second,
      );
    }
  }
}
