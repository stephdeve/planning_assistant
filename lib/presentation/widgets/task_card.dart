import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/task.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback? onComplete;
  final VoidCallback? onSnooze;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onTestReminder;
  final bool showDate;

  const TaskCard({
    super.key,
    required this.task,
    this.onComplete,
    this.onSnooze,
    this.onEdit,
    this.onDelete,
    this.onTestReminder,
    this.showDate = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final timeFormatter = DateFormat('HH:mm');
    final dateFormatter = DateFormat('d MMM', 'fr_FR');

    Color accentColor;
    if (task.isCompleted) {
      accentColor = Colors.green;
    } else if (_isOverdue()) {
      accentColor = cs.error;
    } else {
      accentColor = cs.primary;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: task.isCompleted
                  ? Colors.green.withValues(alpha: 0.2)
                  : _isOverdue()
                      ? cs.error.withValues(alpha: 0.3)
                      : cs.outlineVariant.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // ─── Accent bar ──────────────────────────────
                Container(
                  width: 4,
                  height: 52,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 14),

                // ─── Content ─────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.schedule_rounded,
                              size: 13, color: accentColor),
                          const SizedBox(width: 4),
                          Text(
                            showDate
                                ? '${dateFormatter.format(task.scheduledDateTime)} · ${timeFormatter.format(task.scheduledDateTime)}'
                                : timeFormatter.format(task.scheduledDateTime),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: accentColor,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const Spacer(),
                          if (task.isRecurring)
                            _Badge(
                              label: _recurrenceLabel(task),
                              icon: Icons.repeat_rounded,
                              color: Colors.blue,
                            ),
                          if (task.isCompleted)
                            const _Badge(
                              label: 'Fait',
                              icon: Icons.check_circle_rounded,
                              color: Colors.green,
                            ),
                          if (_isOverdue() && !task.isCompleted)
                            _Badge(
                              label: 'En retard',
                              icon: Icons.warning_amber_rounded,
                              color: cs.error,
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        task.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: task.isCompleted ? cs.outline : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        task.description,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.outline),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // ─── Actions ─────────────────────────────────
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!task.isCompleted && onComplete != null)
                      _IconBtn(
                        icon: Icons.check_circle_outline_rounded,
                        color: Colors.green,
                        tooltip: 'Terminer',
                        onTap: onComplete!,
                      ),
                    if (!task.isCompleted && onSnooze != null)
                      _IconBtn(
                        icon: Icons.snooze_rounded,
                        color: Colors.orange,
                        tooltip: 'Reporter',
                        onTap: onSnooze!,
                      ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert_rounded,
                          size: 18, color: cs.outline),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      onSelected: (v) {
                        if (v == 'edit') onEdit?.call();
                        if (v == 'delete') onDelete?.call();
                        if (v == 'complete') onComplete?.call();
                        if (v == 'snooze') onSnooze?.call();
                        if (v == 'test') onTestReminder?.call();
                      },
                      itemBuilder: (_) => [
                        if (!task.isCompleted) ...[
                          _menuItem('complete', Icons.check_circle_rounded,
                              'Terminer', Colors.green),
                          _menuItem('snooze', Icons.snooze_rounded,
                              'Reporter 10 min', Colors.orange),
                          _menuItem('test', Icons.volume_up_rounded,
                              'Tester le rappel 🔔', cs.primary),
                        ],
                        _menuItem(
                            'edit', Icons.edit_rounded, 'Modifier', cs.onSurface),
                        if (onDelete != null)
                          _menuItem('delete', Icons.delete_rounded,
                              'Supprimer', cs.error),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(
      String value, IconData icon, String label, Color color) {
    return PopupMenuItem(
      value: value,
      padding: EdgeInsets.zero,
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: color, size: 20),
        title: Text(label,
            style: TextStyle(
                color: color == Colors.red ? color : null,
                fontWeight: FontWeight.w500)),
      ),
    );
  }

  bool _isOverdue() =>
      task.scheduledDateTime.isBefore(DateTime.now()) && !task.isCompleted;

  String _recurrenceLabel(Task t) {
    switch (t.recurrenceType) {
      case RecurrenceType.daily:
        return '/ jour';
      case RecurrenceType.weekly:
        return '/ sem.';
      case RecurrenceType.hourly:
        return '/ ${t.recurrenceIntervalHours}h';
      case RecurrenceType.none:
        return '';
    }
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _Badge({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 10, color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  const _IconBtn(
      {required this.icon,
      required this.color,
      required this.tooltip,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 22, color: color),
        ),
      ),
    );
  }
}
