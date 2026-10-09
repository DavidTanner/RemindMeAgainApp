import 'package:flutter/material.dart';

import '../models/task.dart';
import '../utils/date_formatter.dart';

/// Modal bottom sheet form for creating a new [Task] or editing an existing one.
class TaskFormSheet extends StatefulWidget {
  const TaskFormSheet({
    super.key,
    this.initialTask,
    required this.now,
    required this.onSave,
    this.onShowDebug,
  });

  final Task? initialTask;
  final DateTime now;
  final ValueChanged<Task> onSave;

  /// When editing an existing task, opens the task debug/JSON view.
  final VoidCallback? onShowDebug;

  @override
  State<TaskFormSheet> createState() => _TaskFormSheetState();
}

class _TaskFormSheetState extends State<TaskFormSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;

  late TaskStatus _status;
  late DateTime? _completedAt;
  late bool _hasDueDate;
  late DateTime _selectedDueDate;
  late TimeOfDay _selectedDueTime;
  late bool _isAllDay;

  bool get _isEditing => widget.initialTask != null;

  @override
  void initState() {
    super.initState();
    final Task? task = widget.initialTask;
    _titleController = TextEditingController(text: task?.title ?? '');
    _notesController = TextEditingController(text: task?.notes ?? '');
    _status = task?.status ?? TaskStatus.active;
    _completedAt = task?.completedAt;

    if (task?.dueDate != null) {
      _hasDueDate = true;
      final DateTime due = task!.dueDate!;
      _selectedDueDate = DateTime(due.year, due.month, due.day);
      _selectedDueTime = TimeOfDay(hour: due.hour, minute: due.minute);
      _isAllDay = task.isAllDay;
    } else {
      _hasDueDate = true;
      _selectedDueDate = DateTime(
        widget.now.year,
        widget.now.month,
        widget.now.day,
      );
      _selectedDueTime = const TimeOfDay(hour: 17, minute: 0);
      _isAllDay = true;
      if (task != null && task.dueDate == null) {
        _hasDueDate = false;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDueDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  Future<void> _pickDueTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedDueTime,
    );
    if (picked != null) {
      setState(() {
        _selectedDueTime = picked;
      });
    }
  }

  Future<void> _pickCompletedTimestamp() async {
    final DateTime currentCompleted = _completedAt ?? widget.now;
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: currentCompleted,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null || !mounted) {
      return;
    }
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(currentCompleted),
    );
    if (pickedTime == null || !mounted) {
      return;
    }
    setState(() {
      _completedAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  void _handleSubmit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    DateTime? finalDueDate;
    if (_hasDueDate) {
      if (_isAllDay) {
        finalDueDate = DateTime(
          _selectedDueDate.year,
          _selectedDueDate.month,
          _selectedDueDate.day,
        );
      } else {
        finalDueDate = DateTime(
          _selectedDueDate.year,
          _selectedDueDate.month,
          _selectedDueDate.day,
          _selectedDueTime.hour,
          _selectedDueTime.minute,
        );
      }
    }

    final DateTime? finalCompletedAt = _status == TaskStatus.completed
        ? (_completedAt ?? widget.now)
        : null;

    final Task result = Task(
      id:
          widget.initialTask?.id ??
          'task-${DateTime.now().microsecondsSinceEpoch}',
      title: _titleController.text.trim(),
      notes: _notesController.text.trim(),
      status: _status,
      completedAt: finalCompletedAt,
      dueDate: finalDueDate,
      isAllDay: _isAllDay,
    );

    widget.onSave(result);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final DateTime previewDueDateTime = DateTime(
      _selectedDueDate.year,
      _selectedDueDate.month,
      _selectedDueDate.day,
      _selectedDueTime.hour,
      _selectedDueTime.minute,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    _isEditing ? 'Edit Task' : 'New Task',
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (_isEditing && widget.onShowDebug != null)
                        IconButton(
                          key: const ValueKey<String>('task-debug-button'),
                          icon: const Icon(Icons.data_object_rounded),
                          onPressed: widget.onShowDebug,
                          tooltip: 'Show task JSON',
                        ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey<String>('task-title-input'),
                controller: _titleController,
                autofocus: !_isEditing,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Title',
                  hintText: 'What do you need to be reminded of?',
                  prefixIcon: const Icon(Icons.title_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a task title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey<String>('task-notes-input'),
                controller: _notesController,
                maxLines: 3,
                minLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Notes',
                  hintText: 'Add details, links, or context...',
                  alignLabelWithHint: true,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 24),
                    child: Icon(Icons.notes_rounded),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Status',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<TaskStatus>(
                key: const ValueKey<String>('task-status-segmented'),
                segments: const <ButtonSegment<TaskStatus>>[
                  ButtonSegment<TaskStatus>(
                    value: TaskStatus.active,
                    label: Text('Active'),
                    icon: Icon(Icons.radio_button_unchecked_rounded),
                  ),
                  ButtonSegment<TaskStatus>(
                    value: TaskStatus.completed,
                    label: Text('Completed'),
                    icon: Icon(Icons.check_circle_outline_rounded),
                  ),
                ],
                selected: <TaskStatus>{_status},
                onSelectionChanged: (Set<TaskStatus> selection) {
                  final TaskStatus newStatus = selection.first;
                  setState(() {
                    _status = newStatus;
                    if (newStatus == TaskStatus.completed) {
                      _completedAt ??= widget.now;
                    } else {
                      _completedAt = null;
                    }
                  });
                },
              ),
              if (_status == TaskStatus.completed) ...<Widget>[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.tertiaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.done_all_rounded,
                        size: 18,
                        color: colorScheme.onTertiaryContainer,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          TaskDateFormatter.formatCompletedTimestamp(
                            _completedAt ?? widget.now,
                            now: widget.now,
                          ),
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onTertiaryContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _pickCompletedTimestamp,
                        child: const Text('Change'),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Card(
                margin: EdgeInsets.zero,
                elevation: 0,
                color: colorScheme.surfaceContainerLow,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
                child: Column(
                  children: <Widget>[
                    SwitchListTile(
                      key: const ValueKey<String>('task-has-due-date-switch'),
                      title: Text(
                        'Due Date',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        _hasDueDate
                            ? TaskDateFormatter.formatDueDate(
                                previewDueDateTime,
                                isAllDay: _isAllDay,
                                now: widget.now,
                              )
                            : 'No due date set',
                      ),
                      secondary: const Icon(Icons.calendar_today_rounded),
                      value: _hasDueDate,
                      onChanged: (bool value) {
                        setState(() {
                          _hasDueDate = value;
                        });
                      },
                    ),
                    if (_hasDueDate) ...<Widget>[
                      const Divider(height: 1),
                      SwitchListTile(
                        key: const ValueKey<String>('task-all-day-switch'),
                        title: const Text('All-day'),
                        subtitle: Text(
                          _isAllDay
                              ? 'Due for the entire day'
                              : 'Includes a specific due time',
                        ),
                        secondary: Icon(
                          _isAllDay
                              ? Icons.wb_sunny_outlined
                              : Icons.schedule_rounded,
                        ),
                        value: _isAllDay,
                        onChanged: (bool value) {
                          setState(() {
                            _isAllDay = value;
                          });
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: OutlinedButton.icon(
                                key: const ValueKey<String>('pick-date-button'),
                                onPressed: _pickDueDate,
                                icon: const Icon(Icons.event_rounded, size: 18),
                                label: Text(
                                  TaskDateFormatter.formatFullDate(
                                    _selectedDueDate,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            if (!_isAllDay) ...<Widget>[
                              const SizedBox(width: 10),
                              OutlinedButton.icon(
                                key: const ValueKey<String>('pick-time-button'),
                                onPressed: _pickDueTime,
                                icon: const Icon(
                                  Icons.access_time_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  TaskDateFormatter.formatTime(
                                    previewDueDateTime,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      key: const ValueKey<String>('save-task-button'),
                      onPressed: _handleSubmit,
                      icon: const Icon(Icons.check_rounded),
                      label: Text(_isEditing ? 'Save Changes' : 'Create Task'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
