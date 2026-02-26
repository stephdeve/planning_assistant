// ============================================================
// PAGE CHAT IA — ASSISTANT INTELLIGENT DE PLANNING
// Interface conversationnelle avec l'IA pour analyser et
// optimiser le planning. Propose des raccourcis de questions
// courantes et affiche les réponses en temps réel.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/providers.dart';
import '../viewmodels/ai_chat_viewmodel.dart';
import '../viewmodels/task_viewmodel.dart';

class AiChatPage extends ConsumerStatefulWidget {
  const AiChatPage({super.key});

  @override
  ConsumerState<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends ConsumerState<AiChatPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  // Questions suggérées pour guider l'utilisateur
  final _suggestions = [
    "Que me reste-t-il aujourd'hui ?",
    "Réorganise mes tâches de demain.",
    "Y a-t-il des conflits dans mon planning ?",
    "Optimise mon planning de la semaine.",
    "Quelles sont mes tâches récurrentes ?",
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(aiChatViewModelProvider);
    final theme = Theme.of(context);

    // Auto-scroll vers le bas à chaque nouveau message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            CircleAvatar(
              backgroundColor: Color(0xFF6750A4),
              radius: 16,
              child: Icon(Icons.smart_toy, size: 18, color: Colors.white),
            ),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Assistant IA'),
                Text('Powered by GPT', style: TextStyle(fontSize: 11)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Effacer la conversation',
            onPressed: () => ref
                .read(aiChatViewModelProvider.notifier)
                .clearConversation(),
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Zone de messages ──────────────────────────────────
          Expanded(
            child: chatState.messages.isEmpty
                ? _WelcomeScreen(suggestions: _suggestions, onSuggestionTap: _sendSuggestion)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: chatState.messages.length +
                        (chatState.isLoading ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == chatState.messages.length) {
                        // Indicateur de chargement à la fin
                        return const _TypingIndicator();
                      }
                      return _MessageBubble(
                          message: chatState.messages[i]);
                    },
                  ),
          ),

          // ─── Suggestions rapides (seulement si peu de messages) ──
          if (chatState.messages.length < 3)
            _SuggestionsRow(
              suggestions: _suggestions.take(3).toList(),
              onTap: _sendSuggestion,
            ),

          // ─── Barre de saisie ───────────────────────────────────
          _InputBar(
            controller: _controller,
            isLoading: chatState.isLoading,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    final tasks = ref.read(taskViewModelProvider).allTasks;
    ref.read(aiChatViewModelProvider.notifier).sendMessage(text, tasks);
  }

  void _sendSuggestion(String suggestion) {
    _controller.text = suggestion;
    _sendMessage();
  }
}

// ─────────────────────────────────────────────────────────
// WIDGETS INTERNES
// ─────────────────────────────────────────────────────────

/// Écran d'accueil du chat quand aucun message n'existe
class _WelcomeScreen extends StatelessWidget {
  final List<String> suggestions;
  final ValueChanged<String> onSuggestionTap;

  const _WelcomeScreen({required this.suggestions, required this.onSuggestionTap});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 32),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.smart_toy,
              size: 40,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Votre assistant planning IA',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Posez-moi n\'importe quelle question sur votre planning. '
            'Je peux détecter les conflits, optimiser votre emploi du temps '
            'et répondre à vos questions.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Text(
            'Questions suggérées',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 12),
          ...suggestions.map((s) => _SuggestionCard(
                text: s,
                onTap: () => onSuggestionTap(s),
              )),
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _SuggestionCard({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(Icons.lightbulb_outline,
            color: Theme.of(context).colorScheme.primary),
        title: Text(text),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}

/// Bulle de message individuelle (utilisateur ou IA)
class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isFromUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar IA
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(Icons.smart_toy,
                  size: 16, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 8),
          ],

          // Contenu du message
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(
                      color: isUser
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('HH:mm').format(message.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: (isUser
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurfaceVariant)
                          .withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Espace côté utilisateur
          if (isUser) const SizedBox(width: 40),
        ],
      ),
    );
  }
}

/// Indicateur "l'IA est en train de taper..."
class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor:
                Theme.of(context).colorScheme.primaryContainer,
            child: Icon(Icons.smart_toy,
                size: 16,
                color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 40,
                  height: 16,
                  child: LinearProgressIndicator(),
                ),
                const SizedBox(width: 8),
                Text(
                  'En train de réfléchir...',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Rangée de suggestions rapides sous la zone de messages
class _SuggestionsRow extends StatelessWidget {
  final List<String> suggestions;
  final ValueChanged<String> onTap;

  const _SuggestionsRow({required this.suggestions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => ActionChip(
          label: Text(suggestions[i], style: const TextStyle(fontSize: 12)),
          onPressed: () => onTap(suggestions[i]),
        ),
      ),
    );
  }
}

/// Barre de saisie avec bouton d'envoi
class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.isLoading,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Posez votre question...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(24)),
                ),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              maxLines: 4,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          // Bouton d'envoi (ou spinner si en cours)
          FilledButton(
            onPressed: isLoading ? null : onSend,
            style: FilledButton.styleFrom(
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(12),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}
