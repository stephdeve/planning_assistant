// ============================================================
// ENTITÉ TÂCHE — COUCHE DOMAIN (Clean Architecture)
// Cette classe représente la vérité métier, sans dépendance
// à Flutter, SQLite ou toute infrastructure externe.
// ============================================================

import 'package:flutter/foundation.dart';

/// Types de récurrence possibles pour une tâche
enum RecurrenceType {
  none,       // Tâche unique
  daily,      // Quotidienne
  weekly,     // Hebdomadaire
  hourly,     // Toutes les X heures (voir [recurrenceIntervalHours])
}

/// Représente une tâche planifiée dans le système
@immutable
class Task {
  final int? id;                         // Null avant la première sauvegarde
  final String title;                    // Titre court et descriptif
  final String description;              // Détail de la tâche, lu à voix haute
  final DateTime scheduledDateTime;      // Date + heure exacte de déclenchement
  final RecurrenceType recurrenceType;   // Type de répétition
  final int recurrenceIntervalHours;     // Utilisé si recurrenceType == hourly
  final bool isCompleted;                // Tâche marquée comme terminée
  final bool isActive;                   // Faux si l'utilisateur l'a désactivée
  final DateTime createdAt;              // Date de création
  final DateTime? nextOccurrence;        // Calculée dynamiquement pour les récurrences

  const Task({
    this.id,
    required this.title,
    required this.description,
    required this.scheduledDateTime,
    this.recurrenceType = RecurrenceType.none,
    this.recurrenceIntervalHours = 1,
    this.isCompleted = false,
    this.isActive = true,
    required this.createdAt,
    this.nextOccurrence,
  });

  /// Crée une copie de la tâche avec les champs modifiés
  Task copyWith({
    int? id,
    String? title,
    String? description,
    DateTime? scheduledDateTime,
    RecurrenceType? recurrenceType,
    int? recurrenceIntervalHours,
    bool? isCompleted,
    bool? isActive,
    DateTime? createdAt,
    DateTime? nextOccurrence,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      scheduledDateTime: scheduledDateTime ?? this.scheduledDateTime,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      recurrenceIntervalHours: recurrenceIntervalHours ?? this.recurrenceIntervalHours,
      isCompleted: isCompleted ?? this.isCompleted,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      nextOccurrence: nextOccurrence ?? this.nextOccurrence,
    );
  }

  /// Calcule la prochaine occurrence selon le type de récurrence
  DateTime? calculateNextOccurrence() {
    final now = DateTime.now();
    switch (recurrenceType) {
      case RecurrenceType.none:
        return null;
      case RecurrenceType.daily:
        // Même heure, le lendemain (ou today si pas encore passé)
        var next = scheduledDateTime;
        while (next.isBefore(now)) {
          next = next.add(const Duration(days: 1));
        }
        return next;
      case RecurrenceType.weekly:
        var next = scheduledDateTime;
        while (next.isBefore(now)) {
          next = next.add(const Duration(days: 7));
        }
        return next;
      case RecurrenceType.hourly:
        var next = scheduledDateTime;
        while (next.isBefore(now)) {
          next = next.add(Duration(hours: recurrenceIntervalHours));
        }
        return next;
    }
  }

  /// Vérifie si la tâche est récurrente
  bool get isRecurring => recurrenceType != RecurrenceType.none;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Task &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Task{id: $id, title: $title, scheduledAt: $scheduledDateTime, '
        'recurrence: $recurrenceType}';
  }
}
