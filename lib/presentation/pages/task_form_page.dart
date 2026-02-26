// ============================================================
// FORMULAIRE DE TÂCHE — WIDGET RÉUTILISABLE
// Ce widget gère aussi bien la création que la modification
// d'une tâche. Il adapte son titre et son comportement selon
// qu'une tâche initiale est fournie ou non.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/task.dart';
import '../viewmodels/task_viewmodel.dart';

class TaskFormPage extends ConsumerStatefulWidget {
  /// Tâche à modifier (null = création d'une nouvelle tâche)
  final Task? taskToEdit;

  const TaskFormPage({super.key, this.taskToEdit});

  @override
  ConsumerState<TaskFormPage> createState() => _TaskFormPageState();
}

class _TaskFormPageState extends ConsumerState<TaskFormPage> {
  // Clé pour valider le formulaire avant soumission
  final _formKey = GlobalKey<FormState>();

  // Contrôleurs de texte
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  // État du formulaire
  late DateTime _selectedDateTime;
  late RecurrenceType _recurrenceType;
  late int _recurrenceIntervalHours;

  bool get _isEditing => widget.taskToEdit != null;

  @override
  void initState() {
    super.initState();

    // Pré-remplir si on est en mode édition, sinon valeurs par défaut
    final task = widget.taskToEdit;
    _titleController = TextEditingController(text: task?.title ?? '');
    _descriptionController =
        TextEditingController(text: task?.description ?? '');
    _selectedDateTime = task?.scheduledDateTime ??
        DateTime.now().add(const Duration(hours: 1));
    _recurrenceType = task?.recurrenceType ?? RecurrenceType.none;
    _recurrenceIntervalHours = task?.recurrenceIntervalHours ?? 1;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifier la tâche' : 'Nouvelle tâche'),
        actions: [
          // Bouton de sauvegarde dans l'AppBar
          TextButton.icon(
            onPressed: _submitForm,
            icon: const Icon(Icons.check),
            label: const Text('Enregistrer'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ─── Section : Informations principales ───────────────
            _SectionHeader(title: 'Informations', icon: Icons.info_outline),
            const SizedBox(height: 12),

            // Titre
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Titre *',
                hintText: 'Ex: Réunion d\'équipe',
                prefixIcon: Icon(Icons.title),
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Le titre est obligatoire';
                }
                if (value.trim().length < 3) {
                  return 'Le titre doit contenir au moins 3 caractères';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Description (lu à voix haute lors du rappel)
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description *',
                hintText: 'Ce texte sera lu à voix haute lors du rappel',
                prefixIcon: Icon(Icons.description),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'La description est obligatoire';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // ─── Section : Planification ───────────────────────────
            _SectionHeader(title: 'Planification', icon: Icons.schedule),
            const SizedBox(height: 12),

            // Sélecteur de date et heure
            _DateTimePicker(
              selectedDateTime: _selectedDateTime,
              onChanged: (dt) => setState(() => _selectedDateTime = dt),
            ),
            const SizedBox(height: 24),

            // ─── Section : Récurrence ──────────────────────────────
            _SectionHeader(title: 'Récurrence', icon: Icons.repeat),
            const SizedBox(height: 12),

            _RecurrencePicker(
              selectedType: _recurrenceType,
              intervalHours: _recurrenceIntervalHours,
              onTypeChanged: (type) =>
                  setState(() => _recurrenceType = type),
              onIntervalChanged: (h) =>
                  setState(() => _recurrenceIntervalHours = h),
            ),
            const SizedBox(height: 32),

            // ─── Bouton principal ──────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _submitForm,
                icon: Icon(_isEditing ? Icons.save : Icons.add_alarm),
                label: Text(
                  _isEditing ? 'Enregistrer les modifications' : 'Créer la tâche',
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final viewModel = ref.read(taskViewModelProvider.notifier);

    final task = Task(
      id: widget.taskToEdit?.id,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      scheduledDateTime: _selectedDateTime,
      recurrenceType: _recurrenceType,
      recurrenceIntervalHours: _recurrenceIntervalHours,
      createdAt: widget.taskToEdit?.createdAt ?? DateTime.now(),
    );

    if (_isEditing) {
      await viewModel.updateTask(task);
    } else {
      await viewModel.createTask(task);
    }

    if (mounted) Navigator.of(context).pop();
  }
}

// ─────────────────────────────────────────────────────────
// WIDGETS INTERNES
// ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        const SizedBox(width: 8),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class _DateTimePicker extends StatelessWidget {
  final DateTime selectedDateTime;
  final ValueChanged<DateTime> onChanged;

  const _DateTimePicker({
    required this.selectedDateTime,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('EEEE d MMMM yyyy', 'fr_FR');
    final timeFormatter = DateFormat('HH:mm');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sélecteur de date
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text(dateFormatter.format(selectedDateTime)),
              subtitle: const Text('Date du rappel'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _pickDate(context),
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(height: 1),
            // Sélecteur d'heure
            ListTile(
              leading: const Icon(Icons.access_time),
              title: Text(timeFormatter.format(selectedDateTime)),
              subtitle: const Text('Heure exacte'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _pickTime(context),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('fr', 'FR'),
    );
    if (picked != null) {
      onChanged(DateTime(
        picked.year,
        picked.month,
        picked.day,
        selectedDateTime.hour,
        selectedDateTime.minute,
      ));
    }
  }

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(selectedDateTime),
      builder: (context, child) =>
          MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (picked != null) {
      onChanged(DateTime(
        selectedDateTime.year,
        selectedDateTime.month,
        selectedDateTime.day,
        picked.hour,
        picked.minute,
      ));
    }
  }
}

class _RecurrencePicker extends StatelessWidget {
  final RecurrenceType selectedType;
  final int intervalHours;
  final ValueChanged<RecurrenceType> onTypeChanged;
  final ValueChanged<int> onIntervalChanged;

  const _RecurrencePicker({
    required this.selectedType,
    required this.intervalHours,
    required this.onTypeChanged,
    required this.onIntervalChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Choix du type de récurrence avec des chips cliquables
            Wrap(
              spacing: 8,
              children: RecurrenceType.values.map((type) {
                final isSelected = selectedType == type;
                return ChoiceChip(
                  label: Text(_recurrenceLabel(type)),
                  selected: isSelected,
                  onSelected: (_) => onTypeChanged(type),
                );
              }).toList(),
            ),

            // Slider pour l'intervalle en heures (seulement si hourly)
            if (selectedType == RecurrenceType.hourly) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.timer_outlined),
                  const SizedBox(width: 8),
                  Text('Toutes les $intervalHours heure(s)'),
                ],
              ),
              Slider(
                value: intervalHours.toDouble(),
                min: 1,
                max: 24,
                divisions: 23,
                label: '${intervalHours}h',
                onChanged: (v) => onIntervalChanged(v.round()),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _recurrenceLabel(RecurrenceType type) {
    switch (type) {
      case RecurrenceType.none:
        return 'Unique';
      case RecurrenceType.daily:
        return 'Quotidien';
      case RecurrenceType.weekly:
        return 'Hebdomadaire';
      case RecurrenceType.hourly:
        return 'Toutes les X heures';
    }
  }
}
