import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/task.dart';
import '../utils/date_formatter.dart';

/// Signature for loading the latest raw backing-store JSON of a task.
typedef TaskJsonLoader = Future<Map<String, dynamic>?> Function();

/// Debug bottom sheet showing the values the app derived for a [Task]
/// (due date, activation time, where the time came from) alongside the raw
/// Google Tasks API JSON response for that task.
class TaskDebugSheet extends StatefulWidget {
  const TaskDebugSheet({
    super.key,
    required this.task,
    required this.now,
    this.fetchJson,
    this.onJsonFetched,
  });

  final Task task;
  final DateTime now;

  /// Loads a fresh copy of the task JSON from the backing store. When `null`
  /// the refresh action is hidden and only the cached JSON is shown.
  final TaskJsonLoader? fetchJson;

  /// Called with the JSON returned by [fetchJson] so the caller can keep its
  /// cached copy up to date.
  final ValueChanged<Map<String, dynamic>>? onJsonFetched;

  @override
  State<TaskDebugSheet> createState() => _TaskDebugSheetState();
}

class _TaskDebugSheetState extends State<TaskDebugSheet> {
  static const JsonEncoder _encoder = JsonEncoder.withIndent('  ');

  Map<String, dynamic>? _json;
  bool _isRefreshing = false;
  bool _isFresh = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _json = widget.task.rawJson;
  }

  String? get _prettyJson {
    final Map<String, dynamic>? json = _json;
    if (json == null) {
      return null;
    }
    return _encoder.convert(json);
  }

  Future<void> _refresh() async {
    final TaskJsonLoader? loader = widget.fetchJson;
    if (loader == null || _isRefreshing) {
      return;
    }
    setState(() {
      _isRefreshing = true;
      _errorMessage = null;
    });
    try {
      final Map<String, dynamic>? fetched = await loader();
      if (!mounted) {
        return;
      }
      setState(() {
        _isRefreshing = false;
        _json = fetched;
        _isFresh = fetched != null;
        if (fetched == null) {
          _errorMessage = 'The backing store returned no JSON for this task.';
        }
      });
      if (fetched != null) {
        widget.onJsonFetched?.call(fetched);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isRefreshing = false;
        _errorMessage = 'Failed to fetch task JSON: $error';
      });
    }
  }

  Future<void> _copyJson() async {
    final String? pretty = _prettyJson;
    if (pretty == null) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: pretty));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Task JSON copied')));
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Task task = widget.task;
    final DateTime now = widget.now;
    final DateTime? activatesAt = task.activatesAt;
    final String? pretty = _prettyJson;

    return SizedBox(
      key: const ValueKey<String>('task-debug-sheet'),
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 12, 0),
            child: Column(
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
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Task debug',
                            style: textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            task.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
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
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const _SectionTitle(
                    icon: Icons.schedule_rounded,
                    title: 'Derived schedule',
                  ),
                  const SizedBox(height: 8),
                  _InfoCard(
                    rows: <_InfoRow>[
                      _InfoRow('Task ID', task.id),
                      _InfoRow('Status', task.status.label),
                      _InfoRow(
                        'Due',
                        task.dueDate == null
                            ? 'No due date'
                            : TaskDateFormatter.formatDueDate(
                                task.dueDate!,
                                isAllDay: task.isAllDay,
                                now: now,
                              ),
                      ),
                      _InfoRow('All-day', task.isAllDay ? 'Yes' : 'No'),
                      _InfoRow('Due time source', task.dueTimeSource.label),
                      _InfoRow(
                        'Activates',
                        activatesAt == null
                            ? 'Immediately (no due date)'
                            : TaskDateFormatter.formatActivation(
                                activatesAt,
                                isAllDay: task.isAllDay,
                                now: now,
                              ),
                        key: const ValueKey<String>('task-debug-activates'),
                      ),
                      _InfoRow(
                        'Activation state',
                        task.isCompleted
                            ? 'Completed'
                            : task.isPendingActivation(now)
                            ? 'Pending (not yet active)'
                            : 'Active now',
                      ),
                      _InfoRow('Overdue', task.isOverdue(now) ? 'Yes' : 'No'),
                      if (task.completedAt != null)
                        _InfoRow(
                          'Completed at',
                          TaskDateFormatter.formatCompletedTimestamp(
                            task.completedAt!,
                            now: now,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: <Widget>[
                      const Expanded(
                        child: _SectionTitle(
                          icon: Icons.data_object_rounded,
                          title: 'Raw API JSON',
                        ),
                      ),
                      IconButton(
                        key: const ValueKey<String>('task-debug-copy-button'),
                        icon: const Icon(Icons.copy_rounded, size: 20),
                        tooltip: 'Copy JSON',
                        onPressed: pretty == null ? null : _copyJson,
                        visualDensity: VisualDensity.compact,
                      ),
                      if (widget.fetchJson != null)
                        IconButton(
                          key: const ValueKey<String>(
                            'task-debug-refresh-button',
                          ),
                          icon: _isRefreshing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh_rounded, size: 20),
                          tooltip: 'Fetch latest from API',
                          onPressed: _isRefreshing ? null : _refresh,
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  Text(
                    _isFresh
                        ? 'Fetched from the API just now.'
                        : pretty == null
                        ? 'No API response cached for this task.'
                        : 'Cached from the last sync. '
                              'Refresh to fetch the latest response.',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (_errorMessage != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Container(
                      key: const ValueKey<String>('task-debug-error'),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SelectableText(
                      pretty ??
                          'This task has not been synced with Google Tasks yet, '
                              'so there is no API response to show.',
                      key: const ValueKey<String>('task-debug-json'),
                      style: textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        fontFamilyFallback: const <String>[
                          'Menlo',
                          'Courier New',
                        ],
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Note: the Google Tasks API documents that the time portion '
                    'of "due" is discarded, so a time chosen in Google Calendar '
                    'normally arrives as T00:00:00.000Z. Check the "due" value '
                    'above to confirm what Google returned for this task.',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        Icon(icon, size: 18, color: colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _InfoRow {
  const _InfoRow(this.label, this.value, {this.key});

  final String label;
  final String value;
  final Key? key;
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.rows});

  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        children: <Widget>[
          for (final _InfoRow row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 128,
                    child: Text(
                      row.label,
                      style: textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SelectableText(
                      row.value,
                      key: row.key,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
