// ============================================================
// AI VIEW MODEL — COUCHE PRESENTATION
// Gère les interactions avec l'IA : questions sur le planning,
// détection de conflits, optimisation.
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/task.dart';
import '../../services/ai_service.dart';
import '../../core/providers.dart';

/// Message dans la conversation avec l'IA
class ChatMessage {
  final String content;
  final bool isFromUser;
  final DateTime timestamp;

  const ChatMessage({
    required this.content,
    required this.isFromUser,
    required this.timestamp,
  });
}

/// État du chat IA
class AiChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? errorMessage;

  const AiChatState({
    this.messages = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  AiChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AiChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class AiChatViewModel extends Notifier<AiChatState> {
  late final AiService _aiService;

  @override
  AiChatState build() {
    _aiService = ref.watch(aiServiceProvider);
    return const AiChatState();
  }

  /// Envoie une question à l'IA avec le contexte du planning
  Future<void> sendMessage(String userMessage, List<Task> currentTasks) async {
    // Ajouter le message de l'utilisateur immédiatement
    final userMsg = ChatMessage(
      content: userMessage,
      isFromUser: true,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isLoading: true,
    );

    try {
      final response = await _aiService.askAboutPlanning(
        userQuestion: userMessage,
        tasks: currentTasks,
      );

      final aiMsg = ChatMessage(
        content: response.message,
        isFromUser: false,
        timestamp: DateTime.now(),
      );

      state = state.copyWith(
        messages: [...state.messages, aiMsg],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Erreur IA : $e',
      );
    }
  }

  /// Analyse les conflits et les ajoute au chat
  Future<void> detectConflicts(List<Task> tasks) async {
    state = state.copyWith(isLoading: true);

    try {
      final response = await _aiService.detectConflicts(tasks);

      final message = ChatMessage(
        content: response.message,
        isFromUser: false,
        timestamp: DateTime.now(),
      );

      state = state.copyWith(
        messages: [...state.messages, message],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Impossible d\'analyser les conflits : $e',
      );
    }
  }

  /// Optimise le planning et affiche les suggestions
  Future<void> optimizePlanning(List<Task> tasks) async {
    state = state.copyWith(isLoading: true);

    try {
      final response = await _aiService.optimizePlanning(tasks);

      final message = ChatMessage(
        content: response.message,
        isFromUser: false,
        timestamp: DateTime.now(),
      );

      state = state.copyWith(
        messages: [...state.messages, message],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Impossible d\'optimiser le planning : $e',
      );
    }
  }

  void clearConversation() {
    state = const AiChatState();
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

final aiChatViewModelProvider =
    NotifierProvider<AiChatViewModel, AiChatState>(() => AiChatViewModel());
