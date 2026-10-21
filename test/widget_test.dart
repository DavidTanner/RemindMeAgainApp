import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:remind_me_again/main.dart';
import 'package:remind_me_again/models/task.dart';
import 'package:remind_me_again/services/alarm_service.dart';

void main() {
  final DateTime fixedNow = DateTime(2026, 10, 5, 14, 30);

  testWidgets(
    'Displays pre-populated tasks with title, notes, status, due date, and completed timestamp',
    (WidgetTester tester) async {
      await tester.pumpWidget(RemindMeAgainApp(referenceNow: fixedNow));

      expect(find.text('Remind Me Again'), findsOneWidget);
      expect(find.text('5 active • 1 completed'), findsOneWidget);

      // Verify overdue timed task
      expect(find.text('Submit quarterly expense report'), findsOneWidget);
      expect(find.text('Yesterday • 4:30 PM'), findsOneWidget);

      // Verify today timed task and today all-day task
      expect(find.text('Pick up prescription from pharmacy'), findsOneWidget);
      expect(find.text('Today • 5:30 PM'), findsOneWidget);
      expect(find.text('Renew annual library membership'), findsOneWidget);
      expect(find.text('Today • All day'), findsWidgets);

      // Scroll down to verify completed task with completed timestamp
      await tester.scrollUntilVisible(
        find.text('Schedule dentist checkup'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Schedule dentist checkup'), findsOneWidget);
      expect(find.text('Completed Today at 9:15 AM'), findsOneWidget);
    },
  );

  testWidgets('Filters tasks by All, Active, and Completed chips', (
    WidgetTester tester,
  ) async {
    final List<Task> tasks = <Task>[
      Task(
        id: 't1',
        title: 'Buy groceries',
        notes: 'Milk, eggs, bread',
        status: TaskStatus.active,
        dueDate: DateTime(2026, 10, 5),
        isAllDay: true,
      ),
      Task(
        id: 't2',
        title: 'File taxes',
        notes: 'Uploaded receipt PDF',
        status: TaskStatus.completed,
        completedAt: DateTime(2026, 10, 5, 11, 0),
        dueDate: DateTime(2026, 10, 5, 10, 0),
        isAllDay: false,
      ),
    ];

    await tester.pumpWidget(
      RemindMeAgainApp(initialTasks: tasks, referenceNow: fixedNow),
    );

    // Initially on 'All'
    expect(find.text('Buy groceries'), findsOneWidget);
    expect(find.text('File taxes'), findsOneWidget);

    // Tap 'Active' filter
    await tester.tap(find.byKey(const ValueKey<String>('filter-chip-active')));
    await tester.pumpAndSettle();

    expect(find.text('Buy groceries'), findsOneWidget);
    expect(find.text('File taxes'), findsNothing);

    // Tap 'Completed' filter
    await tester.tap(
      find.byKey(const ValueKey<String>('filter-chip-completed')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Buy groceries'), findsNothing);
    expect(find.text('File taxes'), findsOneWidget);
    expect(find.text('Completed Today at 11:00 AM'), findsOneWidget);
  });

  testWidgets(
    'Toggling task status sets and clears the completedAt timestamp',
    (WidgetTester tester) async {
      final List<Task> tasks = <Task>[
        Task(
          id: 't1',
          title: 'Call plumber',
          notes: 'Kitchen sink leak',
          status: TaskStatus.active,
          dueDate: DateTime(2026, 10, 5, 16, 0),
          isAllDay: false,
        ),
      ];

      await tester.pumpWidget(
        RemindMeAgainApp(initialTasks: tasks, referenceNow: fixedNow),
      );

      expect(find.text('Completed Today at 2:30 PM'), findsNothing);

      // Mark as completed
      await tester.tap(find.byKey(const ValueKey<String>('task-checkbox-t1')));
      await tester.pumpAndSettle();

      expect(find.text('Completed Today at 2:30 PM'), findsOneWidget);
      expect(find.text('0 active • 1 completed'), findsOneWidget);

      // Uncheck to mark active again
      await tester.tap(find.byKey(const ValueKey<String>('task-checkbox-t1')));
      await tester.pumpAndSettle();

      expect(find.text('Completed Today at 2:30 PM'), findsNothing);
      expect(find.text('1 active • 0 completed'), findsOneWidget);
    },
  );

  testWidgets(
    'Creates a new task supporting both all-day and timed due dates',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        RemindMeAgainApp(initialTasks: const <Task>[], referenceNow: fixedNow),
      );

      expect(find.text('No tasks yet'), findsOneWidget);

      // Open New Task sheet
      await tester.tap(find.byKey(const ValueKey<String>('add-task-fab')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey<String>('task-title-input')),
        'Water indoor plants',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('task-notes-input')),
        'Ferns and succulents in living room',
      );

      // Toggle off All-day so it includes a specific time (defaults to 5:00 PM)
      await tester.tap(
        find.byKey(const ValueKey<String>('task-all-day-switch')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('pick-time-button')),
        findsOneWidget,
      );

      final Finder saveButton = find.byKey(
        const ValueKey<String>('save-task-button'),
      );
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(find.text('Water indoor plants'), findsOneWidget);
      expect(find.text('Ferns and succulents in living room'), findsOneWidget);
      expect(find.text('Today • 5:00 PM'), findsOneWidget);
    },
  );

  testWidgets(
    'Quick snoozes an active alarm from the task card and updates scheduled alarm',
    (WidgetTester tester) async {
      final AlarmService alarmService = AlarmService();
      final List<Task> tasks = <Task>[
        Task(
          id: 'alarm-1',
          title: 'Take afternoon medication',
          notes: 'With a full glass of water',
          status: TaskStatus.active,
          dueDate: DateTime(2026, 10, 5, 14, 0),
          isAllDay: false,
        ),
      ];

      await tester.pumpWidget(
        RemindMeAgainApp(
          initialTasks: tasks,
          referenceNow: fixedNow,
          alarmService: alarmService,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alarm ringing'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('task-snooze-alarm-1')),
        findsOneWidget,
      );

      // Tap Snooze on the task card (default 10 min from 2:30 PM -> 2:40 PM)
      await tester.tap(
        find.byKey(const ValueKey<String>('task-snooze-alarm-1')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Snoozed until 2:40 PM'), findsOneWidget);
      expect(
        alarmService.scheduledAlarms['alarm-1']?.scheduledAt,
        DateTime(2026, 10, 5, 14, 40),
      );
    },
  );

  testWidgets(
    'Triggers alarm dialog when scheduled time arrives and supports custom snooze duration',
    (WidgetTester tester) async {
      final AlarmService alarmService = AlarmService();
      final List<Task> tasks = <Task>[
        Task(
          id: 'alarm-2',
          title: 'Join client call',
          notes: 'Zoom link in calendar invite',
          status: TaskStatus.active,
          dueDate: DateTime(2026, 10, 5, 14, 35),
          isAllDay: false,
        ),
      ];

      await tester.pumpWidget(
        RemindMeAgainApp(
          initialTasks: tasks,
          referenceNow: fixedNow,
          alarmService: alarmService,
        ),
      );
      await tester.pumpAndSettle();

      // Advance time by 5 minutes so the alarm triggers at 2:35 PM
      await tester.pump(const Duration(minutes: 5));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('alarm-ring-dialog')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('alarm-dialog-title')),
        findsOneWidget,
      );

      // Select 15 min snooze preset and tap Snooze
      await tester.tap(find.byKey(const ValueKey<String>('snooze-preset-15')));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('alarm-snooze-button')),
      );
      await tester.pumpAndSettle();

      // 2:35 PM + 15 min = 2:50 PM
      expect(find.text('Snoozed until 2:50 PM'), findsOneWidget);
      expect(
        alarmService.scheduledAlarms['alarm-2']?.scheduledAt,
        DateTime(2026, 10, 5, 14, 50),
      );
    },
  );

  testWidgets(
    'Handles OS notification snooze and complete actions via AlarmService',
    (WidgetTester tester) async {
      final AlarmService alarmService = AlarmService();
      final List<Task> tasks = <Task>[
        Task(
          id: 'alarm-3',
          title: 'Check oven timer',
          notes: 'Sourdough loaf',
          status: TaskStatus.active,
          dueDate: DateTime(2026, 10, 5, 15, 0),
          isAllDay: false,
          snoozeDurationMinutes: 5,
        ),
      ];

      await tester.pumpWidget(
        RemindMeAgainApp(
          initialTasks: tasks,
          referenceNow: fixedNow,
          alarmService: alarmService,
        ),
      );
      await tester.pumpAndSettle();

      final String payload = AlarmService.encodePayload(
        taskId: 'alarm-3',
        title: 'Check oven timer',
        notes: 'Sourdough loaf',
        snoozeMinutes: 5,
      );

      // Simulate tapping the Snooze action button on the OS notification
      await alarmService.handleNotificationResponse(
        NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          actionId: AlarmService.actionSnoozeId,
          payload: payload,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Snoozed until 2:35 PM'), findsOneWidget);

      // Simulate tapping the Complete action button on the OS notification
      await alarmService.handleNotificationResponse(
        NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          actionId: AlarmService.actionCompleteId,
          payload: payload,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('0 active • 1 completed'), findsOneWidget);
      expect(alarmService.scheduledAlarms.containsKey('alarm-3'), isFalse);
    },
  );
}
