import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mcp/mcp_client.dart';
import '../mcp/mcp_exception.dart';
import 'gemma_model_runner.dart';

/// Drives one chat turn end-to-end: on-device Gemma inference + MCP tool
/// calls against the user's own Cashlyze data, entirely on-device except
/// for the MCP HTTP calls themselves (which hit the user's own backend,
/// same trust boundary as the rest of the app - no third-party AI vendor
/// involved, unlike the server-side Groq chat this replaces).
///
/// Mirrors the old `AiChatService.sendMessage` shape (`Future<String>`
/// given the conversation) so the UI layer swap is close to a drop-in
/// replacement - see `ai_assistant_screen.dart`.
class OnDeviceAiService {
  OnDeviceAiService({required this.mcpClient});

  final McpClient mcpClient;

  static const _maxToolIterations = 8;

  List<McpTool>? _cachedTools;

  Future<bool> isModelDownloaded() => GemmaModelRunner.instance.isDownloaded();

  Future<void> downloadModel({required final void Function(double progress) onProgress}) =>
      GemmaModelRunner.instance.download(onProgress: onProgress);

  /// Starts (or restarts) a conversation. Call when opening the chat screen
  /// fresh / on "clear chat" - re-fetches the tool list in case the backend
  /// added new tools since last connect.
  Future<void> startConversation() async {
    _cachedTools = null;
    await GemmaModelRunner.instance.resetChat();
    mcpClient.reset();
  }

  /// Sends a user message and returns the assistant's final text reply,
  /// after running as many MCP tool calls as the model requests.
  Future<String> sendMessage(final String userText) async {
    final tools = await _tools();
    final chat = await GemmaModelRunner.instance.ensureChat(tools: tools);

    await chat.addQuery(Message.text(text: userText, isUser: true));
    var response = await chat.generateChatResponse();

    var iterations = 0;
    while (response is FunctionCallResponse) {
      if (iterations++ >= _maxToolIterations) {
        throw const McpMaxIterationsException();
      }

      final resultText = await _runTool(response.name, response.args);
      await chat.addQuery(
        Message.toolResponse(toolName: response.name, response: {'result': resultText}),
      );
      response = await chat.generateChatResponse();
    }

    if (response is TextResponse) {
      return response.token;
    }
    // ThinkingResponse or an unexpected type reaching here means the model
    // never produced a final answer - surface as an inference failure
    // rather than silently returning nothing.
    throw const ModelInferenceException('The assistant did not return a response.');
  }

  Future<String> _runTool(final String name, final Map<String, dynamic> args) async {
    try {
      return await mcpClient.callTool(name, args);
    } on McpToolException catch (e) {
      // Relay the tool's own error text back to the model as the "result"
      // so it can explain the failure to the user in its next turn,
      // instead of the whole conversation throwing.
      return 'Error: ${e.message}';
    }
  }

  Future<List<Tool>> _tools() async {
    final cached = _cachedTools;
    final mcpTools = cached ?? await mcpClient.listTools();
    _cachedTools ??= mcpTools;

    return mcpTools
        .map((final t) => Tool(
              name: t.name,
              description: t.description,
              parameters: t.inputSchema,
            ))
        .toList();
  }
}

final onDeviceAiServiceProvider = Provider<OnDeviceAiService>((final ref) {
  return OnDeviceAiService(mcpClient: ref.watch(mcpClientProvider));
});
