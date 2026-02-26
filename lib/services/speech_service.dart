// ============================================================
// SERVICE DE RECONNAISSANCE VOCALE — COUCHE SERVICE
// Utilise speech_to_text pour écouter les commandes vocales.
// Reconnaît "Stop" et "Reporter" pour contrôler les rappels.
// ============================================================

import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';

/// Commandes vocales reconnues par l'application
enum VoiceCommand {
  stop,       // Stoppe le rappel en cours
  snooze,     // Reporter de 10 minutes
  unknown,    // Commande non reconnue
}

/// Service encapsulant toute la logique de reconnaissance vocale.
/// S'abonne aux résultats et les mappe en [VoiceCommand] exploitables.
class SpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isListening = false;
  bool _isAvailable = false;

  // Callbacks pour les ViewModels
  void Function(VoiceCommand command)? onCommandRecognized;
  void Function(String partialResult)? onPartialResult;
  void Function(String error)? onError;

  // ─────────────────────────────────────────────────────────
  // INITIALISATION
  // ─────────────────────────────────────────────────────────

  /// Initialise le service et vérifie la disponibilité.
  /// Retourne true si la reconnaissance vocale est disponible.
  Future<bool> initialize() async {
    _isAvailable = await _speech.initialize(
      onStatus: _onSpeechStatus,
      onError: _onSpeechError,
      debugLogging: false,
    );
    return _isAvailable;
  }

  // ─────────────────────────────────────────────────────────
  // ÉCOUTE
  // ─────────────────────────────────────────────────────────

  /// Démarre l'écoute vocale.
  /// [localeId] : identifiant de langue, ex. 'fr_FR'
  Future<bool> startListening({String localeId = 'fr_FR'}) async {
    if (!_isAvailable || _isListening) return false;

    await _speech.listen(
      onResult: _onSpeechResult,
      localeId: localeId,
      listenFor: const Duration(seconds: 10), // Écoute max 10 secondes
      pauseFor: const Duration(seconds: 3),   // Pause avant arrêt auto
      partialResults: true,                   // Résultats partiels activés
      listenMode: stt.ListenMode.dictation,
    );

    _isListening = true;
    return true;
  }

  /// Arrête l'écoute vocale manuellement
  Future<void> stopListening() async {
    if (!_isListening) return;
    await _speech.stop();
    _isListening = false;
  }

  /// Annule l'écoute sans traiter le résultat
  Future<void> cancelListening() async {
    if (!_isListening) return;
    await _speech.cancel();
    _isListening = false;
  }

  // ─────────────────────────────────────────────────────────
  // TRAITEMENT DES RÉSULTATS
  // ─────────────────────────────────────────────────────────

  void _onSpeechResult(SpeechRecognitionResult result) {
    final text = result.recognizedWords.toLowerCase().trim();

    // Notifier les résultats partiels pour l'UI (indicateur visuel)
    if (!result.finalResult) {
      onPartialResult?.call(text);
      return;
    }

    // Résultat final : mapper vers une commande connue
    final command = _parseCommand(text);
    onCommandRecognized?.call(command);
    _isListening = false;
  }

  /// Mappe le texte reconnu vers une [VoiceCommand].
  /// On accepte plusieurs variantes linguistiques pour chaque commande.
  VoiceCommand _parseCommand(String text) {
    // Mots-clés pour "Stop" → arrêt immédiat
    const stopKeywords = ['stop', 'arrête', 'arreter', 'arrêter',
        'fin', 'terminer', 'terminé', 'ok', 'compris'];

    // Mots-clés pour "Reporter" → snooze 10 min
    const snoozeKeywords = ['reporter', 'répéter', 'plus tard',
        'snooze', 'dans 10 minutes', 'repousser', 'attendre'];

    if (stopKeywords.any((kw) => text.contains(kw))) {
      return VoiceCommand.stop;
    }

    if (snoozeKeywords.any((kw) => text.contains(kw))) {
      return VoiceCommand.snooze;
    }

    return VoiceCommand.unknown;
  }

  void _onSpeechStatus(String status) {
    if (status == 'done' || status == 'notListening') {
      _isListening = false;
    }
  }

  void _onSpeechError(dynamic error) {
    _isListening = false;
    onError?.call(error.errorMsg ?? 'Erreur inconnue');
  }

  // ─────────────────────────────────────────────────────────
  // ÉTATS
  // ─────────────────────────────────────────────────────────

  bool get isListening => _isListening;
  bool get isAvailable => _isAvailable;

  /// Récupère la liste des langues supportées
  Future<List<stt.LocaleName>> getLocales() async {
    if (!_isAvailable) return [];
    return await _speech.locales();
  }
}
