import 'package:flutter_gemma/core/model.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

import '../mcp/mcp_exception.dart';

/// Thin adapter around the `flutter_gemma` plugin (verified against the
/// resolved version in pubspec.lock - `flutter_gemma-0.10.6` - by reading
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

  /// Rough size of the quantized .task file, used only to turn the plugin's
  /// raw byte-count progress stream into an approximate 0.0-1.0 fraction for
  /// the download UI - not exact, HuggingFace doesn't expose a stable
  /// content-length the plugin surfaces here.
  static const _approxModelBytes = 620 * 1024 * 1024;

  InferenceModel? _model;
  InferenceChat? _chat;

  Future<bool> isDownloaded() => FlutterGemmaPlugin.instance.modelManager.isModelInstalled;

  /// Downloads the model to app storage, reporting an approximate 0.0-1.0
  /// progress. No-op if already downloaded.
  Future<void> download({
    required final void Function(double progress) onProgress,
  }) async {
    if (await isDownloaded()) return;
    try {
      final modelManager = FlutterGemmaPlugin.instance.modelManager;
      await for (final bytesDownloaded in modelManager.downloadModelFromNetworkWithProgress(_modelUrl)) {
        onProgress((bytesDownloaded / _approxModelBytes).clamp(0.0, 1.0));
      }
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
      _model ??= await FlutterGemmaPlugin.instance.createModel(
        modelType: ModelType.gemmaIt,
        maxTokens: 2048,
      );

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
