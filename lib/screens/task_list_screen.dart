import 'package:flutter/material.dart';

import '../models/task.dart';
import '../widgets/task_card.dart';
import '../widgets/task_form_sheet.dart';

/// Main screen displaying the user's tasks with status filter chips
/// (All, Active, Completed) and date-based section grouping.
class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key, this.initialTasks, this.referenceNow});

  final List<Task>? initialTasks;
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
  late final List<Task> _tasks;
  TaskFilter _selectedFilter = TaskFilter.all;
  String _searchQuery = '';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  DateTime get _now => widget.referenceNow ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _tasks = List<Task>.from(
      widget.initialTasks ?? TaskListScreen.defaultSampleTasks(_now),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  void _toggleTaskStatus(Task task) {
    final int index = _tasks.indexWhere((Task t) => t.id == task.id);
    if (index == -1) {
      return;
    }
    setState(() {
      _tasks[index] = _tasks[index].toggleStatus(now: _now);
    });
  }

  void _saveTask(Task updatedOrNewTask) {
    final int index = _tasks.indexWhere(
      (Task t) => t.id == updatedOrNewTask.id,
    );
    setState(() {
      if (index >= 0) {
        _tasks[index] = updatedOrNewTask;
      } else {
        _tasks.insert(0, updatedOrNewTask);
      }
    });
  }

  void _deleteTask(Task task) {
    final int index = _tasks.indexWhere((Task t) => t.id == task.id);
    if (index == -1) {
      return;
    }
    setState(() {
      _tasks.removeAt(index);
    });

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted "${task.title}"'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            setState(() {
              final int insertIndex = index.clamp(0, _tasks.length);
              _tasks.insert(insertIndex, task);
            });
          },
        ),
      ),
    );
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
          Expanded(
            child: groupedTasks.isEmpty
                ? _EmptyTasksState(
                    filter: _selectedFilter,
                    hasSearchQuery: _searchQuery.trim().isNotEmpty,
                    onCreateTask: () => _openTaskForm(),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 96),
                    itemCount: groupedTasks.length,
                    itemBuilder: (BuildContext context, int sectionIndex) {
                      final TaskDateGroup group = groupedTasks.keys.elementAt(
                        sectionIndex,
                      );
                      final List<Task> sectionTasks = groupedTasks[group]!;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _SectionHeader(
                            group: group,
                            count: sectionTasks.length,
                          ),
                          for (final Task task in sectionTasks)
                            TaskCard(
                              key: ValueKey<String>('task-card-${task.id}'),
                              task: task,
                              now: _now,
                              onToggleStatus: () => _toggleTaskStatus(task),
                              onTap: () => _openTaskForm(task: task),
                              onDelete: () => _deleteTask(task),
                            ),
                        ],
                      );
                    },
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
