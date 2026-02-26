// ============================================================
// USE CASES — COUCHE DOMAIN
// Chaque use case encapsule une règle métier précise.
// Principe Single Responsibility : un use case = une action.
// ============================================================

import '../entities/task.dart';
import '../repositories/task_repository.dart';

// ─────────────────────────────────────────────
// USE CASE : Récupérer toutes les tâches
// ─────────────────────────────────────────────
class GetAllTasksUseCase {
  final TaskRepository _repository;
  GetAllTasksUseCase(this._repository);

  Future<List<Task>> call() => _repository.getAllTasks();
}

// ─────────────────────────────────────────────
// USE CASE : Récupérer les tâches du jour
// ─────────────────────────────────────────────
class GetTodayTasksUseCase {
  final TaskRepository _repository;
  GetTodayTasksUseCase(this._repository);

  Future<List<Task>> call() => _repository.getTodayTasks();
}

// ─────────────────────────────────────────────
// USE CASE : Récupérer les tâches de demain
// ─────────────────────────────────────────────
class GetTomorrowTasksUseCase {
  final TaskRepository _repository;
  GetTomorrowTasksUseCase(this._repository);

  Future<List<Task>> call() => _repository.getTomorrowTasks();
}

// ─────────────────────────────────────────────
// USE CASE : Créer une tâche
// ─────────────────────────────────────────────
class CreateTaskUseCase {
  final TaskRepository _repository;
  CreateTaskUseCase(this._repository);

  Future<Task> call(Task task) => _repository.createTask(task);
}

// ─────────────────────────────────────────────
// USE CASE : Mettre à jour une tâche
// ─────────────────────────────────────────────
class UpdateTaskUseCase {
  final TaskRepository _repository;
  UpdateTaskUseCase(this._repository);

  Future<Task> call(Task task) => _repository.updateTask(task);
}

// ─────────────────────────────────────────────
// USE CASE : Supprimer une tâche
// ─────────────────────────────────────────────
class DeleteTaskUseCase {
  final TaskRepository _repository;
  DeleteTaskUseCase(this._repository);

  Future<void> call(int id) => _repository.deleteTask(id);
}

// ─────────────────────────────────────────────
// USE CASE : Marquer une tâche comme terminée
// ─────────────────────────────────────────────
class CompleteTaskUseCase {
  final TaskRepository _repository;
  CompleteTaskUseCase(this._repository);

  /// Marque la tâche comme terminée et, si elle est récurrente,
  /// programme automatiquement la prochaine occurrence.
  Future<Task> call(int id) async {
    final task = await _repository.getTaskById(id);
    if (task == null) throw Exception('Tâche introuvable : $id');

    // Marquer comme terminée
    final completedTask = await _repository.markAsCompleted(id);

    // Si récurrente, calculer et enregistrer la prochaine occurrence
    if (completedTask.isRecurring) {
      final nextOccurrence = completedTask.calculateNextOccurrence();
      if (nextOccurrence != null) {
        return _repository.updateNextOccurrence(id, nextOccurrence);
      }
    }

    return completedTask;
  }
}

// ─────────────────────────────────────────────
// USE CASE : Reporter une tâche (Snooze)
// ─────────────────────────────────────────────
class SnoozeTaskUseCase {
  final TaskRepository _repository;

  /// Durée du report par défaut : 10 minutes
  static const Duration defaultSnoozeDuration = Duration(minutes: 10);

  SnoozeTaskUseCase(this._repository);

  /// Reprogramme la tâche 10 minutes plus tard
  Future<Task> call(int id, {Duration? duration}) async {
    final task = await _repository.getTaskById(id);
    if (task == null) throw Exception('Tâche introuvable : $id');

    final snoozeDuration = duration ?? defaultSnoozeDuration;
    final newDateTime = DateTime.now().add(snoozeDuration);

    final snoozedTask = task.copyWith(
      scheduledDateTime: newDateTime,
      isCompleted: false,
    );

    return _repository.updateTask(snoozedTask);
  }
}
