import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../models/chat_message.dart';

/// Talks to the backend's embedded AI chat endpoint
/// (`POST /api/v1/cashlyze/ai/chat`, app/api/v1/cashlyze/routes/ai_chat.py).
///
/// This is deliberately the *only* way the app talks to the AI assistant -
/// there is no Anthropic API key anywhere in this client, and no direct MCP
/// protocol traffic. The backend holds the key, runs the tool-calling loop
/// against the same cashlyze-mcp-server tools an external MCP client would
/// use, and returns just the final reply text. The existing Cashlyze
/// access token (already attached by AuthInterceptor) is all the auth this
/// needs - no separate OAuth/MCP token dance for this in-app surface.
class AiChatService {
  const AiChatService({required final ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  /// Sends the full conversation so far (ending with the new user message)
  /// and returns the assistant's reply. Uses a longer timeout than the
  /// app's default since the backend may run a multi-step tool-calling loop
  /// (Anthropic call -> MCP tool -> Anthropic call again) within one request.
  Future<String> sendMessage(final List<ChatMessage> conversation) async {
    final response = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.aiChat,
      data: {
        'messages': conversation.map((final m) => m.toJson()).toList(),
      },
      options: Options(
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 30),
      ),
    );
    final body = (response.data as Map).cast<String, dynamic>();
    return body['reply'] as String? ?? '';
  }
}

final aiChatServiceProvider = Provider<AiChatService>((final ref) {
  return AiChatService(apiClient: ref.watch(apiClientProvider));
});
