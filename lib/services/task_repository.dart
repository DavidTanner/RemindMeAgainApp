import '../models/task.dart';

/// Interface for reading and mutating [Task] items in a backing store
/// (such as Google Tasks off-device or an in-memory test store).
abstract class TaskRepository {
  /// Fetches all tasks from the backing store.
  Future<List<Task>> fetchTasks();

  /// Creates [task] in the backing store and returns the persisted [Task]
  /// (including any server-assigned identifier).
  Future<Task> createTask(Task task);

  /// Updates an existing [task] in the backing store and returns the updated [Task].
  Future<Task> updateTask(Task task);

  /// Deletes the task with [taskId] from the backing store.
  Future<void> deleteTask(String taskId);
}

/// In-memory implementation of [TaskRepository] used when `initialTasks`
/// are injected (such as in widget tests).
class InMemoryTaskRepository implements TaskRepository {
  InMemoryTaskRepository([List<Task>? initialTasks])
    : _tasks = List<Task>.from(initialTasks ?? const <Task>[]);

  final List<Task> _tasks;

  @override
  Future<List<Task>> fetchTasks() async {
    return List<Task>.unmodifiable(_tasks);
  }

  @override
  Future<Task> createTask(Task task) async {
    _tasks.insert(0, task);
    return task;
  }

  @override
  Future<Task> updateTask(Task task) async {
    final int index = _tasks.indexWhere((Task t) => t.id == task.id);
    if (index >= 0) {
      _tasks[index] = task;
    } else {
      _tasks.insert(0, task);
    }
    return task;
  }

  @override
  Future<void> deleteTask(String taskId) async {
    _tasks.removeWhere((Task t) => t.id == taskId);
  }
}
