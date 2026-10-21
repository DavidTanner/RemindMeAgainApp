import 'dart:async';

import 'package:flutter/material.dart';

import 'models/task.dart';
import 'screens/task_list_screen.dart';
import 'services/alarm_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(AlarmService.instance.initialize());
  runApp(const RemindMeAgainApp());
}

/// Root widget for the Remind Me Again task application.
class RemindMeAgainApp extends StatelessWidget {
  const RemindMeAgainApp({
    super.key,
    this.initialTasks,
    this.referenceNow,
    this.alarmService,
  });

  final List<Task>? initialTasks;
  final DateTime? referenceNow;
  final AlarmService? alarmService;

  @override
  Widget build(BuildContext context) {
    const Color seedColor = Color(0xFF3F51B5);

    return MaterialApp(
      title: 'Remind Me Again',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        ),
        splashFactory: InkRipple.splashFactory,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
        splashFactory: InkRipple.splashFactory,
        useMaterial3: true,
      ),
      home: TaskListScreen(
        initialTasks: initialTasks,
        referenceNow: referenceNow,
        alarmService: alarmService,
      ),
    );
  }
}

/// Alias maintained for convenience in entrypoints and tests.
typedef MyApp = RemindMeAgainApp;
