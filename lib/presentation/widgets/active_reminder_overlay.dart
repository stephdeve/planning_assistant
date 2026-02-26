// ============================================================
// OVERLAY DE RAPPEL ACTIF — WIDGET CRITIQUE
// Affiché par-dessus toute l'application quand une tâche
// est en train de sonner. Il bloque l'interaction jusqu'à
// ce que l'utilisateur agisse (terminer, reporter).
// Affiche aussi l'indicateur vocal en temps réel.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/task.dart';
import '../../core/providers.dart';
import '../viewmodels/task_viewmodel.dart';

/// Overlay semi-transparent affiché lors d'un rappel actif.
/// Conçu pour être visible même quand l'utilisateur est sur
/// une autre page de l'application.
class ActiveReminderOverlay extends ConsumerWidget {
  final Task task;

  const ActiveReminderOverlay({super.key, required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isListening = ref.watch(isListeningProvider);
    final partialSpeech = ref.watch(partialSpeechResultProvider);
    final theme = Theme.of(context);
    final timeFormatter = DateFormat('HH:mm');

    return Material(
      // Fond semi-transparent pour ne pas perdre le contexte
      color: Colors.black.withOpacity(0.85),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ─── Icône animée ──────────────────────────────────
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary.withOpacity(0.2),
                  border: Border.all(
                    color: theme.colorScheme.primary,
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.alarm,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),

              // ─── Heure et titre ────────────────────────────────
              Text(
                timeFormatter.format(task.scheduledDateTime),
                style: theme.textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                task.title,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                task.description,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 32),

              // ─── Indicateur de reconnaissance vocale ──────────
              _VoiceIndicator(
                isListening: isListening,
                partialText: partialSpeech,
              ),
              const SizedBox(height: 8),
              Text(
                'Dites "Stop" pour terminer ou "Reporter" pour 10 min',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.white60,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // ─── Boutons d'action ──────────────────────────────
              Row(
                children: [
                  // Bouton Reporter (snooze)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => ref
                          .read(taskViewModelProvider.notifier)
                          .snoozeTask(task.id!),
                      icon: const Icon(Icons.snooze),
                      label: const Text('Reporter\n10 min',
                          textAlign: TextAlign.center),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Bouton Terminer
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => ref
                          .read(taskViewModelProvider.notifier)
                          .completeTask(task.id!),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Terminer',
                          style: TextStyle(fontSize: 16)),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Indicateur visuel animé de l'écoute vocale
class _VoiceIndicator extends StatelessWidget {
  final bool isListening;
  final String partialText;

  const _VoiceIndicator({
    required this.isListening,
    required this.partialText,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: isListening
            ? Colors.red.withOpacity(0.2)
            : Colors.white.withOpacity(0.1),
        border: Border.all(
          color: isListening ? Colors.red : Colors.white30,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isListening ? Icons.mic : Icons.mic_off,
            color: isListening ? Colors.red : Colors.white54,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            isListening
                ? (partialText.isEmpty ? 'En écoute...' : partialText)
                : 'Micro inactif',
            style: TextStyle(
              color: isListening ? Colors.white : Colors.white54,
              fontSize: 14,
            ),
          ),
          if (isListening) ...[
            const SizedBox(width: 8),
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.red,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
