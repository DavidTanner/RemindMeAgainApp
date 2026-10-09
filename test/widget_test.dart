import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/tasks/v1.dart' as gtasks;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:remind_me_again/main.dart';
import 'package:remind_me_again/models/task.dart';
import 'package:remind_me_again/screens/task_list_screen.dart';
import 'package:remind_me_again/services/google_auth_service.dart';
import 'package:remind_me_again/services/google_tasks_repository.dart';
import 'package:remind_me_again/services/task_repository.dart';

class _FakeGoogleAuthService implements GoogleAuthService {
  _FakeGoogleAuthService({required this.repository});

  final TaskRepository repository;
  int signInCount = 0;
  int signOutCount = 0;

  @override
  Future<GoogleAuthSession?> restoreSession() async => null;

  @override
  Future<GoogleAuthSession?> signIn() async {
    signInCount++;
    return GoogleAuthSession(
      user: const GoogleAuthUser(
        id: 'user-123',
        email: 'alex@example.com',
        displayName: 'Alex Rivera',
      ),
      taskRepository: repository,
    );
  }

  @override
  Future<void> signOut() async {
    signOutCount++;
  }
}

void main() {
  final DateTime fixedNow = DateTime(2026, 10, 5, 14, 30);

  testWidgets(
    'Displays pre-populated tasks with title, notes, status, due date, and completed timestamp',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        RemindMeAgainApp(
          initialTasks: TaskListScreen.defaultSampleTasks(fixedNow),
          referenceNow: fixedNow,
        ),
      );

      expect(find.text('Remind Me Again'), findsOneWidget);
      expect(find.text('5 active • 1 completed'), findsOneWidget);

      // Filter chips are ordered Active, Completed, All
      final List<String> chipOrder = find
          .byWidgetPredicate((Widget w) => w is FilterChip)
          .evaluate()
          .map(
            (Element e) =>
                ((e.widget as FilterChip).key! as ValueKey<String>).value,
          )
          .toList();
      expect(chipOrder, <String>[
        'filter-chip-active',
        'filter-chip-completed',
        'filter-chip-all',
      ]);

      // Active filter is selected by default, so the completed task is hidden
      expect(find.text('Schedule dentist checkup'), findsNothing);

      // Verify overdue timed task
      expect(find.text('Submit quarterly expense report'), findsOneWidget);
      expect(find.text('Yesterday • 4:30 PM'), findsOneWidget);

      // Verify today timed task and today all-day task
      expect(find.text('Pick up prescription from pharmacy'), findsOneWidget);
      expect(find.text('Today • 5:30 PM'), findsOneWidget);
      expect(find.text('Renew annual library membership'), findsOneWidget);
      expect(find.text('Today • All day'), findsWidgets);

      // Switch to All, then scroll down to verify completed task with timestamp
      await tester.tap(find.byKey(const ValueKey<String>('filter-chip-all')));
      await tester.pumpAndSettle();
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

    // Initially on 'Active'
    expect(find.text('Buy groceries'), findsOneWidget);
    expect(find.text('File taxes'), findsNothing);

    // Tap 'All' filter
    await tester.tap(find.byKey(const ValueKey<String>('filter-chip-all')));
    await tester.pumpAndSettle();

    expect(find.text('Buy groceries'), findsOneWidget);
    expect(find.text('File taxes'), findsOneWidget);

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

      // Mark as completed; it disappears from the default Active view
      await tester.tap(find.byKey(const ValueKey<String>('task-checkbox-t1')));
      await tester.pumpAndSettle();

      expect(find.text('Call plumber'), findsNothing);
      expect(find.text('All caught up!'), findsOneWidget);
      expect(find.text('0 active • 1 completed'), findsOneWidget);

      // Switch to Completed to see the completion timestamp
      await tester.tap(
        find.byKey(const ValueKey<String>('filter-chip-completed')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Completed Today at 2:30 PM'), findsOneWidget);

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

  test('GoogleTasksRepository round-trips timed due dates via notes metadata and preserves all-day tasks', () {
    final Task timedTask = Task(
      id: 'gtask-1',
      title: 'Doctor appointment',
      notes: 'Bring insurance card',
      status: TaskStatus.active,
      dueDate: DateTime(2026, 10, 5, 17, 30),
      isAllDay: false,
    );

    final gtasks.Task remoteTimed = GoogleTasksRepository.toGoogleTask(
      timedTask,
    );
    expect(remoteTimed.due, '2026-10-05T00:00:00.000Z');
    expect(
      remoteTimed.notes,
      'Bring insurance card\n\n[remind_me_again:due_time=17:30]',
    );

    final Task roundTrippedTimed = GoogleTasksRepository.fromGoogleTask(
      remoteTimed,
    );
    expect(roundTrippedTimed.id, 'gtask-1');
    expect(roundTrippedTimed.title, 'Doctor appointment');
    expect(roundTrippedTimed.notes, 'Bring insurance card');
    expect(roundTrippedTimed.isAllDay, isFalse);
    expect(roundTrippedTimed.dueDate, DateTime(2026, 10, 5, 17, 30));

    final Task allDayTask = Task(
      id: 'gtask-2',
      title: 'Pay rent',
      notes: 'Via portal',
      status: TaskStatus.completed,
      completedAt: DateTime(2026, 10, 5, 9, 0),
      dueDate: DateTime(2026, 10, 5),
      isAllDay: true,
    );

    final gtasks.Task remoteAllDay = GoogleTasksRepository.toGoogleTask(
      allDayTask,
    );
    expect(remoteAllDay.notes, 'Via portal');
    expect(remoteAllDay.status, 'completed');

    final Task roundTrippedAllDay = GoogleTasksRepository.fromGoogleTask(
      remoteAllDay,
    );
    expect(roundTrippedAllDay.isAllDay, isTrue);
    expect(roundTrippedAllDay.dueDate, DateTime(2026, 10, 5));
    expect(roundTrippedAllDay.isCompleted, isTrue);
    expect(roundTrippedAllDay.completedAt, DateTime(2026, 10, 5, 9, 0));
  });

  testWidgets(
    'Requires Google Sign-In when unauthenticated and syncs tasks with Google Tasks (@default) after sign-in',
    (WidgetTester tester) async {
      final List<Map<String, dynamic>> remoteStore = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'remote-1',
          'title': 'Sync project roadmap',
          'notes': 'Share Q4 milestones\n\n[remind_me_again:due_time=16:00]',
          'status': 'needsAction',
          'due': '2026-10-05T00:00:00.000Z',
        },
      ];

      int singleTaskGetCount = 0;
      final MockClient mockHttpClient = MockClient((
        http.Request request,
      ) async {
        final String path = Uri.decodeComponent(request.url.path);
        if (request.method == 'GET' &&
            path == '/tasks/v1/lists/@default/tasks') {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'kind': 'tasks#tasks',
              'items': remoteStore,
            }),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }
        if (request.method == 'POST' &&
            path == '/tasks/v1/lists/@default/tasks') {
          final Map<String, dynamic> body =
              jsonDecode(request.body) as Map<String, dynamic>;
          final Map<String, dynamic> created = <String, dynamic>{
            ...body,
            'id': 'remote-created-2',
          };
          remoteStore.insert(0, created);
          return http.Response(
            jsonEncode(created),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }
        if (request.method == 'PUT' &&
            path.startsWith('/tasks/v1/lists/@default/tasks/')) {
          final Map<String, dynamic> body =
              jsonDecode(request.body) as Map<String, dynamic>;
          final String id = path.split('/').last;
          final int idx = remoteStore.indexWhere(
            (Map<String, dynamic> item) => item['id'] == id,
          );
          if (idx >= 0) {
            remoteStore[idx] = body;
          }
          return http.Response(
            jsonEncode(body),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }
        if (request.method == 'GET' &&
            path.startsWith('/tasks/v1/lists/@default/tasks/')) {
          singleTaskGetCount++;
          final String id = path.split('/').last;
          final Map<String, dynamic>? item = remoteStore
              .cast<Map<String, dynamic>?>()
              .firstWhere(
                (Map<String, dynamic>? item) => item!['id'] == id,
                orElse: () => null,
              );
          if (item == null) {
            return http.Response('Not found', 404);
          }
          return http.Response(
            jsonEncode(<String, dynamic>{
              ...item,
              'kind': 'tasks#task',
              'etag': '"etag-fresh"',
              'webViewLink': 'https://tasks.google.com/task/$id',
            }),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }
        if (request.method == 'DELETE' &&
            path.startsWith('/tasks/v1/lists/@default/tasks/')) {
          final String id = path.split('/').last;
          remoteStore.removeWhere(
            (Map<String, dynamic> item) => item['id'] == id,
          );
          return http.Response('', 204);
        }
        return http.Response('Not found', 404);
      });

      final GoogleTasksRepository repository = GoogleTasksRepository(
        tasksApi: gtasks.TasksApi(mockHttpClient),
        httpClient: mockHttpClient,
      );
      final _FakeGoogleAuthService authService = _FakeGoogleAuthService(
        repository: repository,
      );

      await tester.pumpWidget(
        RemindMeAgainApp(authService: authService, referenceNow: fixedNow),
      );
      await tester.pumpAndSettle();

      // Initially unauthenticated: shows Google Sign-In screen
      expect(find.text('Connect to Google Tasks'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('google-sign-in-button')),
        findsOneWidget,
      );

      // Tap Sign in with Google
      await tester.tap(
        find.byKey(const ValueKey<String>('google-sign-in-button')),
      );
      await tester.pumpAndSettle();

      expect(authService.signInCount, 1);
      expect(find.text('Sync project roadmap'), findsOneWidget);
      expect(find.text('Share Q4 milestones'), findsOneWidget);
      expect(find.text('Today • 4:00 PM'), findsOneWidget);
      expect(find.text('Activates Today • 4:00 PM'), findsOneWidget);

      // Long-press the card to open the debug sheet with the cached JSON
      await tester.longPress(
        find.byKey(const ValueKey<String>('task-card-remote-1')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('task-debug-sheet')),
        findsOneWidget,
      );
      final Finder debugSheet = find.byKey(
        const ValueKey<String>('task-debug-sheet'),
      );
      Finder inSheet(Finder matching) =>
          find.descendant(of: debugSheet, matching: matching);

      expect(inSheet(find.textContaining('"id": "remote-1"')), findsOneWidget);
      expect(
        inSheet(find.textContaining('"due": "2026-10-05T00:00:00.000Z"')),
        findsOneWidget,
      );
      expect(
        inSheet(find.text('Notes tag [remind_me_again:due_time]')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('task-debug-activates')),
          matching: find.text('Today • 4:00 PM'),
        ),
        findsOneWidget,
      );
      expect(inSheet(find.text('Pending (not yet active)')), findsOneWidget);

      // Refresh performs a verbatim GET for the single task
      await tester.tap(
        find.byKey(const ValueKey<String>('task-debug-refresh-button')),
      );
      await tester.pumpAndSettle();

      expect(singleTaskGetCount, 1);
      expect(
        inSheet(find.textContaining('"etag": "\\"etag-fresh\\""')),
        findsOneWidget,
      );
      expect(
        inSheet(find.text('Fetched from the API just now.')),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('task-debug-sheet')),
        findsNothing,
      );

      // Complete the remote task and verify PUT request updates remoteStore
      await tester.tap(
        find.byKey(const ValueKey<String>('task-checkbox-remote-1')),
      );
      await tester.pumpAndSettle();

      expect(remoteStore.first['status'], 'completed');

      // Sign out returns to the Google Sign-In screen
      await tester.tap(find.byKey(const ValueKey<String>('sign-out-button')));
      await tester.pumpAndSettle();

      expect(authService.signOutCount, 1);
      expect(find.text('Connect to Google Tasks'), findsOneWidget);
    },
  );

  test('GoogleTasksRepository honours a time-of-day in the API due timestamp when present', () {
    // Google documents that the time portion of `due` is discarded, but if
    // it is ever returned it takes precedence over the notes tag.
    final DecodedDue fromTimestamp =
        GoogleTasksRepository.decodeNotesAndDueDate(
          rawNotes: 'Notes\n\n[remind_me_again:due_time=09:00]',
          rawDue: '2026-10-05T17:30:00.000Z',
        );
    final DateTime expectedLocal = DateTime.parse('2026-10-05T17:30:00.000Z')
        .toLocal();
    expect(fromTimestamp.notes, 'Notes');
    expect(fromTimestamp.isAllDay, isFalse);
    expect(fromTimestamp.dueTimeSource, DueTimeSource.dueTimestamp);
    expect(
      fromTimestamp.dueDate,
      DateTime(
        expectedLocal.year,
        expectedLocal.month,
        expectedLocal.day,
        expectedLocal.hour,
        expectedLocal.minute,
      ),
    );

    final DecodedDue fromTag = GoogleTasksRepository.decodeNotesAndDueDate(
      rawNotes: '[remind_me_again:due_time=09:15]',
      rawDue: '2026-10-05T00:00:00.000Z',
    );
    expect(fromTag.notes, '');
    expect(fromTag.isAllDay, isFalse);
    expect(fromTag.dueTimeSource, DueTimeSource.notesTag);
    expect(fromTag.dueDate, DateTime(2026, 10, 5, 9, 15));

    final DecodedDue dateOnly = GoogleTasksRepository.decodeNotesAndDueDate(
      rawNotes: 'Plain notes',
      rawDue: '2026-10-05T00:00:00.000Z',
    );
    expect(dateOnly.isAllDay, isTrue);
    expect(dateOnly.dueTimeSource, DueTimeSource.none);
    expect(dateOnly.dueDate, DateTime(2026, 10, 5));

    final Task remote = GoogleTasksRepository.fromGoogleTask(
      gtasks.Task(
        id: 'g-1',
        title: 'Keep JSON',
        due: '2026-10-05T00:00:00.000Z',
        status: 'needsAction',
      ),
    );
    expect(remote.rawJson, isNotNull);
    expect(remote.rawJson!['id'], 'g-1');
    expect(remote.rawJson!['due'], '2026-10-05T00:00:00.000Z');
    expect(remote.copyWith(title: 'Renamed').rawJson, remote.rawJson);
  });

  test('Task.activatesAt and isPendingActivation reflect the due schedule', () {
    final DateTime now = DateTime(2026, 10, 5, 14, 30);

    final Task timedLater = Task(
      id: 'a',
      title: 'Later today',
      dueDate: DateTime(2026, 10, 5, 17, 0),
      isAllDay: false,
    );
    expect(timedLater.activatesAt, DateTime(2026, 10, 5, 17, 0));
    expect(timedLater.isPendingActivation(now), isTrue);

    final Task timedEarlier = Task(
      id: 'b',
      title: 'Earlier today',
      dueDate: DateTime(2026, 10, 5, 9, 0),
      isAllDay: false,
    );
    expect(timedEarlier.isPendingActivation(now), isFalse);

    final Task allDayTomorrow = Task(
      id: 'c',
      title: 'Tomorrow',
      dueDate: DateTime(2026, 10, 6, 23, 59),
      isAllDay: true,
    );
    expect(allDayTomorrow.activatesAt, DateTime(2026, 10, 6));
    expect(allDayTomorrow.isPendingActivation(now), isTrue);

    final Task allDayToday = Task(
      id: 'd',
      title: 'Today',
      dueDate: DateTime(2026, 10, 5),
      isAllDay: true,
    );
    expect(allDayToday.isPendingActivation(now), isFalse);

    const Task noDue = Task(id: 'e', title: 'Whenever');
    expect(noDue.activatesAt, isNull);
    expect(noDue.isPendingActivation(now), isFalse);

    final Task completed = timedLater.toggleStatus(now: now);
    expect(completed.isPendingActivation(now), isFalse);
  });

  testWidgets(
    'Shows activation chips and opens the task debug sheet from the card and the edit form',
    (WidgetTester tester) async {
      final List<Task> tasks = <Task>[
        Task(
          id: 't1',
          title: 'Evening workout',
          dueDate: DateTime(2026, 10, 5, 18, 0),
          isAllDay: false,
          dueTimeSource: DueTimeSource.notesTag,
          rawJson: <String, dynamic>{
            'id': 't1',
            'title': 'Evening workout',
            'due': '2026-10-05T00:00:00.000Z',
          },
        ),
        Task(
          id: 't2',
          title: 'Morning stretch',
          dueDate: DateTime(2026, 10, 5, 7, 0),
          isAllDay: false,
        ),
        Task(
          id: 't3',
          title: 'Laundry',
          dueDate: DateTime(2026, 10, 6),
          isAllDay: true,
        ),
      ];

      await tester.pumpWidget(
        RemindMeAgainApp(initialTasks: tasks, referenceNow: fixedNow),
      );

      expect(find.text('Activates Today • 6:00 PM'), findsOneWidget);
      expect(find.text('Active since Today • 7:00 AM'), findsOneWidget);
      expect(find.text('Activates Tomorrow • Start of day'), findsOneWidget);

      // Long-press opens the debug sheet with cached JSON
      await tester.longPress(
        find.byKey(const ValueKey<String>('task-card-t1')),
      );
      await tester.pumpAndSettle();

      final Finder debugSheet = find.byKey(
        const ValueKey<String>('task-debug-sheet'),
      );
      Finder inSheet(Finder matching) =>
          find.descendant(of: debugSheet, matching: matching);

      expect(debugSheet, findsOneWidget);
      expect(
        inSheet(find.textContaining('"title": "Evening workout"')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('task-debug-activates')),
          matching: find.text('Today • 6:00 PM'),
        ),
        findsOneWidget,
      );
      expect(inSheet(find.text('Pending (not yet active)')), findsOneWidget);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      // A task that never synced has no JSON to show
      await tester.longPress(
        find.byKey(const ValueKey<String>('task-card-t2')),
      );
      await tester.pumpAndSettle();
      expect(
        inSheet(find.text('No API response cached for this task.')),
        findsOneWidget,
      );
      expect(inSheet(find.text('Active now')), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      // The edit form exposes the same view via the JSON button
      await tester.tap(find.text('Evening workout'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Task'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('task-debug-button')));
      await tester.pumpAndSettle();
      expect(debugSheet, findsOneWidget);
      expect(inSheet(find.textContaining('"id": "t1"')), findsOneWidget);
    },
  );
}
