// ============================================================
// MODÈLE DE DONNÉES — COUCHE DATA
// TaskModel étend Task pour ajouter la sérialisation SQLite.
// On sépare bien le "modèle de transfert" (data layer) de
// l'"entité métier" (domain layer) — principe Clean Arch.
// ============================================================

import '../../domain/entities/task.dart';

/// Extension de l'entité Task avec les capacités de sérialisation SQLite.
/// Cette classe fait le pont entre la base de données et le domaine.
class TaskModel extends Task {
  const TaskModel({
    super.id,
    required super.title,
    required super.description,
    required super.scheduledDateTime,
    super.recurrenceType,
    super.recurrenceIntervalHours,
    super.isCompleted,
    super.isActive,
    required super.createdAt,
    super.nextOccurrence,
  });

  // ─────────────────────────────────────────────────────────
  // MAPPING DEPUIS UN MAP SQLite (résultat d'une requête)
  // ─────────────────────────────────────────────────────────
  factory TaskModel.fromMap(Map<String, dynamic> map) {
    return TaskModel(
      id: map['id'] as int?,
      title: map['title'] as String,
      description: map['description'] as String,
      // SQLite stocke les dates en millisecondes depuis epoch
      scheduledDateTime: DateTime.fromMillisecondsSinceEpoch(
        map['scheduled_date_time'] as int,
      ),
      // La récurrence est stockée comme un entier (index de l'enum)
      recurrenceType: RecurrenceType.values[map['recurrence_type'] as int],
      recurrenceIntervalHours: map['recurrence_interval_hours'] as int,
      // SQLite stocke les booléens comme 0/1
      isCompleted: (map['is_completed'] as int) == 1,
      isActive: (map['is_active'] as int) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['created_at'] as int,
      ),
      nextOccurrence: map['next_occurrence'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['next_occurrence'] as int,
            )
          : null,
    );
  }

  // ─────────────────────────────────────────────────────────
  // MAPPING VERS UN MAP SQLite (pour INSERT / UPDATE)
  // ─────────────────────────────────────────────────────────
  Map<String, dynamic> toMap() {
    return {
      // On n'inclut pas 'id' pour l'auto-incrémentation SQLite
      if (id != null) 'id': id,
      'title': title,
      'description': description,
      'scheduled_date_time': scheduledDateTime.millisecondsSinceEpoch,
      'recurrence_type': recurrenceType.index,
      'recurrence_interval_hours': recurrenceIntervalHours,
      'is_completed': isCompleted ? 1 : 0,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'next_occurrence': nextOccurrence?.millisecondsSinceEpoch,
    };
  }

  // ─────────────────────────────────────────────────────────
  // CONVERSION DEPUIS UNE ENTITÉ DOMAIN
  // ─────────────────────────────────────────────────────────
  factory TaskModel.fromEntity(Task task) {
    return TaskModel(
      id: task.id,
      title: task.title,
      description: task.description,
      scheduledDateTime: task.scheduledDateTime,
      recurrenceType: task.recurrenceType,
      recurrenceIntervalHours: task.recurrenceIntervalHours,
      isCompleted: task.isCompleted,
      isActive: task.isActive,
      createdAt: task.createdAt,
      nextOccurrence: task.nextOccurrence,
    );
  }

  /// Convertit ce modèle en entité domain pure
  Task toEntity() {
    return Task(
      id: id,
      title: title,
      description: description,
      scheduledDateTime: scheduledDateTime,
      recurrenceType: recurrenceType,
      recurrenceIntervalHours: recurrenceIntervalHours,
      isCompleted: isCompleted,
      isActive: isActive,
      createdAt: createdAt,
      nextOccurrence: nextOccurrence,
    );
  }
}
