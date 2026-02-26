// ============================================================
// TASK VIEW MODEL — COUCHE PRESENTATION
// Le ViewModel fait le pont entre l'UI et les use cases.
// Il gère l'état de l'UI (loading, error, data) et orchestre
// les appels aux use cases, à la notification et à l'audio.
// Utilise AsyncNotifier de Riverpod pour la gestion d'état.
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/task.dart';
import '../../domain/usecases/task_usecases.dart';
import '../../services/notification_service.dart';
import '../../services/audio_service.dart';
import '../../services/speech_service.dart';
import '../../core/providers.dart';

// ─────────────────────────────────────────────────────────
// ÉTATS POSSIBLES DU VIEW MODEL DE TÂCHES
// ─────────────────────────────────────────────────────────

/// Encapsule tous les états possibles de la liste de tâches
class TasksState {
  final List<Task> todayTasks;
  final List<Task> allTasks;
  final bool isLoading;
  final String? errorMessage;

  const TasksState({
    this.todayTasks = const [],
    this.allTasks = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  TasksState copyWith({
    List<Task>? todayTasks,
    List<Task>? allTasks,
    bool? isLoading,
    String? errorMessage,
  }) {
    return TasksState(
      todayTasks: todayTasks ?? this.todayTasks,
      allTasks: allTasks ?? this.allTasks,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

// ─────────────────────────────────────────────────────────
// VIEW MODEL PRINCIPAL
// ─────────────────────────────────────────────────────────

class TaskViewModel extends Notifier<TasksState> {
  late final CreateTaskUseCase _createTask;
  late final UpdateTaskUseCase _updateTask;
  late final DeleteTaskUseCase _deleteTask;
  late final CompleteTaskUseCase _completeTask;
  late final SnoozeTaskUseCase _snoozeTask;
  late final GetAllTasksUseCase _getAllTasks;
  late final GetTodayTasksUseCase _getTodayTasks;
  late final NotificationService _notificationService;
  late final AudioService _audioService;
  late final SpeechService _speechService;

  @override
  TasksState build() {
    // Injection des dépendances via Riverpod
    _createTask = ref.watch(createTaskUseCaseProvider);
    _updateTask = ref.watch(updateTaskUseCaseProvider);
    _deleteTask = ref.watch(deleteTaskUseCaseProvider);
    _completeTask = ref.watch(completeTaskUseCaseProvider);
    _snoozeTask = ref.watch(snoozeTaskUseCaseProvider);
    _getAllTasks = ref.watch(getAllTasksUseCaseProvider);
    _getTodayTasks = ref.watch(getTodayTasksUseCaseProvider);
    _notificationService = ref.watch(notificationServiceProvider);
    _audioService = ref.watch(audioServiceProvider);
    _speechService = ref.watch(speechServiceProvider);

    // Configurer les callbacks de notifications
    _setupNotificationCallbacks();
    // Configurer les callbacks de reconnaissance vocale
    _setupSpeechCallbacks();

    // Charger les tâches au démarrage
    loadTasks();

    return const TasksState();
  }

  // ─────────────────────────────────────────────────────────
  // CHARGEMENT DES DONNÉES
  // ─────────────────────────────────────────────────────────

  Future<void> loadTasks() async {
    state = state.copyWith(isLoading: true);
    try {
      final allTasks = await _getAllTasks();
      final todayTasks = await _getTodayTasks();
      state = state.copyWith(
        allTasks: allTasks,
        todayTasks: todayTasks,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Erreur de chargement : $e',
      );
    }
  }

  // ─────────────────────────────────────────────────────────
  // OPÉRATIONS CRUD
  // ─────────────────────────────────────────────────────────

  /// Crée une nouvelle tâche et planifie sa notification
  Future<void> createTask(Task task) async {
    state = state.copyWith(isLoading: true);
    try {
      final createdTask = await _createTask(task);

      // Planifier la notification ET les répétitions (rappels 30s)
      await _notificationService.scheduleTaskNotification(createdTask);
      await _notificationService.scheduleRepeatingReminder(createdTask);

      await loadTasks();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Impossible de créer la tâche : $e',
      );
    }
  }

  /// Met à jour une tâche existante et reprogramme ses notifications
  Future<void> updateTask(Task task) async {
    state = state.copyWith(isLoading: true);
    try {
      final updatedTask = await _updateTask(task);

      // Annuler les anciennes notifications et en créer de nouvelles
      if (task.id != null) {
        await _notificationService.cancelTaskNotifications(task.id!);
        await _notificationService.scheduleTaskNotification(updatedTask);
        await _notificationService.scheduleRepeatingReminder(updatedTask);
      }

      await loadTasks();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Impossible de modifier la tâche : $e',
      );
    }
  }

  /// Supprime une tâche et annule ses notifications
  Future<void> deleteTask(int taskId) async {
    try {
      await _notificationService.cancelTaskNotifications(taskId);
      await _deleteTask(taskId);
      await loadTasks();
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Impossible de supprimer la tâche : $e',
      );
    }
  }

  /// Marque une tâche comme terminée, arrête l'audio si en cours
  Future<void> completeTask(int taskId) async {
    try {
      await _completeTask(taskId);
      await _notificationService.cancelTaskNotifications(taskId);
      await _audioService.stopAll();

      // Effacer le rappel actif si c'était cette tâche
      final activeReminder = ref.read(activeReminderProvider);
      if (activeReminder?.id == taskId) {
        ref.read(activeReminderProvider.notifier).state = null;
      }

      await loadTasks();
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Impossible de terminer la tâche : $e',
      );
    }
  }

  /// Reporte une tâche de 10 minutes (snooze)
  Future<void> snoozeTask(int taskId) async {
    try {
      final snoozedTask = await _snoozeTask(taskId);

      // Arrêter l'audio immédiatement
      await _audioService.stopAll();

      // Reprogrammer pour dans 10 min
      await _notificationService.cancelTaskNotifications(taskId);
      await _notificationService.scheduleTaskNotification(snoozedTask);

      // Effacer le rappel actif
      ref.read(activeReminderProvider.notifier).state = null;

      await loadTasks();
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Impossible de reporter la tâche : $e',
      );
    }
  }

  // ─────────────────────────────────────────────────────────
  // GESTION DES RAPPELS AUDIO + VOCAL
  // ─────────────────────────────────────────────────────────

  /// Démarre la séquence complète de rappel pour une tâche
  Future<void> triggerReminder(Task task) async {
    // Enregistrer la tâche active pour l'affichage UI
    ref.read(activeReminderProvider.notifier).state = task;

    // Jouer l'alarme + TTS — attendre la fin complète
    await _audioService.playFullReminder(
      taskTitle: task.title,
      taskDescription: task.description,
    );

    // Attendre que l'audio soit libéré (Android audio focus)
    // avant de démarrer le micro
    await Future.delayed(const Duration(milliseconds: 800));
    _startVoiceListening();
  }

  void _startVoiceListening() {
    ref.read(isListeningProvider.notifier).state = true;
    _speechService.startListening();
  }

  // ─────────────────────────────────────────────────────────
  // CONFIGURATION DES CALLBACKS
  // ─────────────────────────────────────────────────────────

  void _setupNotificationCallbacks() {
    _notificationService.onNotificationAction = (taskId, action) {
      // Appelé quand l'utilisateur tape sur un bouton de notification
      if (action == NotificationActions.complete) {
        completeTask(taskId);
      } else if (action == NotificationActions.snooze) {
        snoozeTask(taskId);
      }
    };
  }

  void _setupSpeechCallbacks() {
    _speechService.onCommandRecognized = (command) {
      ref.read(isListeningProvider.notifier).state = false;
      ref.read(partialSpeechResultProvider.notifier).state = '';

      final activeTask = ref.read(activeReminderProvider);
      if (activeTask?.id == null) return;

      if (command == VoiceCommand.stop) {
        completeTask(activeTask!.id!);
      } else if (command == VoiceCommand.snooze) {
        snoozeTask(activeTask!.id!);
      } else {
        // Commande non reconnue — relancer l'écoute
        _startVoiceListening();
      }
    };

    _speechService.onPartialResult = (text) {
      ref.read(partialSpeechResultProvider.notifier).state = text;
    };

    _speechService.onError = (error) {
      ref.read(isListeningProvider.notifier).state = false;
    };
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

/// Provider du TaskViewModel
final taskViewModelProvider =
    NotifierProvider<TaskViewModel, TasksState>(() => TaskViewModel());
