import 'package:flutter/material.dart';

import '../models/task.dart';
import '../utils/date_formatter.dart';

/// A Material 3 card displaying a single [Task] with its title, notes,
/// status badge, due date (all-day or with time), and completed timestamp.
class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.now,
    required this.onToggleStatus,
    required this.onTap,
    required this.onDelete,
  });

  final Task task;
  final DateTime now;
  final VoidCallback onToggleStatus;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool isCompleted = task.isCompleted;
    final bool isOverdue = task.isOverdue(now);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isOverdue
              ? colorScheme.error.withValues(alpha: 0.45)
              : colorScheme.outlineVariant.withValues(alpha: 0.65),
        ),
      ),
      color: isCompleted
          ? colorScheme.surfaceContainerLow
          : colorScheme.surfaceContainerLowest,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Checkbox(
                key: ValueKey<String>('task-checkbox-${task.id}'),
                value: isCompleted,
                onChanged: (_) => onToggleStatus(),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            task.title,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              decoration: isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: isCompleted
                                  ? colorScheme.onSurfaceVariant
                                  : colorScheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusBadge(status: task.status),
                      ],
                    ),
                    if (task.notes.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        task.notes,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          color: isCompleted
                              ? colorScheme.onSurfaceVariant.withValues(
                                  alpha: 0.75,
                                )
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (task.dueDate != null ||
                        task.completedAt != null) ...<Widget>[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: <Widget>[
                          if (task.dueDate != null)
                            _DueDateChip(
                              dueDate: task.dueDate!,
                              isAllDay: task.isAllDay,
                              isOverdue: isOverdue,
                              isCompleted: isCompleted,
                              now: now,
                            ),
                          if (task.completedAt != null)
                            _CompletedTimestampChip(
                              completedAt: task.completedAt!,
                              now: now,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                key: ValueKey<String>('task-delete-${task.id}'),
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                color: colorScheme.onSurfaceVariant,
                tooltip: 'Delete task',
                onPressed: onDelete,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final TaskStatus status;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final bool isCompleted = status == TaskStatus.completed;

    final Color bgColor = isCompleted
        ? colorScheme.secondaryContainer
        : colorScheme.primaryContainer;
    final Color fgColor = isCompleted
        ? colorScheme.onSecondaryContainer
        : colorScheme.onPrimaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: fgColor, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _DueDateChip extends StatelessWidget {
  const _DueDateChip({
    required this.dueDate,
    required this.isAllDay,
    required this.isOverdue,
    required this.isCompleted,
    required this.now,
  });

  final DateTime dueDate;
  final bool isAllDay;
  final bool isOverdue;
  final bool isCompleted;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final String formatted = TaskDateFormatter.formatDueDate(
      dueDate,
      isAllDay: isAllDay,
      now: now,
    );

    final Color backgroundColor;
    final Color foregroundColor;

    if (isCompleted) {
      backgroundColor = colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.6,
      );
      foregroundColor = colorScheme.onSurfaceVariant;
    } else if (isOverdue) {
      backgroundColor = colorScheme.errorContainer;
      foregroundColor = colorScheme.onErrorContainer;
    } else {
      backgroundColor = colorScheme.surfaceContainerHighest;
      foregroundColor = colorScheme.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            isAllDay ? Icons.event_rounded : Icons.schedule_rounded,
            size: 14,
            color: foregroundColor,
          ),
          const SizedBox(width: 5),
          Text(
            formatted,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: foregroundColor,
              fontWeight: isOverdue ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletedTimestampChip extends StatelessWidget {
  const _CompletedTimestampChip({required this.completedAt, required this.now});

  final DateTime completedAt;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final String formatted = TaskDateFormatter.formatCompletedTimestamp(
      completedAt,
      now: now,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.check_circle_outline_rounded,
            size: 14,
            color: colorScheme.onTertiaryContainer,
          ),
          const SizedBox(width: 5),
          Text(
            formatted,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.onTertiaryContainer,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
