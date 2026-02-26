import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/task.dart';
import '../viewmodels/task_viewmodel.dart';
import 'task_form_page.dart';
import '../widgets/task_card.dart';

enum TaskFilter { all, today, pending, completed, recurring }

class TasksListPage extends ConsumerStatefulWidget {
  const TasksListPage({super.key});
  @override
  ConsumerState<TasksListPage> createState() => _TasksListPageState();
}

class _TasksListPageState extends ConsumerState<TasksListPage> {
  TaskFilter _filter = TaskFilter.today;

  @override
  Widget build(BuildContext context) {
    final taskState = ref.watch(taskViewModelProvider);
    final tasks = _apply(taskState.allTasks);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ─── AppBar ─────────────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: cs.surface,
            title: Text('Mes tâches',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: _FilterRow(
                current: _filter,
                onChanged: (f) => setState(() => _filter = f),
              ),
            ),
          ),

          if (taskState.isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (tasks.isEmpty)
            SliverFillRemaining(child: _EmptyState(filter: _filter))
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              sliver: SliverList.separated(
                itemCount: tasks.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) {
                  final task = tasks[i];
                  return TaskCard(
                    task: task,
                    showDate: _filter != TaskFilter.today,
                    onComplete: task.id == null
                        ? null
                        : () => ref
                            .read(taskViewModelProvider.notifier)
                            .completeTask(task.id!),
                    onSnooze: task.id == null
                        ? null
                        : () => ref
                            .read(taskViewModelProvider.notifier)
                            .snoozeTask(task.id!),
                    onTestReminder: task.id == null
                        ? null
                        : () => ref
                            .read(taskViewModelProvider.notifier)
                            .triggerReminder(task),
                    onEdit: () => Navigator.push(
                      ctx,
                      MaterialPageRoute(
                          builder: (_) => TaskFormPage(taskToEdit: task)),
                    ),
                    onDelete: () => _confirmDelete(ctx, task),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  List<Task> _apply(List<Task> all) {
    final now = DateTime.now();
    final sod = DateTime(now.year, now.month, now.day);
    final eod = sod.add(const Duration(days: 1));
    if (_filter == TaskFilter.today) {
      return all
          .where((t) =>
              t.scheduledDateTime.isAfter(sod) &&
              t.scheduledDateTime.isBefore(eod))
          .toList();
    } else if (_filter == TaskFilter.pending) {
      return all.where((t) => !t.isCompleted && t.isActive).toList();
    } else if (_filter == TaskFilter.completed) {
      return all.where((t) => t.isCompleted).toList();
    } else if (_filter == TaskFilter.recurring) {
      return all.where((t) => t.isRecurring).toList();
    }
    return all;
  }

  Future<void> _confirmDelete(BuildContext ctx, Task task) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer la tâche ?'),
        content: Text(
            'Supprimer "${task.title}" ? Cette action est irréversible.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Annuler')),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok == true && task.id != null) {
      ref.read(taskViewModelProvider.notifier).deleteTask(task.id!);
    }
  }
}

class _FilterRow extends StatelessWidget {
  final TaskFilter current;
  final ValueChanged<TaskFilter> onChanged;
  const _FilterRow({required this.current, required this.onChanged});

  static const List<Map<String, Object>> _filters = [
    {
      'filter': TaskFilter.today,
      'label': "Aujourd'hui",
      'icon': Icons.today_rounded,
    },
    {
      'filter': TaskFilter.pending,
      'label': 'En attente',
      'icon': Icons.pending_actions_rounded,
    },
    {
      'filter': TaskFilter.completed,
      'label': 'Faites',
      'icon': Icons.check_circle_rounded,
    },
    {
      'filter': TaskFilter.recurring,
      'label': 'Récurrentes',
      'icon': Icons.repeat_rounded,
    },
    {
      'filter': TaskFilter.all,
      'label': 'Toutes',
      'icon': Icons.list_rounded,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final m = _filters[i];
          final f = m['filter'] as TaskFilter;
          final label = m['label'] as String;
          final icon = m['icon'] as IconData;
          return FilterChip(
            avatar: Icon(icon, size: 15),
            label: Text(label),
            selected: current == f,
            onSelected: (_) => onChanged(f),
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final TaskFilter filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    IconData icon;
    String msg;
    if (filter == TaskFilter.pending) {
      icon = Icons.inbox_rounded;
      msg = 'Aucune tâche en attente';
    } else if (filter == TaskFilter.completed) {
      icon = Icons.check_circle_outline_rounded;
      msg = 'Aucune tâche terminée';
    } else if (filter == TaskFilter.recurring) {
      icon = Icons.repeat_rounded;
      msg = 'Aucune tâche récurrente';
    } else if (filter == TaskFilter.all) {
      icon = Icons.add_task_rounded;
      msg = 'Aucune tâche créée';
    } else {
      icon = Icons.event_available_rounded;
      msg = 'Aucune tâche aujourd\'hui';
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: cs.primary),
          ),
          const SizedBox(height: 16),
          Text(msg,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
