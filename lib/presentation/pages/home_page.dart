// ============================================================
// PAGE D'ACCUEIL — TABLEAU DE BORD
// Affiche les tâches du jour, un résumé global et l'accès
// rapide à toutes les fonctionnalités principales.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/task.dart';
import '../viewmodels/task_viewmodel.dart';
import '../viewmodels/ai_chat_viewmodel.dart';
import '../../core/providers.dart';
import 'task_form_page.dart';
import 'ai_chat_page.dart';
import 'tasks_list_page.dart';
import '../widgets/active_reminder_overlay.dart';
import '../widgets/task_card.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _currentIndex = 0;

  // Pages du BottomNavigationBar
  final _pages = const [
    _DashboardTab(),
    TasksListPage(),
    AiChatPage(),
  ];

  @override
  Widget build(BuildContext context) {
    // Surveiller si un rappel est actif pour afficher l'overlay
    final activeReminder = ref.watch(activeReminderProvider);

    return Stack(
      children: [
        Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: _pages,
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (i) =>
                setState(() => _currentIndex = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Tableau de bord',
              ),
              NavigationDestination(
                icon: Icon(Icons.task_alt_outlined),
                selectedIcon: Icon(Icons.task_alt),
                label: 'Tâches',
              ),
              NavigationDestination(
                icon: Icon(Icons.smart_toy_outlined),
                selectedIcon: Icon(Icons.smart_toy),
                label: 'Assistant IA',
              ),
            ],
          ),
          // FAB pour créer une tâche rapidement (masqué sur l'onglet IA)
          floatingActionButton: _currentIndex == 2
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TaskFormPage(),
                    ),
                  ),
                  icon: const Icon(Icons.add_alarm),
                  label: const Text('Nouvelle tâche'),
                ),
        ),

        // Overlay de rappel actif — affiché par-dessus tout le contenu
        // quand une tâche est en train de sonner
        if (activeReminder != null)
          ActiveReminderOverlay(task: activeReminder),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
// ONGLET TABLEAU DE BORD
// ─────────────────────────────────────────────────────────

class _DashboardTab extends ConsumerWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskState = ref.watch(taskViewModelProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bonjour 👋'),
            Text(
              DateFormat('EEEE d MMMM', 'fr_FR').format(DateTime.now()),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {}, // TODO: historique des notifications
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(taskViewModelProvider.notifier).loadTasks(),
        child: CustomScrollView(
          slivers: [
            // ─── Résumé statistique ───────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _StatsRow(tasks: taskState.allTasks),
              ),
            ),

            // ─── Tâches du jour ───────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    Text(
                      "Aujourd'hui",
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Chip(
                      label: Text('${taskState.todayTasks.length}'),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            ),

            if (taskState.isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (taskState.todayTasks.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_available,
                          size: 64,
                          color: theme.colorScheme.outline),
                      const SizedBox(height: 16),
                      Text(
                        'Aucune tâche aujourd\'hui',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('Profitez de votre journée libre !'),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList.builder(
                  itemCount: taskState.todayTasks.length,
                  itemBuilder: (_, i) {
                    final task = taskState.todayTasks[i];
                    return TaskCard(
                      task: task,
                      onComplete: () => ref
                          .read(taskViewModelProvider.notifier)
                          .completeTask(task.id!),
                      onSnooze: () => ref
                          .read(taskViewModelProvider.notifier)
                          .snoozeTask(task.id!),
                      onTestReminder: () => ref
                          .read(taskViewModelProvider.notifier)
                          .triggerReminder(task),
                      onEdit: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TaskFormPage(taskToEdit: task),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// WIDGET STATISTIQUES
// ─────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final List<Task> tasks;
  const _StatsRow({required this.tasks});

  @override
  Widget build(BuildContext context) {
    final total = tasks.length;
    final completed = tasks.where((t) => t.isCompleted).length;
    final recurring = tasks.where((t) => t.isRecurring).length;
    final pending = tasks.where((t) => !t.isCompleted && t.isActive).length;

    return Row(
      children: [
        _StatCard(value: '$total', label: 'Total', icon: Icons.list_alt),
        const SizedBox(width: 8),
        _StatCard(
            value: '$pending',
            label: 'En attente',
            icon: Icons.pending_actions,
            color: Colors.orange),
        const SizedBox(width: 8),
        _StatCard(
            value: '$completed',
            label: 'Terminées',
            icon: Icons.check_circle_outline,
            color: Colors.green),
        const SizedBox(width: 8),
        _StatCard(
            value: '$recurring',
            label: 'Récurrentes',
            icon: Icons.repeat,
            color: Colors.blue),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color? color;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        color ?? Theme.of(context).colorScheme.primary;

    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: effectiveColor, size: 20),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: effectiveColor,
                    ),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
