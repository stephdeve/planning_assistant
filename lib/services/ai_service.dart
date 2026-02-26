// ============================================================
// SERVICE IA — COUCHE SERVICE
// Intègre l'API OpenAI (ou Gemini) pour l'analyse intelligente
// du planning. Le service est isolé dans sa propre couche pour
// faciliter le changement de provider IA sans toucher à l'UI.
// ============================================================

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../domain/entities/task.dart';
import 'package:intl/intl.dart';

/// Réponse structurée de l'IA
class AiResponse {
  final String message;       // Réponse en langage naturel
  final List<String> suggestions; // Suggestions structurées (si applicable)
  final bool hasConflicts;    // L'IA a détecté des conflits

  const AiResponse({
    required this.message,
    this.suggestions = const [],
    this.hasConflicts = false,
  });
}

/// Service d'intelligence artificielle pour l'analyse du planning.
/// Supporte OpenAI GPT et Google Gemini selon la config .env.
class AiService {
  late final Dio _dio;
  late final String _apiKey;
  late final String _model;
  late final String _provider;

  bool _isInitialized = false;

  // ─────────────────────────────────────────────────────────
  // INITIALISATION
  // ─────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Lecture sécurisée des clés depuis .env
    _apiKey = dotenv.env['AI_API_KEY'] ?? '';
    _model = dotenv.env['AI_MODEL'] ?? 'gpt-4o-mini';
    _provider = dotenv.env['AI_PROVIDER'] ?? 'openai';
    final baseUrl = dotenv.env['AI_BASE_URL'] ?? 'https://api.openai.com/v1';

    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
    ));

    // Intercepteur de log pour le débogage (désactiver en production)
    _dio.interceptors.add(LogInterceptor(
      requestBody: false,
      responseBody: false,
    ));

    _isInitialized = true;
  }

  // ─────────────────────────────────────────────────────────
  // MÉTHODES PUBLIQUES
  // ─────────────────────────────────────────────────────────

  /// Répond à une question libre sur le planning.
  /// Exemples : "Que me reste-t-il aujourd'hui ?"
  ///            "Réorganise mes tâches de demain."
  Future<AiResponse> askAboutPlanning({
    required String userQuestion,
    required List<Task> tasks,
  }) async {
    await initialize();

    final systemPrompt = _buildSystemPrompt();
    final planningContext = _buildPlanningContext(tasks);
    final fullPrompt = '''
$planningContext

Question de l'utilisateur : $userQuestion
''';

    return _sendRequest(systemPrompt: systemPrompt, userMessage: fullPrompt);
  }

  /// Analyse les conflits dans un planning.
  /// Un conflit = deux tâches prévues à moins de 30 minutes d'intervalle.
  Future<AiResponse> detectConflicts(List<Task> tasks) async {
    await initialize();

    if (tasks.isEmpty) {
      return const AiResponse(
        message: 'Votre planning est vide. Ajoutez des tâches pour commencer !',
        hasConflicts: false,
      );
    }

    final systemPrompt = _buildSystemPrompt();
    final planningContext = _buildPlanningContext(tasks);
    final prompt = '''
$planningContext

Analyse ce planning et identifie :
1. Les conflits horaires (tâches trop proches ou simultanées)
2. Les tâches qui pourraient être regroupées pour gagner du temps
3. Les moments de surcharge (trop de tâches dans une courte période)

Réponds en français avec des suggestions concrètes et actionnables.
Commence par indiquer s'il y a des conflits (oui/non) puis explique.
''';

    final response = await _sendRequest(
        systemPrompt: systemPrompt, userMessage: prompt);

    // Détecter si la réponse mentionne des conflits
    final hasConflicts = response.message.toLowerCase().contains('conflit') ||
        response.message.toLowerCase().contains('chevauchement');

    return AiResponse(
      message: response.message,
      suggestions: response.suggestions,
      hasConflicts: hasConflicts,
    );
  }

  /// Propose une réorganisation optimale du planning
  Future<AiResponse> optimizePlanning(List<Task> tasks) async {
    await initialize();

    final systemPrompt = _buildSystemPrompt();
    final planningContext = _buildPlanningContext(tasks);
    final prompt = '''
$planningContext

Propose une réorganisation optimale de ces tâches en tenant compte :
- Des niveaux d'énergie typiques dans la journée (matin = concentration, après-midi = routine)
- Des bonnes pratiques de productivité (blocs de travail focalisé, pauses)
- De la récurrence des tâches
- Des contraintes horaires existantes

Présente ta suggestion de manière claire et ordonnée chronologiquement.
''';

    return _sendRequest(systemPrompt: systemPrompt, userMessage: prompt);
  }

  // ─────────────────────────────────────────────────────────
  // MÉTHODES PRIVÉES
  // ─────────────────────────────────────────────────────────

  /// Prompt système définissant le rôle et le comportement de l'IA
  String _buildSystemPrompt() {
    return '''Tu es un assistant personnel de productivité spécialisé dans la gestion du temps et du planning.
Tu t'exprimes toujours en français, de manière concise, bienveillante et pratique.
Tu as accès au planning de l'utilisateur et tu peux analyser ses tâches pour détecter des conflits,
proposer des optimisations et répondre à ses questions sur son organisation.
Tes réponses doivent être directes, utiles et orientées action. Maximum 200 mots par réponse.''';
  }

  /// Formate le planning sous forme de contexte lisible pour l'IA
  String _buildPlanningContext(List<Task> tasks) {
    if (tasks.isEmpty) return 'Planning : aucune tâche planifiée.';

    final formatter = DateFormat('EEEE d MMMM à HH:mm', 'fr_FR');
    final buffer = StringBuffer('Planning actuel :\n');

    // Trier par date
    final sorted = [...tasks]
      ..sort((a, b) => a.scheduledDateTime.compareTo(b.scheduledDateTime));

    for (final task in sorted) {
      final recurrence = task.recurrenceType != RecurrenceType.none
          ? ' [${_recurrenceLabel(task.recurrenceType, task.recurrenceIntervalHours)}]'
          : '';
      final status = task.isCompleted ? ' ✅' : '';

      buffer.writeln(
        '- ${formatter.format(task.scheduledDateTime)} : '
        '${task.title}$recurrence$status',
      );
    }

    return buffer.toString();
  }

  String _recurrenceLabel(RecurrenceType type, int hours) {
    switch (type) {
      case RecurrenceType.daily:
        return 'quotidien';
      case RecurrenceType.weekly:
        return 'hebdomadaire';
      case RecurrenceType.hourly:
        return 'toutes les ${hours}h';
      case RecurrenceType.none:
        return '';
    }
  }

  /// Envoie la requête à l'API et parse la réponse
  Future<AiResponse> _sendRequest({
    required String systemPrompt,
    required String userMessage,
  }) async {
    try {
      final response = await _dio.post(
        '/chat/completions',
        data: {
          'model': _model,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userMessage},
          ],
          'temperature': 0.7,
          'max_tokens': 500,
        },
      );

      final content = response.data['choices'][0]['message']['content']
          as String? ?? '';

      return AiResponse(message: content.trim());

    } on DioException catch (e) {
      // Gestion des erreurs réseau et API
      final errorMessage = _handleDioError(e);
      return AiResponse(message: errorMessage);
    } catch (e) {
      return AiResponse(
        message: 'Une erreur inattendue s\'est produite. Veuillez réessayer.',
      );
    }
  }

  String _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
        return 'La connexion a expiré. Vérifiez votre connexion internet.';
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        if (statusCode == 401) {
          return 'Clé API invalide. Vérifiez votre fichier .env.';
        } else if (statusCode == 429) {
          return 'Quota API dépassé. Attendez quelques instants.';
        }
        return 'Erreur API ($statusCode). Réessayez plus tard.';
      case DioExceptionType.connectionError:
        return 'Impossible de contacter l\'IA. Vérifiez votre connexion.';
      default:
        return 'Erreur réseau. Réessayez dans quelques instants.';
    }
  }
}
