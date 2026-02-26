import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/task.dart';
import '../viewmodels/task_viewmodel.dart';
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

  @override
  Widget build(BuildContext context) {
    final activeReminder = ref.watch(activeReminderProvider);
    final pages = [
      const _DashboardTab(),
      const TasksListPage(),
      const AiChatPage(),
    ];

    return Stack(
      children: [
        Scaffold(
          extendBody: true,
          body: IndexedStack(index: _currentIndex, children: pages),
          bottomNavigationBar: _BottomBar(
            currentIndex: _currentIndex,
            onTap: (i) => setState(() => _currentIndex = i),
          ),
          floatingActionButton: _currentIndex == 2
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TaskFormPage()),
                  ),
                  icon: const Icon(Icons.add_alarm_rounded),
                  label: const Text('Nouvelle tâche',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.endFloat,
        ),
        if (activeReminder != null)
          ActiveReminderOverlay(task: activeReminder),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _BottomBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard_rounded),
          label: 'Tableau de bord',
        ),
        NavigationDestination(
          icon: Icon(Icons.task_alt_outlined),
          selectedIcon: Icon(Icons.task_alt_rounded),
          label: 'Tâches',
        ),
        NavigationDestination(
          icon: Icon(Icons.smart_toy_outlined),
          selectedIcon: Icon(Icons.smart_toy_rounded),
          label: 'Assistant IA',
        ),
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
    final cs = theme.colorScheme;
    final now = DateTime.now();
    final greeting = _greeting(now.hour);

    return CustomScrollView(
      slivers: [
        // ─── Gradient Header ────────────────────────────────
        SliverToBoxAdapter(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  cs.primary,
                  cs.primary.withValues(alpha: 0.75),
                ],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                greeting,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('EEEE d MMMM', 'fr_FR').format(now),
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.white24,
                          child: Text(
                            greeting.substring(0, 1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Stat chips
                    _StatChipsRow(tasks: taskState.allTasks),
                  ],
                ),
              ),
            ),
          ),
        ),

        // ─── Section "Aujourd'hui" ───────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Text(
                  "Aujourd'hui",
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${taskState.todayTasks.length}',
                    style: TextStyle(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ─── Task list ──────────────────────────────────────
        if (taskState.isLoading)
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          )
        else if (taskState.todayTasks.isEmpty)
          SliverFillRemaining(
            child: _EmptyDashboard(cs: cs),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
            sliver: SliverList.separated(
              itemCount: taskState.todayTasks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
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
                    ctx,
                    MaterialPageRoute(
                        builder: (_) => TaskFormPage(taskToEdit: task)),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  String _greeting(int hour) {
    if (hour < 6) return 'Bonne nuit 🌙';
    if (hour < 12) return 'Bonjour ☀️';
    if (hour < 18) return 'Bon après-midi 🌤️';
    return 'Bonsoir 🌆';
  }
}

class _StatChipsRow extends StatelessWidget {
  final List<Task> tasks;
  const _StatChipsRow({required this.tasks});

  @override
  Widget build(BuildContext context) {
    final total = tasks.length;
    final done = tasks.where((t) => t.isCompleted).length;
    final pending = tasks.where((t) => !t.isCompleted && t.isActive).length;

    return Row(
      children: [
        _Chip(label: '$total tâches', icon: Icons.list_alt_rounded),
        const SizedBox(width: 8),
        _Chip(label: '$pending en attente', icon: Icons.pending_actions_rounded, color: Colors.orangeAccent),
        const SizedBox(width: 8),
        _Chip(label: '$done faites', icon: Icons.check_circle_rounded, color: Colors.greenAccent),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? color;
  const _Chip({required this.label, required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: c),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: c, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _EmptyDashboard extends StatelessWidget {
  final ColorScheme cs;
  const _EmptyDashboard({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.event_available_rounded,
                size: 44, color: cs.primary),
          ),
          const SizedBox(height: 20),
          Text(
            'Journée libre !',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Aucune tâche planifiée aujourd\'hui.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: cs.outline),
          ),
        ],
      ),
    );
  }
}
