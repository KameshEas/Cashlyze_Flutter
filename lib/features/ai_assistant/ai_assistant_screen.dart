import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/mcp/mcp_exception.dart';
import '../../core/mcp/mcp_oauth_client.dart';
import '../../core/models/chat_message.dart';
import '../../core/services/on_device_ai_service.dart';
import '../../core/ui/constants.dart';

/// Maps a chat-send failure to plain, non-technical copy for the chat
/// bubble. Raw exception detail is developer diagnostic text, not
/// something to show a user - it's logged instead (see [_send]) so it's
/// still visible while debugging.
String _friendlyChatError(final Object e) {
  return switch (e) {
    McpConnectionException() => "Couldn't reach your Cashlyze data. Check your connection and try again.",
    McpToolException(:final message) => message,
    McpMaxIterationsException() => 'That request was too complex for on-device AI to finish. Try breaking it into smaller questions.',
    McpReauthRequiredException() => 'Your on-device AI connection expired. Please reconnect from the assistant settings.',
    ModelNotDownloadedException() || ModelLoadException() =>
      "The on-device AI model isn't ready. Please download it from the assistant settings.",
    ModelInferenceException() => "The assistant couldn't generate a response. Please try again.",
    McpException(:final message) => message,
    _ => "The AI assistant isn't available right now. Please try again later.",
  };
}

/// Embedded AI assistant chat panel.
///
/// Runs entirely on-device: a small Gemma model (via `flutter_gemma`) does
/// the reasoning locally, and calls the Cashlyze MCP server directly over
/// Streamable HTTP for any data it needs (see [OnDeviceAiService]) - no
/// message content is sent to a third-party AI vendor. Requires a one-time
/// "connect" step (OAuth/PKCE against the user's own Cashlyze login) and a
/// one-time model download before the chat itself is usable.
class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

enum _SetupStage { checking, needsConnect, connecting, needsDownload, downloading, ready }

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  _SetupStage _stage = _SetupStage.checking;
  double _downloadProgress = 0;
  String? _setupError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkSetup());
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkSetup() async {
    final connected = await ref.read(mcpOAuthClientProvider).isConnected();
    if (!connected) {
      if (mounted) setState(() => _stage = _SetupStage.needsConnect);
      return;
    }
    await _checkModel();
  }

  Future<void> _checkModel() async {
    final downloaded = await ref.read(onDeviceAiServiceProvider).isModelDownloaded();
    if (!mounted) return;
    if (!downloaded) {
      setState(() => _stage = _SetupStage.needsDownload);
      return;
    }
    await ref.read(onDeviceAiServiceProvider).startConversation();
    if (mounted) setState(() => _stage = _SetupStage.ready);
  }

  Future<void> _connect() async {
    setState(() {
      _stage = _SetupStage.connecting;
      _setupError = null;
    });
    try {
      await ref.read(mcpOAuthClientProvider).connect();
      await _checkModel();
    } catch (e) {
      if (kDebugMode) debugPrint('[AiAssistant] connect failed: $e');
      if (!mounted) return;
      setState(() {
        _stage = _SetupStage.needsConnect;
        _setupError = _friendlyChatError(e);
      });
    }
  }

  Future<void> _downloadModel() async {
    setState(() {
      _stage = _SetupStage.downloading;
      _downloadProgress = 0;
      _setupError = null;
    });
    try {
      await ref.read(onDeviceAiServiceProvider).downloadModel(
            onProgress: (final p) {
              if (mounted) setState(() => _downloadProgress = p);
            },
          );
      await _checkModel();
    } catch (e) {
      if (kDebugMode) debugPrint('[AiAssistant] model download failed: $e');
      if (!mounted) return;
      setState(() {
        _stage = _SetupStage.needsDownload;
        _setupError = _friendlyChatError(e);
      });
    }
  }

  Future<void> _disconnect() async {
    await ref.read(mcpOAuthClientProvider).disconnect();
    if (!mounted) return;
    setState(() {
      _messages.clear();
      _stage = _SetupStage.needsConnect;
    });
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
      final reply = await ref.read(onDeviceAiServiceProvider).sendMessage(text);
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
      if (e is McpReauthRequiredException) {
        setState(() => _stage = _SetupStage.needsConnect);
      }
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
        actions: [
          if (_stage == _SetupStage.ready)
            IconButton(
              tooltip: 'Disconnect on-device AI',
              icon: const Icon(Icons.link_off_rounded),
              onPressed: _disconnect,
            ),
        ],
      ),
      body: switch (_stage) {
        _SetupStage.checking => const Center(child: CircularProgressIndicator()),
        _SetupStage.needsConnect || _SetupStage.connecting => _ConnectPrompt(
            theme: theme,
            isConnecting: _stage == _SetupStage.connecting,
            error: _setupError,
            onConnect: _connect,
          ),
        _SetupStage.needsDownload || _SetupStage.downloading => _ModelDownloadPrompt(
            theme: theme,
            isDownloading: _stage == _SetupStage.downloading,
            progress: _downloadProgress,
            error: _setupError,
            onDownload: _downloadModel,
          ),
        _SetupStage.ready => _ChatBody(
            theme: theme,
            messages: _messages,
            isSending: _isSending,
            inputController: _inputController,
            scrollController: _scrollController,
            onSend: _send,
          ),
      },
    );
  }
}

class _ConnectPrompt extends StatelessWidget {
  const _ConnectPrompt({
    required this.theme,
    required this.isConnecting,
    required this.error,
    required this.onConnect,
  });

  final ThemeData theme;
  final bool isConnecting;
  final String? error;
  final VoidCallback onConnect;

  @override
  Widget build(final BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_outlined, size: 40, color: theme.colorScheme.primary.withValues(alpha: 0.6)),
            const SizedBox(height: AppSpacing.s16),
            Text(
              'Connect on-device AI',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              'The assistant runs fully on your device and reads your Cashlyze '
              'data directly - nothing is sent to a third-party AI service. '
              "You'll be asked to authorize it once.",
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              textAlign: TextAlign.center,
            ),
            if (error != null) ...[
              const SizedBox(height: AppSpacing.s16),
              Text(
                error!,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: AppSpacing.s24),
            FilledButton(
              onPressed: isConnecting ? null : onConnect,
              child: isConnecting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Connect'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelDownloadPrompt extends StatelessWidget {
  const _ModelDownloadPrompt({
    required this.theme,
    required this.isDownloading,
    required this.progress,
    required this.error,
    required this.onDownload,
  });

  final ThemeData theme;
  final bool isDownloading;
  final double progress;
  final String? error;
  final VoidCallback onDownload;

  @override
  Widget build(final BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.download_rounded, size: 40, color: theme.colorScheme.primary.withValues(alpha: 0.6)),
            const SizedBox(height: AppSpacing.s16),
            Text(
              'Download the AI model',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              'A one-time download (roughly 600 MB) so the assistant can run '
              'fully offline-capable on this device. Wi-Fi recommended.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              textAlign: TextAlign.center,
            ),
            if (error != null) ...[
              const SizedBox(height: AppSpacing.s16),
              Text(
                error!,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: AppSpacing.s24),
            if (isDownloading)
              Column(
                children: [
                  SizedBox(
                    width: 200,
                    child: LinearProgressIndicator(value: progress > 0 ? progress : null),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Text('${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%'),
                ],
              )
            else
              FilledButton(onPressed: onDownload, child: const Text('Download')),
          ],
        ),
      ),
    );
  }
}

class _ChatBody extends StatelessWidget {
  const _ChatBody({
    required this.theme,
    required this.messages,
    required this.isSending,
    required this.inputController,
    required this.scrollController,
    required this.onSend,
  });

  final ThemeData theme;
  final List<ChatMessage> messages;
  final bool isSending;
  final TextEditingController inputController;
  final ScrollController scrollController;
  final VoidCallback onSend;

  @override
  Widget build(final BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: messages.isEmpty
              ? _EmptyState(theme: theme)
              : ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(AppSpacing.pagePadding),
                  itemCount: messages.length + (isSending ? 1 : 0),
                  itemBuilder: (final context, final index) {
                    if (index >= messages.length) {
                      return const _TypingIndicator();
                    }
                    return _ChatBubble(message: messages[index]);
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
                    controller: inputController,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    enabled: !isSending,
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
                  onPressed: isSending ? null : onSend,
                  icon: isSending
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
