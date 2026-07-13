/// A single turn in the embedded AI assistant conversation.
///
/// Mirrors the backend's plain user/assistant text shape
/// (app/api/v1/cashlyze/schemas/ai_chat.py `ChatMessage`) - tool-calling
/// happens entirely server-side in a single request, so the client never
/// sees tool_use/tool_result blocks, only the final text per turn.
class ChatMessage {
  const ChatMessage({required this.role, required this.content});

  factory ChatMessage.user(final String content) =>
      ChatMessage(role: 'user', content: content);

  factory ChatMessage.assistant(final String content) =>
      ChatMessage(role: 'assistant', content: content);

  final String role; // 'user' or 'assistant'
  final String content;

  bool get isUser => role == 'user';

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}
