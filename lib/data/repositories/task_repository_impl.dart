// ============================================================
// IMPLÉMENTATION DU REPOSITORY — COUCHE DATA
// Implémente l'interface TaskRepository avec SQLite comme
// source de vérité. La couche domain ne connaît pas SQLite.
// ============================================================

import 'dart:async';
import '../../domain/entities/task.dart';
import '../../domain/repositories/task_repository.dart';
import '../datasources/database_helper.dart';
import '../models/task_model.dart';

/// Implémentation concrète de [TaskRepository] utilisant SQLite
/// via [DatabaseHelper].
class TaskRepositoryImpl implements TaskRepository {
  final DatabaseHelper _dbHelper;

  // StreamController pour émettre les changements en temps réel
  // (permet aux ViewModels d'écouter les mises à jour automatiquement)
  final _tasksStreamController =
      StreamController<List<Task>>.broadcast();

  TaskRepositoryImpl({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper();

  // ─── Utilitaire : notifie tous les auditeurs du stream ──
  Future<void> _notifyListeners() async {
    final tasks = await getAllTasks();
    _tasksStreamController.add(tasks);
  }

  @override
  Future<List<Task>> getAllTasks() async {
    final rows = await _dbHelper.queryAll();
    return rows.map((row) => TaskModel.fromMap(row).toEntity()).toList();
  }

  @override
  Future<List<Task>> getActiveTasks() async {
    final all = await getAllTasks();
    return all.where((t) => t.isActive && !t.isCompleted).toList();
  }

  @override
  Future<List<Task>> getTodayTasks() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final rows = await _dbHelper.queryByDateRange(
      startOfDay.millisecondsSinceEpoch,
      endOfDay.millisecondsSinceEpoch,
    );

    return rows.map((row) => TaskModel.fromMap(row).toEntity()).toList();
  }

  @override
  Future<List<Task>> getTomorrowTasks() async {
    final now = DateTime.now();
    final startOfTomorrow = DateTime(now.year, now.month, now.day + 1);
    final endOfTomorrow = startOfTomorrow.add(const Duration(days: 1));

    final rows = await _dbHelper.queryByDateRange(
      startOfTomorrow.millisecondsSinceEpoch,
      endOfTomorrow.millisecondsSinceEpoch,
    );

    return rows.map((row) => TaskModel.fromMap(row).toEntity()).toList();
  }

  @override
  Future<Task?> getTaskById(int id) async {
    final row = await _dbHelper.queryById(id);
    if (row == null) return null;
    return TaskModel.fromMap(row).toEntity();
  }

  @override
  Future<Task> createTask(Task task) async {
    final model = TaskModel.fromEntity(task);
    final id = await _dbHelper.insert(model.toMap());

    final createdTask = task.copyWith(id: id);
    await _notifyListeners();
    return createdTask;
  }

  @override
  Future<Task> updateTask(Task task) async {
    if (task.id == null) throw Exception('Impossible de mettre à jour une tâche sans id');

    final model = TaskModel.fromEntity(task);
    await _dbHelper.update(model.toMap(), task.id!);

    await _notifyListeners();
    return task;
  }

  @override
  Future<void> deleteTask(int id) async {
    await _dbHelper.delete(id);
    await _notifyListeners();
  }

  @override
  Future<Task> markAsCompleted(int id) async {
    final task = await getTaskById(id);
    if (task == null) throw Exception('Tâche introuvable : $id');

    final completedTask = task.copyWith(isCompleted: true);
    return updateTask(completedTask);
  }

  @override
  Future<Task> updateNextOccurrence(int id, DateTime nextOccurrence) async {
    final task = await getTaskById(id);
    if (task == null) throw Exception('Tâche introuvable : $id');

    final updatedTask = task.copyWith(
      nextOccurrence: nextOccurrence,
      // Réinitialiser isCompleted pour la prochaine occurrence
      isCompleted: false,
      scheduledDateTime: nextOccurrence,
    );
    return updateTask(updatedTask);
  }

  @override
  Stream<List<Task>> watchAllTasks() {
    // Émettre une valeur initiale immédiatement
    getAllTasks().then((tasks) {
      if (!_tasksStreamController.isClosed) {
        _tasksStreamController.add(tasks);
      }
    });
    return _tasksStreamController.stream;
  }

  /// Libère les ressources (appeler en cas de dispose)
  void dispose() {
    _tasksStreamController.close();
  }
}
