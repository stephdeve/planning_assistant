import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
  bool _hasText = false;

  final _suggestions = [
    "Que me reste-t-il aujourd'hui ?",
    'Y a-t-il des conflits dans mon planning ?',
    'Optimise mon planning de la semaine.',
    'Quelles sont mes tâches récurrentes ?',
    'Réorganise mes tâches de demain.',
  ];

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() => _hasText = _controller.text.trim().isNotEmpty);
    });
  }

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
    final cs = theme.colorScheme;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.surface,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cs.primary, cs.tertiary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy_rounded,
                  size: 20, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Assistant IA',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                Text('Powered by GPT',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: cs.outline)),
              ],
            ),
          ],
        ),
        actions: [
          if (chatState.messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Effacer',
              onPressed: () =>
                  ref.read(aiChatViewModelProvider.notifier).clearConversation(),
            ),
        ],
      ),

      body: Column(
        children: [
          // ─── Messages ─────────────────────────────────────
          Expanded(
            child: chatState.messages.isEmpty
                ? _WelcomeScreen(
                    suggestions: _suggestions,
                    onTap: _sendSuggestion,
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    itemCount: chatState.messages.length +
                        (chatState.isLoading ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == chatState.messages.length) {
                        return const _TypingBubble();
                      }
                      return _MessageBubble(message: chatState.messages[i]);
                    },
                  ),
          ),

          // ─── Quick suggestions ────────────────────────────
          if (chatState.messages.length < 3)
            _SuggestionsRow(
              suggestions: _suggestions.take(3).toList(),
              onTap: _sendSuggestion,
            ),

          // ─── Input bar ────────────────────────────────────
          _InputBar(
            controller: _controller,
            isLoading: chatState.isLoading,
            hasText: _hasText,
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

  void _sendSuggestion(String s) {
    _controller.text = s;
    _sendMessage();
  }
}

// ─────────────────────────────────────────────────────────

class _WelcomeScreen extends StatelessWidget {
  final List<String> suggestions;
  final ValueChanged<String> onTap;
  const _WelcomeScreen({required this.suggestions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary, cs.tertiary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child:
                const Icon(Icons.smart_toy_rounded, size: 40, color: Colors.white),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Votre assistant planning IA',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Posez n\'importe quelle question sur votre planning. '
          'Je détecte les conflits, optimise votre emploi du temps et réponds à vos questions.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: cs.outline),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        Text('Suggestions',
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        ...suggestions.map((s) => _SuggestionTile(text: s, onTap: onTap)),
      ],
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  final String text;
  final ValueChanged<String> onTap;
  const _SuggestionTile({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cs.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => onTap(text),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.lightbulb_rounded,
                    size: 18, color: cs.primary),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(text,
                        style: const TextStyle(fontWeight: FontWeight.w500))),
                Icon(Icons.arrow_forward_rounded,
                    size: 16, color: cs.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isUser = message.isFromUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cs.primary, cs.tertiary],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy_rounded,
                  size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? cs.primary : cs.surfaceContainerHigh,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(
                      color: isUser ? cs.onPrimary : cs.onSurface,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    DateFormat('HH:mm').format(message.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: (isUser ? cs.onPrimary : cs.outline)
                          .withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [cs.primary, cs.tertiary]),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy_rounded,
                size: 16, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 36,
                  height: 14,
                  child: LinearProgressIndicator(
                    borderRadius: BorderRadius.circular(4),
                    color: cs.primary,
                    backgroundColor: cs.primaryContainer,
                  ),
                ),
                const SizedBox(width: 8),
                Text('Réflexion…',
                    style: TextStyle(color: cs.outline, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionsRow extends StatelessWidget {
  final List<String> suggestions;
  final ValueChanged<String> onTap;
  const _SuggestionsRow({required this.suggestions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => ActionChip(
          label: Text(suggestions[i],
              style: TextStyle(fontSize: 12, color: cs.primary)),
          backgroundColor: cs.primaryContainer.withValues(alpha: 0.5),
          side: BorderSide(color: cs.primary.withValues(alpha: 0.25)),
          onPressed: () => onTap(suggestions[i]),
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final bool hasText;
  final VoidCallback onSend;
  const _InputBar({
    required this.controller,
    required this.isLoading,
    required this.hasText,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: cs.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Posez votre question…',
                  hintStyle: TextStyle(color: cs.outline),
                  filled: true,
                  fillColor: cs.surfaceContainerHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: Material(
                color: (hasText && !isLoading) ? cs.primary : cs.surfaceContainerHigh,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: (isLoading) ? null : onSend,
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cs.primary,
                            ),
                          )
                        : Icon(
                            Icons.send_rounded,
                            size: 20,
                            color: hasText ? cs.onPrimary : cs.outline,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
