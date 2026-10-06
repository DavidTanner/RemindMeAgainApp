import 'package:flutter/material.dart';

import '../models/task.dart';
import '../services/google_auth_service.dart';
import '../services/task_repository.dart';
import '../widgets/task_card.dart';
import '../widgets/task_form_sheet.dart';

/// Main screen displaying the user's tasks synced with Google Tasks off-device,
/// with status filter chips (All, Active, Completed) and date-based section grouping.
class TaskListScreen extends StatefulWidget {
  const TaskListScreen({
    super.key,
    this.initialTasks,
    this.taskRepository,
    this.authService,
    this.referenceNow,
  });

  final List<Task>? initialTasks;
  final TaskRepository? taskRepository;
  final GoogleAuthService? authService;
  final DateTime? referenceNow;

  /// Generates default pre-populated sample tasks relative to [now].
  static List<Task> defaultSampleTasks(DateTime now) {
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime yesterday = today.subtract(const Duration(days: 1));
    final DateTime tomorrow = today.add(const Duration(days: 1));
    final DateTime nextWeek = today.add(const Duration(days: 5));

    return <Task>[
      Task(
        id: 'sample-1',
        title: 'Submit quarterly expense report',
        notes: 'Attach travel receipts and meal invoices from the conference.',
        status: TaskStatus.active,
        dueDate: DateTime(
          yesterday.year,
          yesterday.month,
          yesterday.day,
          16,
          30,
        ),
        isAllDay: false,
      ),
      Task(
        id: 'sample-2',
        title: 'Pick up prescription from pharmacy',
        notes: 'Main Street Pharmacy closes at 7:00 PM.',
        status: TaskStatus.active,
        dueDate: DateTime(today.year, today.month, today.day, 17, 30),
        isAllDay: false,
      ),
      Task(
        id: 'sample-3',
        title: 'Renew annual library membership',
        notes: 'Can be completed online or at the front desk.',
        status: TaskStatus.active,
        dueDate: today,
        isAllDay: true,
      ),
      Task(
        id: 'sample-4',
        title: 'Team design review meeting',
        notes: 'Walk through the mobile task management UI prototypes.',
        status: TaskStatus.active,
        dueDate: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 10, 0),
        isAllDay: false,
      ),
      Task(
        id: 'sample-5',
        title: 'Prepare weekend camping gear',
        notes: 'Check tent stakes, sleeping bags, and lantern batteries.',
        status: TaskStatus.active,
        dueDate: nextWeek,
        isAllDay: true,
      ),
      Task(
        id: 'sample-6',
        title: 'Schedule dentist checkup',
        notes: ' Morning appointments preferred.',
        status: TaskStatus.completed,
        completedAt: DateTime(today.year, today.month, today.day, 9, 15),
        dueDate: today,
        isAllDay: true,
      ),
    ];
  }

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final List<Task> _tasks = <Task>[];
  TaskRepository? _repository;
  GoogleAuthService? _authService;
  GoogleAuthUser? _currentUser;

  bool _isCheckingAuth = false;
  bool _isSigningIn = false;
  bool _isLoadingTasks = false;
  String? _errorMessage;

  TaskFilter _selectedFilter = TaskFilter.all;
  String _searchQuery = '';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  DateTime get _now => widget.referenceNow ?? DateTime.now();

  bool get _requiresSignIn => _authService != null && _repository == null;

  @override
  void initState() {
    super.initState();
    if (widget.taskRepository != null) {
      _repository = widget.taskRepository;
      if (widget.initialTasks != null) {
        _tasks.addAll(widget.initialTasks!);
      } else {
        _loadTasks();
      }
    } else if (widget.initialTasks != null && widget.authService == null) {
      _tasks.addAll(widget.initialTasks!);
      _repository = InMemoryTaskRepository(_tasks);
    } else {
      _authService = widget.authService ?? GoogleSignInAuthService();
      _isCheckingAuth = true;
      _restoreAuthSession();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _restoreAuthSession() async {
    try {
      final GoogleAuthSession? session = await _authService!.restoreSession();
      if (!mounted) {
        return;
      }
      if (session != null) {
        setState(() {
          _currentUser = session.user;
          _repository = session.taskRepository;
          _isCheckingAuth = false;
          _errorMessage = null;
        });
        await _loadTasks();
      } else {
        setState(() {
          _isCheckingAuth = false;
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isCheckingAuth = false;
        _errorMessage = 'Failed to restore Google session: $error';
      });
    }
  }

  Future<void> _handleSignIn() async {
    if (_authService == null || _isSigningIn) {
      return;
    }
    setState(() {
      _isSigningIn = true;
      _errorMessage = null;
    });

    try {
      final GoogleAuthSession? session = await _authService!.signIn();
      if (!mounted) {
        return;
      }
      if (session != null) {
        setState(() {
          _currentUser = session.user;
          _repository = session.taskRepository;
          _isSigningIn = false;
        });
        await _loadTasks();
      } else {
        setState(() {
          _isSigningIn = false;
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSigningIn = false;
        _errorMessage = 'Google Sign-In failed: $error';
      });
    }
  }

  Future<void> _handleSignOut() async {
    if (_authService == null) {
      return;
    }
    try {
      await _authService!.signOut();
    } catch (_) {
      // Ignore sign-out errors and clear local session state.
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _currentUser = null;
      _repository = null;
      _tasks.clear();
      _isSearching = false;
      _searchController.clear();
      _searchQuery = '';
      _errorMessage = null;
    });
  }

  Future<void> _loadTasks() async {
    final TaskRepository? repository = _repository;
    if (repository == null) {
      return;
    }
    setState(() {
      _isLoadingTasks = true;
      _errorMessage = null;
    });

    try {
      final List<Task> fetched = await repository.fetchTasks();
      if (!mounted) {
        return;
      }
      setState(() {
        _tasks
          ..clear()
          ..addAll(fetched);
        _isLoadingTasks = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingTasks = false;
        _errorMessage = 'Failed to sync with Google Tasks: $error';
      });
    }
  }

  void _showSyncError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  int _countForFilter(TaskFilter filter) {
    switch (filter) {
      case TaskFilter.all:
        return _tasks.length;
      case TaskFilter.active:
        return _tasks.where((Task t) => !t.isCompleted).length;
      case TaskFilter.completed:
        return _tasks.where((Task t) => t.isCompleted).length;
    }
  }

  List<Task> get _filteredTasks {
    return _tasks.where((Task task) {
      final bool matchesFilter = switch (_selectedFilter) {
        TaskFilter.all => true,
        TaskFilter.active => !task.isCompleted,
        TaskFilter.completed => task.isCompleted,
      };
      if (!matchesFilter) {
        return false;
      }
      if (_searchQuery.trim().isEmpty) {
        return true;
      }
      final String query = _searchQuery.toLowerCase();
      return task.title.toLowerCase().contains(query) ||
          task.notes.toLowerCase().contains(query);
    }).toList();
  }

  Map<TaskDateGroup, List<Task>> _groupTasks(List<Task> tasks) {
    final Map<TaskDateGroup, List<Task>> grouped = <TaskDateGroup, List<Task>>{
      for (final TaskDateGroup group in TaskDateGroup.values) group: <Task>[],
    };

    for (final Task task in tasks) {
      final TaskDateGroup group = task.dateGroup(_now);
      grouped[group]!.add(task);
    }

    for (final MapEntry<TaskDateGroup, List<Task>> entry in grouped.entries) {
      entry.value.sort((Task a, Task b) {
        if (entry.key == TaskDateGroup.completed) {
          final DateTime aCompleted =
              a.completedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final DateTime bCompleted =
              b.completedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bCompleted.compareTo(aCompleted);
        }
        if (a.dueDate == null && b.dueDate == null) {
          return a.title.compareTo(b.title);
        }
        if (a.dueDate == null) {
          return 1;
        }
        if (b.dueDate == null) {
          return -1;
        }
        final int dateComparison = a.dueDate!.compareTo(b.dueDate!);
        if (dateComparison != 0) {
          return dateComparison;
        }
        if (a.isAllDay != b.isAllDay) {
          return a.isAllDay ? -1 : 1;
        }
        return a.title.compareTo(b.title);
      });
    }

    grouped.removeWhere((_, List<Task> list) => list.isEmpty);
    return grouped;
  }

  Future<void> _toggleTaskStatus(Task task) async {
    final int index = _tasks.indexWhere((Task t) => t.id == task.id);
    if (index == -1) {
      return;
    }
    final Task previous = _tasks[index];
    final Task toggled = previous.toggleStatus(now: _now);
    setState(() {
      _tasks[index] = toggled;
    });

    final TaskRepository? repository = _repository;
    if (repository == null) {
      return;
    }

    try {
      final Task persisted = await repository.updateTask(toggled);
      if (!mounted) {
        return;
      }
      final int currentIndex = _tasks.indexWhere(
        (Task t) => t.id == toggled.id,
      );
      if (currentIndex != -1) {
        setState(() {
          _tasks[currentIndex] = persisted;
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      final int currentIndex = _tasks.indexWhere(
        (Task t) => t.id == toggled.id,
      );
      if (currentIndex != -1) {
        setState(() {
          _tasks[currentIndex] = previous;
        });
      }
      _showSyncError('Failed to update task in Google Tasks: $error');
    }
  }

  Future<void> _saveTask(Task updatedOrNewTask) async {
    final int index = _tasks.indexWhere(
      (Task t) => t.id == updatedOrNewTask.id,
    );
    final bool isExisting = index >= 0;
    final Task? previous = isExisting ? _tasks[index] : null;

    setState(() {
      if (isExisting) {
        _tasks[index] = updatedOrNewTask;
      } else {
        _tasks.insert(0, updatedOrNewTask);
      }
    });

    final TaskRepository? repository = _repository;
    if (repository == null) {
      return;
    }

    try {
      final Task persisted = isExisting
          ? await repository.updateTask(updatedOrNewTask)
          : await repository.createTask(updatedOrNewTask);
      if (!mounted) {
        return;
      }
      final int currentIndex = _tasks.indexWhere(
        (Task t) => t.id == updatedOrNewTask.id,
      );
      if (currentIndex != -1) {
        setState(() {
          _tasks[currentIndex] = persisted;
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        final int currentIndex = _tasks.indexWhere(
          (Task t) => t.id == updatedOrNewTask.id,
        );
        if (isExisting && previous != null && currentIndex != -1) {
          _tasks[currentIndex] = previous;
        } else if (!isExisting && currentIndex != -1) {
          _tasks.removeAt(currentIndex);
        }
      });
      _showSyncError('Failed to save task to Google Tasks: $error');
    }
  }

  Future<void> _deleteTask(Task task) async {
    final int index = _tasks.indexWhere((Task t) => t.id == task.id);
    if (index == -1) {
      return;
    }
    setState(() {
      _tasks.removeAt(index);
    });

    final TaskRepository? repository = _repository;
    if (repository != null) {
      try {
        await repository.deleteTask(task.id);
      } catch (error) {
        if (!mounted) {
          return;
        }
        setState(() {
          final int insertIndex = index.clamp(0, _tasks.length);
          _tasks.insert(insertIndex, task);
        });
        _showSyncError('Failed to delete task from Google Tasks: $error');
        return;
      }
    }

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted "${task.title}"'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            _undoDeleteTask(task, index);
          },
        ),
      ),
    );
  }

  Future<void> _undoDeleteTask(Task task, int originalIndex) async {
    setState(() {
      final int insertIndex = originalIndex.clamp(0, _tasks.length);
      _tasks.insert(insertIndex, task);
    });

    final TaskRepository? repository = _repository;
    if (repository == null) {
      return;
    }
    try {
      final Task recreated = await repository.createTask(task);
      if (!mounted) {
        return;
      }
      final int currentIndex = _tasks.indexWhere((Task t) => t.id == task.id);
      if (currentIndex != -1) {
        setState(() {
          _tasks[currentIndex] = recreated;
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _tasks.removeWhere((Task t) => t.id == task.id);
      });
      _showSyncError('Failed to restore task in Google Tasks: $error');
    }
  }

  Future<void> _openTaskForm({Task? task}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        return TaskFormSheet(initialTask: task, now: _now, onSave: _saveTask);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    if (_isCheckingAuth) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Remind Me Again',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(
            key: ValueKey<String>('auth-loading-indicator'),
          ),
        ),
      );
    }

    if (_requiresSignIn) {
      return Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Remind Me Again',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Google Tasks sync',
                style: textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        body: _GoogleSignInView(
          isSigningIn: _isSigningIn,
          errorMessage: _errorMessage,
          onSignIn: _handleSignIn,
        ),
      );
    }

    final List<Task> filtered = _filteredTasks;
    final Map<TaskDateGroup, List<Task>> groupedTasks = _groupTasks(filtered);
    final int activeCount = _countForFilter(TaskFilter.active);
    final int completedCount = _countForFilter(TaskFilter.completed);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                key: const ValueKey<String>('task-search-input'),
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search tasks or notes...',
                  border: InputBorder.none,
                ),
                onChanged: (String value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Remind Me Again',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '$activeCount active • $completedCount completed',
                    style: textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
        actions: <Widget>[
          IconButton(
            key: const ValueKey<String>('toggle-search-button'),
            icon: Icon(
              _isSearching ? Icons.close_rounded : Icons.search_rounded,
            ),
            tooltip: _isSearching ? 'Close search' : 'Search tasks',
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _searchQuery = '';
                }
              });
            },
          ),
          IconButton(
            key: const ValueKey<String>('refresh-tasks-button'),
            icon: const Icon(Icons.sync_rounded),
            tooltip: 'Sync with Google Tasks',
            onPressed: _isLoadingTasks ? null : _loadTasks,
          ),
          if (_authService != null)
            IconButton(
              key: const ValueKey<String>('sign-out-button'),
              icon: const Icon(Icons.logout_rounded),
              tooltip: _currentUser != null
                  ? 'Sign out (${_currentUser!.email})'
                  : 'Sign out',
              onPressed: _handleSignOut,
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _FilterBar(
            selectedFilter: _selectedFilter,
            countBuilder: _countForFilter,
            onFilterSelected: (TaskFilter filter) {
              setState(() {
                _selectedFilter = filter;
              });
            },
          ),
          const Divider(height: 1),
          if (_errorMessage != null)
            MaterialBanner(
              key: const ValueKey<String>('sync-error-banner'),
              backgroundColor: colorScheme.errorContainer,
              content: Text(
                _errorMessage!,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onErrorContainer,
                ),
              ),
              actions: <Widget>[
                TextButton(onPressed: _loadTasks, child: const Text('Retry')),
              ],
            ),
          Expanded(
            child: _isLoadingTasks && _tasks.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(
                      key: ValueKey<String>('tasks-loading-indicator'),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadTasks,
                    child: groupedTasks.isEmpty
                        ? _EmptyTasksState(
                            filter: _selectedFilter,
                            hasSearchQuery: _searchQuery.trim().isNotEmpty,
                            onCreateTask: () => _openTaskForm(),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(top: 8, bottom: 96),
                            itemCount: groupedTasks.length,
                            itemBuilder:
                                (BuildContext context, int sectionIndex) {
                                  final TaskDateGroup group = groupedTasks.keys
                                      .elementAt(sectionIndex);
                                  final List<Task> sectionTasks =
                                      groupedTasks[group]!;

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      _SectionHeader(
                                        group: group,
                                        count: sectionTasks.length,
                                      ),
                                      for (final Task task in sectionTasks)
                                        TaskCard(
                                          key: ValueKey<String>(
                                            'task-card-${task.id}',
                                          ),
                                          task: task,
                                          now: _now,
                                          onToggleStatus: () =>
                                              _toggleTaskStatus(task),
                                          onTap: () =>
                                              _openTaskForm(task: task),
                                          onDelete: () => _deleteTask(task),
                                        ),
                                    ],
                                  );
                                },
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey<String>('add-task-fab'),
        onPressed: () => _openTaskForm(),
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('New Task'),
      ),
    );
  }
}

class _GoogleSignInView extends StatelessWidget {
  const _GoogleSignInView({
    required this.isSigningIn,
    required this.errorMessage,
    required this.onSignIn,
  });

  final bool isSigningIn;
  final String? errorMessage;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cloud_sync_rounded,
                  size: 48,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Connect to Google Tasks',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Sign in with your Google account to store and sync your reminders off device in your default Google Tasks list.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (errorMessage != null) ...<Widget>[
                const SizedBox(height: 20),
                Container(
                  key: const ValueKey<String>('auth-error-message'),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.error_outline_rounded,
                        color: colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          errorMessage!,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28),
              FilledButton.icon(
                key: const ValueKey<String>('google-sign-in-button'),
                onPressed: isSigningIn ? null : onSignIn,
                icon: const Icon(Icons.login_rounded),
                label: Text(
                  isSigningIn ? 'Signing in...' : 'Sign in with Google',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selectedFilter,
    required this.countBuilder,
    required this.onFilterSelected,
  });

  final TaskFilter selectedFilter;
  final int Function(TaskFilter) countBuilder;
  final ValueChanged<TaskFilter> onFilterSelected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: <Widget>[
          for (final TaskFilter filter in TaskFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                key: ValueKey<String>('filter-chip-${filter.name}'),
                selected: selectedFilter == filter,
                showCheckmark: false,
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(filter.label),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: selectedFilter == filter
                            ? colorScheme.primary.withValues(alpha: 0.15)
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${countBuilder(filter)}',
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                onSelected: (_) => onFilterSelected(filter),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.group, required this.count});

  final TaskDateGroup group;
  final int count;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final bool isOverdue = group == TaskDateGroup.overdue;
    final Color color = isOverdue ? colorScheme.error : colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: Row(
        children: <Widget>[
          Icon(group.icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            group.title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '($count)',
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _EmptyTasksState extends StatelessWidget {
  const _EmptyTasksState({
    required this.filter,
    required this.hasSearchQuery,
    required this.onCreateTask,
  });

  final TaskFilter filter;
  final bool hasSearchQuery;
  final VoidCallback onCreateTask;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final String title;
    final String subtitle;

    if (hasSearchQuery) {
      title = 'No matching tasks';
      subtitle = 'Try adjusting your search keywords or filter selection.';
    } else {
      switch (filter) {
        case TaskFilter.all:
          title = 'No tasks yet';
          subtitle = 'Add your first task with a due date or all-day reminder to get started.';
        case TaskFilter.active:
          title = 'All caught up!';
          subtitle = 'You have no active tasks remaining.';
        case TaskFilter.completed:
          title = 'No completed tasks';
          subtitle = 'Tasks you mark as completed will appear here with their completion timestamp.';
      }
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              hasSearchQuery
                  ? Icons.search_off_rounded
                  : Icons.task_alt_rounded,
              size: 64,
              color: colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (!hasSearchQuery && filter != TaskFilter.completed) ...<Widget>[
              const SizedBox(height: 20),
              FilledButton.tonalIcon(
                onPressed: onCreateTask,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add a Task'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
