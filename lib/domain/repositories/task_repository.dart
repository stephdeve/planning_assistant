// ============================================================
// INTERFACE DU REPOSITORY — COUCHE DOMAIN
// Définit le "contrat" que la couche data doit respecter.
// La couche domain ne sait pas comment les données sont stockées.
// ============================================================

import '../entities/task.dart';

/// Interface abstraite du repository de tâches.
/// Toute implémentation concrète (SQLite, Hive, mock...) doit
/// respecter ce contrat.
abstract class TaskRepository {
  /// Récupère toutes les tâches (actives et inactives)
  Future<List<Task>> getAllTasks();

  /// Récupère uniquement les tâches actives non terminées
  Future<List<Task>> getActiveTasks();

  /// Récupère les tâches planifiées pour aujourd'hui
  Future<List<Task>> getTodayTasks();

  /// Récupère les tâches planifiées pour demain
  Future<List<Task>> getTomorrowTasks();

  /// Récupère une tâche par son identifiant
  Future<Task?> getTaskById(int id);

  /// Persiste une nouvelle tâche et retourne l'entité avec son id généré
  Future<Task> createTask(Task task);

  /// Met à jour une tâche existante
  Future<Task> updateTask(Task task);

  /// Supprime une tâche définitivement
  Future<void> deleteTask(int id);

  /// Marque une tâche comme terminée
  Future<Task> markAsCompleted(int id);

  /// Met à jour la prochaine occurrence d'une tâche récurrente
  Future<Task> updateNextOccurrence(int id, DateTime nextOccurrence);

  /// Écoute les changements en temps réel (stream pour Riverpod)
  Stream<List<Task>> watchAllTasks();
}
