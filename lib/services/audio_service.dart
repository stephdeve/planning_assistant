// ============================================================
// SERVICE AUDIO & TTS — COUCHE SERVICE
// Gère la lecture vocale (Text-to-Speech) et la lecture
// d'alarmes sonores via audioplayers.
// Le service maintient son état (lecture en cours / arrêtée)
// et expose des méthodes simples pour les ViewModels.
// ============================================================

import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';

/// Résultat possible d'une opération TTS
enum TtsState { playing, stopped, paused, error }

/// Orchestre la lecture de l'alarme sonore ET de la synthèse
/// vocale pour les rappels de tâches.
class AudioService {
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();

  TtsState _ttsState = TtsState.stopped;
  bool _isAlarmPlaying = false;

  // Callback pour notifier les ViewModels des changements d'état
  void Function(TtsState)? onTtsStateChanged;

  // ─────────────────────────────────────────────────────────
  // INITIALISATION
  // ─────────────────────────────────────────────────────────

  Future<void> initialize() async {
    await _configureTts();
    _configureAudioPlayer();
  }

  Future<void> _configureTts() async {
    // Langue française
    await _tts.setLanguage('fr-FR');

    // Vitesse de lecture : 0.0 (lent) → 1.0 (rapide)
    // 0.5 = vitesse normale, confortable à l'écoute
    await _tts.setSpeechRate(0.5);

    // Volume : 0.0 → 1.0
    await _tts.setVolume(1.0);

    // Hauteur de voix : 0.5 (grave) → 2.0 (aigu)
    await _tts.setPitch(1.0);

    // Callbacks d'état TTS
    _tts.setStartHandler(() {
      _ttsState = TtsState.playing;
      onTtsStateChanged?.call(TtsState.playing);
    });

    _tts.setCompletionHandler(() {
      _ttsState = TtsState.stopped;
      onTtsStateChanged?.call(TtsState.stopped);
    });

    _tts.setErrorHandler((message) {
      _ttsState = TtsState.error;
      onTtsStateChanged?.call(TtsState.error);
    });

    _tts.setCancelHandler(() {
      _ttsState = TtsState.stopped;
      onTtsStateChanged?.call(TtsState.stopped);
    });
  }

  void _configureAudioPlayer() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      _isAlarmPlaying = state == PlayerState.playing;
    });
  }

  // ─────────────────────────────────────────────────────────
  // LECTURE D'ALARME
  // ─────────────────────────────────────────────────────────

  /// Joue l'alarme sonore depuis les assets.
  /// Le fichier alarm.mp3 doit être placé dans assets/sounds/.
  Future<void> playAlarm() async {
    if (_isAlarmPlaying) return;

    try {
      await _audioPlayer.play(
        AssetSource('sounds/alarm.mp3'),
        volume: 1.0,
      );
      _isAlarmPlaying = true;
    } catch (e) {
      // Fallback : utiliser un son système si l'asset est absent
      // En production, l'asset devrait toujours être présent
      print('Erreur lecture alarme : $e');
    }
  }

  /// Arrête l'alarme sonore
  Future<void> stopAlarm() async {
    if (!_isAlarmPlaying) return;
    await _audioPlayer.stop();
    _isAlarmPlaying = false;
  }

  // ─────────────────────────────────────────────────────────
  // TEXT-TO-SPEECH
  // ─────────────────────────────────────────────────────────

  /// Lit le texte de la tâche à voix haute.
  /// Format : "Rappel : [titre]. [description]"
  Future<void> speakTask({
    required String title,
    required String description,
  }) async {
    final text = 'Rappel : $title. $description';
    await speak(text);
  }

  /// Lit n'importe quel texte à voix haute
  Future<void> speak(String text) async {
    if (_ttsState == TtsState.playing) {
      await _tts.stop();
    }
    await _tts.speak(text);
  }

  /// Arrête la synthèse vocale en cours
  Future<void> stopSpeaking() async {
    await _tts.stop();
    _ttsState = TtsState.stopped;
  }

  // ─────────────────────────────────────────────────────────
  // SÉQUENCE COMPLÈTE DE RAPPEL
  // ─────────────────────────────────────────────────────────

  /// Lance l'alarme + lecture vocale en séquence.
  /// L'alarme joue en premier pour attirer l'attention,
  /// puis la TTS lit le contenu de la tâche.
  Future<void> playFullReminder({
    required String taskTitle,
    required String taskDescription,
  }) async {
    // 1. Jouer l'alarme sonore
    await playAlarm();

    // 2. Attendre 2 secondes puis lire vocalement
    await Future.delayed(const Duration(seconds: 2));
    await speakTask(title: taskTitle, description: taskDescription);
  }

  /// Arrête tout (alarme + TTS)
  Future<void> stopAll() async {
    await stopAlarm();
    await stopSpeaking();
  }

  // ─────────────────────────────────────────────────────────
  // ÉTATS
  // ─────────────────────────────────────────────────────────

  bool get isPlaying =>
      _isAlarmPlaying || _ttsState == TtsState.playing;

  TtsState get ttsState => _ttsState;

  /// Récupère les langues disponibles sur l'appareil
  Future<List<dynamic>> getAvailableLanguages() async {
    return await _tts.getLanguages;
  }

  Future<void> dispose() async {
    await _tts.stop();
    await _audioPlayer.dispose();
  }
}
