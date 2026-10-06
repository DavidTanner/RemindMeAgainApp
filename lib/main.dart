import 'package:flutter/material.dart';

import 'models/task.dart';
import 'screens/task_list_screen.dart';

void main() {
  runApp(const RemindMeAgainApp());
}

/// Root widget for the Remind Me Again task application.
class RemindMeAgainApp extends StatelessWidget {
  const RemindMeAgainApp({super.key, this.initialTasks, this.referenceNow});

  final List<Task>? initialTasks;
  final DateTime? referenceNow;

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
      ),
    );
  }
}

/// Alias maintained for convenience in entrypoints and tests.
typedef MyApp = RemindMeAgainApp;
