import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/models/chat_message.dart';
import '../../core/services/ai_chat_service.dart';
import '../../core/ui/constants.dart';

/// Maps a chat-send failure to plain, non-technical copy for the chat
/// bubble. Server-side detail (e.g. "GROQ_API_KEY unset") is developer
/// diagnostic text, not something to show a user - it's logged instead
/// (see [_send]) so it's still visible while debugging.
String _friendlyChatError(final Object e) {
  return switch (e) {
    NetworkException() => "You're offline. Check your connection and try again.",
    TimeoutException() => 'That took too long. Please try again.',
    UnauthorizedException() || TokenRefreshException() =>
      'Your session expired. Please log in again.',
    _ => "The AI assistant isn't available right now. Please try again later.",
  };
}

/// Embedded AI assistant chat panel.
///
/// Calls the backend's POST /api/v1/cashlyze/ai/chat endpoint (see
/// [AiChatService]) - the app never talks to Anthropic or MCP directly. The
/// server runs the tool-calling loop against the user's own data and
/// returns only the final reply, so this screen only ever deals in plain
/// user/assistant text turns.
class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _messages.add(ChatMessage.user(text));
      _inputController.clear();
      _isSending = true;
    });
    _scrollToBottom();

    try {
      // Error bubbles are local-only notices, never real model turns - drop
      // them before replaying history back to the backend.
      final history = _messages.where((final m) => !m.isError).toList();
      final reply = await ref.read(aiChatServiceProvider).sendMessage(history);
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage.assistant(reply));
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[AiAssistant] send failed: $e');
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage.error(_friendlyChatError(e)));
      });
    } finally {
      if (mounted) setState(() => _isSending = false);
      _scrollToBottom();
    }
  }

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Assistant'),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _EmptyState(theme: theme)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(AppSpacing.pagePadding),
                    itemCount: _messages.length + (_isSending ? 1 : 0),
                    itemBuilder: (final context, final index) {
                      if (index >= _messages.length) {
                        return const _TypingIndicator();
                      }
                      return _ChatBubble(message: _messages[index]);
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s12,
                AppSpacing.s8,
                AppSpacing.s12,
                AppSpacing.s12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      enabled: !_isSending,
                      decoration: const InputDecoration(
                        hintText: 'Ask about your spending, budgets, splits...',
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: AppRadius.fullAll,
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.s16,
                          vertical: AppSpacing.s12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  IconButton.filled(
                    onPressed: _isSending ? null : _send,
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_upward_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.theme});

  final ThemeData theme;

  @override
  Widget build(final BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_outlined,
              size: 40,
              color: theme.colorScheme.primary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: AppSpacing.s16),
            Text(
              'Ask me about your money',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              '"How much did I spend on food this month?"\n'
              '"Split dinner with Priya and Arjun"\n'
              '"Who do I owe money to?"',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isUser;
    final isError = message.isError;
    final bubbleColor = isUser
        ? theme.colorScheme.primary
        : isError
            ? theme.colorScheme.errorContainer
            : theme.colorScheme.surface;
    final textColor = isUser
        ? theme.colorScheme.onPrimary
        : isError
            ? theme.colorScheme.onErrorContainer
            : theme.colorScheme.onSurface;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s12,
        ),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppRadius.lg),
            topRight: const Radius.circular(AppRadius.lg),
            bottomLeft: Radius.circular(isUser ? AppRadius.lg : AppRadius.sm),
            bottomRight: Radius.circular(isUser ? AppRadius.sm : AppRadius.lg),
          ),
          border: isUser || isError
              ? null
              : Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.06)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isError) ...[
              Icon(Icons.error_outline, size: 16, color: textColor),
              const SizedBox(width: AppSpacing.s8),
            ],
            Flexible(
              child: Text(
                message.content,
                style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chat-bubble "typing" indicator: three dots that bounce in a staggered
/// wave, matching the familiar messaging-app pattern (vs. a plain spinner).
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const _dotCount = 3;
  static const _cycleDuration = Duration(milliseconds: 1000);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _cycleDuration)..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final dotColor = theme.colorScheme.primary;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.06)),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (final context, final _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(_dotCount, (final i) {
                // Stagger each dot's bounce by 1/dotCount of the cycle.
                final phase = (_controller.value - (i / _dotCount)) % 1.0;
                final bounce = phase < 0.5 ? phase / 0.5 : 1 - ((phase - 0.5) / 0.5);
                final scale = 0.5 + bounce * 0.7;
                return Padding(
                  padding: EdgeInsets.only(right: i < _dotCount - 1 ? 5 : 0),
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}
