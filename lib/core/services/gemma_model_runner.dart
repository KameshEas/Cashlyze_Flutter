import 'package:flutter_gemma/flutter_gemma.dart';

import '../mcp/mcp_exception.dart';

/// Thin adapter around the `flutter_gemma` plugin (verified against the
/// resolved version in pubspec.lock - `flutter_gemma-0.16.5` - by reading
/// its source directly under the pub cache, not assumed from memory).
///
/// Isolated in its own file: nothing outside this class should import
/// `package:flutter_gemma` directly, so a future plugin version bump only
/// needs changes here.
class GemmaModelRunner {
  GemmaModelRunner._();
  static final GemmaModelRunner instance = GemmaModelRunner._();

  static const _modelUrl =
      'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/Gemma3-1B-IT_multi-prefill-seq_q8_ekv2048.task';

  InferenceModel? _model;
  InferenceChat? _chat;

  // `FlutterGemma.initialize()` must run exactly once before any other call
  // - `ServiceRegistry.initialize()` unconditionally rebuilds the registry on
  // every call, it isn't safe to call per-download/per-chat like the rest of
  // this class's methods are. Memoized here instead of in `main.dart` so this
  // remains the only file that knows about `package:flutter_gemma`.
  static Future<void>? _initialization;

  Future<void> _ensureInitialized() {
    return _initialization ??= FlutterGemma.initialize();
  }

  Future<bool> isDownloaded() async {
    await _ensureInitialized();
    return FlutterGemma.hasActiveModel();
  }

  /// Downloads the model to app storage, reporting a 0.0-1.0 progress
  /// fraction (the plugin now reports a real 0-100 percentage itself, no
  /// more approximating from a guessed file size). No-op if already
  /// downloaded.
  Future<void> download({
    required final void Function(double progress) onProgress,
  }) async {
    if (await isDownloaded()) return;
    try {
      await FlutterGemma.installModel(modelType: ModelType.gemmaIt)
          .fromNetwork(_modelUrl)
          .withProgress((final progress) => onProgress(progress / 100))
          .install();
    } catch (e) {
      throw ModelDownloadException('Model download failed: $e');
    }
  }

  /// Loads the model and starts a fresh tool-calling chat session. Safe to
  /// call repeatedly - reuses the already-loaded model/chat unless
  /// [forceNewChat] is set (e.g. starting a new conversation).
  Future<InferenceChat> ensureChat({
    required final List<Tool> tools,
    final bool forceNewChat = false,
  }) async {
    if (_chat != null && !forceNewChat) return _chat!;

    if (!await isDownloaded()) {
      throw const ModelNotDownloadedException();
    }

    try {
      _model ??= await FlutterGemma.getActiveModel(maxTokens: 2048);

      await _chat?.stopGeneration();
      _chat = await _model!.createChat(
        temperature: 0.4,
        topK: 40,
        topP: 0.9,
        tools: tools,
        supportsFunctionCalls: true,
      );
      return _chat!;
    } catch (e) {
      throw ModelLoadException('Failed to load the on-device model: $e');
    }
  }

  /// Discards the current chat session (not the downloaded model file) so
  /// the next [ensureChat] call starts a clean conversation.
  Future<void> resetChat() async {
    await _chat?.stopGeneration();
    _chat = null;
  }

  Future<void> dispose() async {
    await _chat?.stopGeneration();
    _chat = null;
    await _model?.close();
    _model = null;
  }
}
