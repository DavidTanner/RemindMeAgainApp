import 'package:flutter/material.dart';

import '../models/task.dart';
import '../utils/date_formatter.dart';

/// Modal dialog presented when a [Task] alarm goes off, allowing the user
/// to snooze the alarm for a chosen duration, dismiss it, or mark the task
/// as completed.
class AlarmRingDialog extends StatefulWidget {
  const AlarmRingDialog({
    super.key,
    required this.task,
    required this.now,
    required this.onSnooze,
    required this.onDismiss,
    required this.onComplete,
  });

  final Task task;
  final DateTime now;
  final ValueChanged<Duration> onSnooze;
  final VoidCallback onDismiss;
  final VoidCallback onComplete;

  @override
  State<AlarmRingDialog> createState() => _AlarmRingDialogState();
}

class _AlarmRingDialogState extends State<AlarmRingDialog> {
  late int _selectedSnoozeMinutes;

  @override
  void initState() {
    super.initState();
    _selectedSnoozeMinutes = widget.task.snoozeDurationMinutes;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final DateTime? alarmTime = widget.task.effectiveAlarmTime;

    return Dialog(
      key: const ValueKey<String>('alarm-ring-dialog'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.notifications_active_rounded,
                    size: 30,
                    color: colorScheme.onErrorContainer,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Alarm',
                style: textTheme.labelLarge?.copyWith(
                  color: colorScheme.error,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                widget.task.title,
                key: const ValueKey<String>('alarm-dialog-title'),
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              if (widget.task.notes.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  widget.task.notes,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (alarmTime != null) ...<Widget>[
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.alarm_rounded,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          TaskDateFormatter.formatDueDate(
                            alarmTime,
                            isAllDay: false,
                            now: widget.now,
                          ),
                          style: textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Text(
                'Snooze duration',
                style: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final int minutes in Task.presetSnoozeMinutes)
                    ChoiceChip(
                      key: ValueKey<String>('snooze-preset-$minutes'),
                      label: Text(
                        TaskDateFormatter.formatSnoozeDuration(minutes),
                      ),
                      selected: _selectedSnoozeMinutes == minutes,
                      showCheckmark: false,
                      onSelected: (_) {
                        setState(() {
                          _selectedSnoozeMinutes = minutes;
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const ValueKey<String>('alarm-snooze-button'),
                onPressed: () {
                  widget.onSnooze(Duration(minutes: _selectedSnoozeMinutes));
                },
                icon: const Icon(Icons.snooze_rounded),
                label: Text(
                  'Snooze (${TaskDateFormatter.formatSnoozeDuration(_selectedSnoozeMinutes)})',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey<String>('alarm-dismiss-button'),
                      onPressed: widget.onDismiss,
                      icon: const Icon(Icons.notifications_off_outlined),
                      label: const Text('Dismiss'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      key: const ValueKey<String>('alarm-complete-button'),
                      onPressed: widget.onComplete,
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: const Text('Complete'),
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
