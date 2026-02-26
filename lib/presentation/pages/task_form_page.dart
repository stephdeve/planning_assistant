import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/task.dart';
import '../viewmodels/task_viewmodel.dart';

class TaskFormPage extends ConsumerStatefulWidget {
  final Task? taskToEdit;
  const TaskFormPage({super.key, this.taskToEdit});
  @override
  ConsumerState<TaskFormPage> createState() => _TaskFormPageState();
}

class _TaskFormPageState extends ConsumerState<TaskFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late DateTime _dt;
  late RecurrenceType _recurrence;
  late int _intervalHours;
  bool _saving = false;

  bool get _isEditing => widget.taskToEdit != null;

  @override
  void initState() {
    super.initState();
    final t = widget.taskToEdit;
    _titleCtrl = TextEditingController(text: t?.title ?? '');
    _descCtrl = TextEditingController(text: t?.description ?? '');
    _dt = t?.scheduledDateTime ?? DateTime.now().add(const Duration(hours: 1));
    _recurrence = t?.recurrenceType ?? RecurrenceType.none;
    _intervalHours = t?.recurrenceIntervalHours ?? 1;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        title: Text(
          _isEditing ? 'Modifier la tâche' : 'Nouvelle tâche',
          style: theme.textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        actions: [
          _saving
              ? const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: Center(
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))),
                )
              : TextButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Enregistrer',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            // ─── Section : Infos principales ──────────────────
            _SectionLabel(
                icon: Icons.info_outline_rounded, label: 'Informations'),
            const SizedBox(height: 12),

            // Titre
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Titre *',
                hintText: 'Ex: Réunion d\'équipe',
                prefixIcon: Icon(Icons.title_rounded),
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Titre obligatoire';
                if (v.trim().length < 3)
                  return 'Au moins 3 caractères';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Description
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description *',
                hintText: 'Ce texte sera lu à voix haute lors du rappel',
                prefixIcon: Icon(Icons.description_rounded),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) {
                if (v == null || v.trim().isEmpty)
                  return 'Description obligatoire';
                return null;
              },
            ),
            const SizedBox(height: 28),

            // ─── Section : Planification ───────────────────────
            _SectionLabel(
                icon: Icons.schedule_rounded, label: 'Planification'),
            const SizedBox(height: 12),
            _DateTimeTile(
              dt: _dt,
              onChanged: (d) => setState(() => _dt = d),
            ),
            const SizedBox(height: 28),

            // ─── Section : Récurrence ──────────────────────────
            _SectionLabel(icon: Icons.repeat_rounded, label: 'Récurrence'),
            const SizedBox(height: 12),
            _RecurrenceSection(
              selected: _recurrence,
              intervalHours: _intervalHours,
              onTypeChanged: (r) => setState(() => _recurrence = r),
              onInterval: (h) => setState(() => _intervalHours = h),
            ),
            const SizedBox(height: 36),

            // ─── Submit button ──────────────────────────────────
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: Icon(
                    _isEditing ? Icons.save_rounded : Icons.add_alarm_rounded),
                label: Text(
                  _isEditing
                      ? 'Enregistrer les modifications'
                      : 'Créer la tâche',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final task = Task(
      id: widget.taskToEdit?.id,
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      scheduledDateTime: _dt,
      recurrenceType: _recurrence,
      recurrenceIntervalHours: _intervalHours,
      createdAt: widget.taskToEdit?.createdAt ?? DateTime.now(),
    );

    final vm = ref.read(taskViewModelProvider.notifier);
    if (_isEditing) {
      await vm.updateTask(task);
    } else {
      await vm.createTask(task);
    }

    setState(() => _saving = false);
    if (mounted) Navigator.of(context).pop();
  }
}

// ─────────────────────────────────────────────────────────
// SOUS-COMPOSANTS
// ─────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: cs.primary,
              ),
        ),
        const SizedBox(width: 10),
        Expanded(
            child: Divider(color: cs.outlineVariant.withValues(alpha: 0.5))),
      ],
    );
  }
}

class _DateTimeTile extends StatelessWidget {
  final DateTime dt;
  final ValueChanged<DateTime> onChanged;
  const _DateTimeTile({required this.dt, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateFmt = DateFormat('EEEE d MMMM yyyy', 'fr_FR');
    final timeFmt = DateFormat('HH:mm');

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          ListTile(
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            leading: Icon(Icons.calendar_today_rounded, color: cs.primary),
            title: Text(dateFmt.format(dt),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Date du rappel'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: dt,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                locale: const Locale('fr', 'FR'),
              );
              if (picked != null) {
                onChanged(DateTime(
                    picked.year, picked.month, picked.day, dt.hour, dt.minute));
              }
            },
          ),
          Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.3)),
          ListTile(
            shape: const RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            leading: Icon(Icons.access_time_rounded, color: cs.primary),
            title: Text(timeFmt.format(dt),
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 20)),
            subtitle: const Text('Heure exacte'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(dt),
                builder: (ctx, child) => MediaQuery(
                  data: MediaQuery.of(ctx)
                      .copyWith(alwaysUse24HourFormat: true),
                  child: child!,
                ),
              );
              if (picked != null) {
                onChanged(DateTime(dt.year, dt.month, dt.day, picked.hour,
                    picked.minute));
              }
            },
          ),
        ],
      ),
    );
  }
}

class _RecurrenceSection extends StatelessWidget {
  final RecurrenceType selected;
  final int intervalHours;
  final ValueChanged<RecurrenceType> onTypeChanged;
  final ValueChanged<int> onInterval;
  const _RecurrenceSection({
    required this.selected,
    required this.intervalHours,
    required this.onTypeChanged,
    required this.onInterval,
  });

  static const Map<RecurrenceType, Map<String, Object>> _labels = {
    RecurrenceType.none: {
      'label': 'Unique',
      'icon': Icons.looks_one_rounded,
    },
    RecurrenceType.daily: {
      'label': 'Quotidien',
      'icon': Icons.calendar_today_rounded,
    },
    RecurrenceType.weekly: {
      'label': 'Hebdo',
      'icon': Icons.date_range_rounded,
    },
    RecurrenceType.hourly: {
      'label': 'Toutes les Xh',
      'icon': Icons.timer_rounded,
    },
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: RecurrenceType.values.map((r) {
            final data = _labels[r]!;
            final label = data['label'] as String;
            final icon = data['icon'] as IconData;
            final isSelected = selected == r;
            return ChoiceChip(
              avatar: Icon(icon,
                  size: 16,
                  color: isSelected ? cs.onPrimaryContainer : null),
              label: Text(label),
              selected: isSelected,
              onSelected: (_) => onTypeChanged(r),
            );
          }).toList(growable: false),
        ),
        if (selected == RecurrenceType.hourly) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.timer_rounded, size: 16, color: cs.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Toutes les $intervalHours heure${intervalHours > 1 ? 's' : ''}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                Slider(
                  value: intervalHours.toDouble(),
                  min: 1,
                  max: 24,
                  divisions: 23,
                  label: '${intervalHours}h',
                  onChanged: (v) => onInterval(v.round()),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
