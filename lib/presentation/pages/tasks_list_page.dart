// ============================================================
// PAGE LISTE DES TÂCHES — VUE COMPLÈTE
// Affiche toutes les tâches avec filtres, tri et actions.
// Utilise un SliverAppBar pour un effet de défilement fluide.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/task.dart';
import '../viewmodels/task_viewmodel.dart';
import 'task_form_page.dart';
import '../widgets/task_card.dart';

/// Filtres disponibles pour la liste des tâches
enum TaskFilter { all, today, pending, completed, recurring }

class TasksListPage extends ConsumerStatefulWidget {
  const TasksListPage({super.key});

  @override
  ConsumerState<TasksListPage> createState() => _TasksListPageState();
}

class _TasksListPageState extends ConsumerState<TasksListPage> {
  TaskFilter _currentFilter = TaskFilter.today;

  @override
  Widget build(BuildContext context) {
    final taskState = ref.watch(taskViewModelProvider);
    final filteredTasks = _applyFilter(taskState.allTasks);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // AppBar qui se réduit au défilement
          SliverAppBar(
            title: const Text('Mes tâches'),
            floating: true,
            snap: true,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: _FilterBar(
                currentFilter: _currentFilter,
                onFilterChanged: (f) =>
                    setState(() => _currentFilter = f),
              ),
            ),
          ),

          if (taskState.isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (filteredTasks.isEmpty)
            SliverFillRemaining(
              child: _EmptyState(filter: _currentFilter),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList.separated(
                itemCount: filteredTasks.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final task = filteredTasks[i];
                  return TaskCard(
                    task: task,
                    showDate: _currentFilter != TaskFilter.today,
                    onComplete: () => ref
                        .read(taskViewModelProvider.notifier)
                        .completeTask(task.id!),
                    onSnooze: () => ref
                        .read(taskViewModelProvider.notifier)
                        .snoozeTask(task.id!),
                    onEdit: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TaskFormPage(taskToEdit: task),
                      ),
                    ),
                    onDelete: () => _confirmDelete(context, task),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  List<Task> _applyFilter(List<Task> tasks) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    switch (_currentFilter) {
      case TaskFilter.all:
        return tasks;
      case TaskFilter.today:
        return tasks.where((t) =>
            t.scheduledDateTime.isAfter(startOfDay) &&
            t.scheduledDateTime.isBefore(endOfDay)).toList();
      case TaskFilter.pending:
        return tasks.where((t) => !t.isCompleted && t.isActive).toList();
      case TaskFilter.completed:
        return tasks.where((t) => t.isCompleted).toList();
      case TaskFilter.recurring:
        return tasks.where((t) => t.isRecurring).toList();
    }
  }

  Future<void> _confirmDelete(BuildContext context, Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la tâche ?'),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer "${task.title}" ? '
          'Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true && task.id != null) {
      ref.read(taskViewModelProvider.notifier).deleteTask(task.id!);
    }
  }
}

// ─────────────────────────────────────────────────────────
// BARRE DE FILTRES
// ─────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final TaskFilter currentFilter;
  final ValueChanged<TaskFilter> onFilterChanged;

  const _FilterBar({
    required this.currentFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _FilterChip(
            label: "Aujourd'hui",
            icon: Icons.today,
            isSelected: currentFilter == TaskFilter.today,
            onTap: () => onFilterChanged(TaskFilter.today),
          ),
          _FilterChip(
            label: 'En attente',
            icon: Icons.pending_actions,
            isSelected: currentFilter == TaskFilter.pending,
            onTap: () => onFilterChanged(TaskFilter.pending),
          ),
          _FilterChip(
            label: 'Terminées',
            icon: Icons.check_circle_outline,
            isSelected: currentFilter == TaskFilter.completed,
            onTap: () => onFilterChanged(TaskFilter.completed),
          ),
          _FilterChip(
            label: 'Récurrentes',
            icon: Icons.repeat,
            isSelected: currentFilter == TaskFilter.recurring,
            onTap: () => onFilterChanged(TaskFilter.recurring),
          ),
          _FilterChip(
            label: 'Toutes',
            icon: Icons.list,
            isSelected: currentFilter == TaskFilter.all,
            onTap: () => onFilterChanged(TaskFilter.all),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        avatar: Icon(icon, size: 16),
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// ÉTAT VIDE
// ─────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final TaskFilter filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    String message;
    IconData icon;

    switch (filter) {
      case TaskFilter.today:
        message = 'Aucune tâche aujourd\'hui';
        icon = Icons.event_available;
        break;
      case TaskFilter.pending:
        message = 'Aucune tâche en attente';
        icon = Icons.inbox;
        break;
      case TaskFilter.completed:
        message = 'Aucune tâche terminée';
        icon = Icons.check_circle_outline;
        break;
      case TaskFilter.recurring:
        message = 'Aucune tâche récurrente';
        icon = Icons.repeat;
        break;
      case TaskFilter.all:
        message = 'Aucune tâche créée';
        icon = Icons.add_task;
        break;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 72, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }
}
