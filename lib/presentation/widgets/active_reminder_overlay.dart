import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/task.dart';
import '../../core/providers.dart';
import '../viewmodels/task_viewmodel.dart';

class ActiveReminderOverlay extends ConsumerStatefulWidget {
  final Task task;
  const ActiveReminderOverlay({super.key, required this.task});
  @override
  ConsumerState<ActiveReminderOverlay> createState() =>
      _ActiveReminderOverlayState();
}

class _ActiveReminderOverlayState
    extends ConsumerState<ActiveReminderOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isListening = ref.watch(isListeningProvider);
    final partialSpeech = ref.watch(partialSpeechResultProvider);
    final timeStr = DateFormat('HH:mm').format(widget.task.scheduledDateTime);

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A0533), Color(0xFF0D0D1A)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const SizedBox(height: 40),

                // ─── Pulsing alarm icon ──────────────────────
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, __) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer glow rings
                        for (int r = 1; r <= 3; r++)
                          Container(
                            width: 80.0 + r * 30 * _pulse.value,
                            height: 80.0 + r * 30 * _pulse.value,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.deepPurpleAccent
                                    .withValues(alpha: max(0, 0.3 - r * 0.08) * _pulse.value),
                                width: 1.5,
                              ),
                            ),
                          ),
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF7C4DFF),
                                Color(0xFF651FFF),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF7C4DFF)
                                    .withValues(alpha: 0.6),
                                blurRadius: 30,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.alarm_rounded,
                              size: 40, color: Colors.white),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 32),

                // ─── Time ───────────────────────────────────
                Text(
                  timeStr,
                  style: const TextStyle(
                    color: Color(0xFF7C4DFF),
                    fontSize: 52,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 8),

                // ─── Title ──────────────────────────────────
                Text(
                  widget.task.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // ─── Description ────────────────────────────
                Text(
                  widget.task.description,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 15,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),

                const Spacer(),

                // ─── Voice indicator ────────────────────────
                _VoiceChip(isListening: isListening, partial: partialSpeech),
                const SizedBox(height: 8),
                Text(
                  'Dites "Stop" pour terminer · "Reporter" pour 10 min',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 28),

                // ─── Action buttons ──────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _OutlineBtn(
                        label: 'Reporter\n10 min',
                        icon: Icons.snooze_rounded,
                        onPressed: () => ref
                            .read(taskViewModelProvider.notifier)
                            .snoozeTask(widget.task.id!),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _FilledBtn(
                        label: 'Terminer',
                        icon: Icons.check_circle_rounded,
                        onPressed: () => ref
                            .read(taskViewModelProvider.notifier)
                            .completeTask(widget.task.id!),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 350.ms)
        .slideY(begin: 0.04, end: 0, duration: 350.ms, curve: Curves.easeOut);
  }
}

class _VoiceChip extends StatelessWidget {
  final bool isListening;
  final String partial;
  const _VoiceChip({required this.isListening, required this.partial});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: isListening
            ? Colors.redAccent.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.06),
        border: Border.all(
          color: isListening ? Colors.redAccent : Colors.white24,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isListening ? Icons.mic_rounded : Icons.mic_off_rounded,
            color: isListening ? Colors.redAccent : Colors.white38,
            size: 18,
          ),
          const SizedBox(width: 10),
          Text(
            isListening
                ? (partial.isEmpty ? 'En écoute…' : partial)
                : 'Micro inactif',
            style: TextStyle(
              color: isListening ? Colors.white : Colors.white38,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (isListening) ...[
            const SizedBox(width: 10),
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 1.8, color: Colors.redAccent),
            ),
          ],
        ],
      ),
    );
  }
}

class _OutlineBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  const _OutlineBtn(
      {required this.label, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label, textAlign: TextAlign.center),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white38),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class _FilledBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  const _FilledBtn(
      {required this.label, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF00C853),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
        shadowColor: const Color(0xFF00C853).withValues(alpha: 0.5),
      ),
    );
  }
}
