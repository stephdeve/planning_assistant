// ============================================================
// WIDGET CARTE DE TÂCHE — COMPOSANT RÉUTILISABLE
// Affiche une tâche avec ses informations, son état et
// ses actions rapides. Design adaptatif selon le contexte.
// ============================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/task.dart';

/// Carte affichant une tâche avec toutes ses métadonnées et actions.
/// [showDate] : afficher ou non la date complète (pas utile si déjà dans un groupe par date)
class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback? onComplete;
  final VoidCallback? onSnooze;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool showDate;

  const TaskCard({
    super.key,
    required this.task,
    this.onComplete,
    this.onSnooze,
    this.onEdit,
    this.onDelete,
    this.showDate = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeFormatter = DateFormat('HH:mm');
    final dateFormatter = DateFormat('d MMM', 'fr_FR');

    // Couleur de l'indicateur gauche selon l'état
    final statusColor = task.isCompleted
        ? Colors.green
        : _isOverdue()
            ? Colors.red
            : theme.colorScheme.primary;

    return Card(
      // Légèrement transparent si terminée
      color: task.isCompleted
          ? theme.colorScheme.surface.withOpacity(0.7)
          : theme.colorScheme.surface,
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Indicateur de statut ─────────────────────────
              Container(
                width: 4,
                height: 60,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),

              // ─── Contenu principal ────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ligne du haut : heure + badges
                    Row(
                      children: [
                        Icon(Icons.access_time,
                            size: 14, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          showDate
                              ? '${dateFormatter.format(task.scheduledDateTime)} ${timeFormatter.format(task.scheduledDateTime)}'
                              : timeFormatter.format(task.scheduledDateTime),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        // Badge récurrence
                        if (task.isRecurring)
                          _Badge(
                            label: _recurrenceShortLabel(task),
                            icon: Icons.repeat,
                            color: Colors.blue,
                          ),
                        // Badge terminé
                        if (task.isCompleted)
                          const _Badge(
                            label: 'Terminé',
                            icon: Icons.check,
                            color: Colors.green,
                          ),
                        // Badge en retard
                        if (_isOverdue() && !task.isCompleted)
                          const _Badge(
                            label: 'En retard',
                            icon: Icons.warning_amber,
                            color: Colors.red,
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Titre
                    Text(
                      task.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        // Barré si terminée
                        decoration: task.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: task.isCompleted
                            ? theme.colorScheme.outline
                            : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),

                    // Description (tronquée à 2 lignes)
                    Text(
                      task.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // ─── Actions rapides ──────────────────────────────
              if (!task.isCompleted)
                Column(
                  children: [
                    // Bouton "Terminer"
                    if (onComplete != null)
                      _ActionButton(
                        icon: Icons.check_circle_outline,
                        tooltip: 'Terminer',
                        color: Colors.green,
                        onTap: onComplete!,
                      ),
                    // Bouton "Reporter"
                    if (onSnooze != null)
                      _ActionButton(
                        icon: Icons.snooze,
                        tooltip: 'Reporter 10 min',
                        color: Colors.orange,
                        onTap: onSnooze!,
                      ),
                  ],
                ),

              // Menu contextuel (plus d'options)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18),
                onSelected: (value) {
                  if (value == 'edit') onEdit?.call();
                  if (value == 'delete') onDelete?.call();
                  if (value == 'complete') onComplete?.call();
                  if (value == 'snooze') onSnooze?.call();
                },
                itemBuilder: (_) => [
                  if (!task.isCompleted) ...[
                    const PopupMenuItem(
                      value: 'complete',
                      child: ListTile(
                        leading: Icon(Icons.check_circle, color: Colors.green),
                        title: Text('Terminer'),
                        dense: true,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'snooze',
                      child: ListTile(
                        leading: Icon(Icons.snooze, color: Colors.orange),
                        title: Text('Reporter 10 min'),
                        dense: true,
                      ),
                    ),
                  ],
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Modifier'),
                      dense: true,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline, color: Colors.red),
                      title: Text('Supprimer',
                          style: TextStyle(color: Colors.red)),
                      dense: true,
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

  bool _isOverdue() {
    return task.scheduledDateTime.isBefore(DateTime.now()) &&
        !task.isCompleted;
  }

  String _recurrenceShortLabel(Task task) {
    switch (task.recurrenceType) {
      case RecurrenceType.daily:
        return '/ jour';
      case RecurrenceType.weekly:
        return '/ semaine';
      case RecurrenceType.hourly:
        return '/ ${task.recurrenceIntervalHours}h';
      case RecurrenceType.none:
        return '';
    }
  }
}

// ─────────────────────────────────────────────────────────
// COMPOSANTS INTERNES
// ─────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _Badge({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20, color: color),
      tooltip: tooltip,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
    );
  }
}
