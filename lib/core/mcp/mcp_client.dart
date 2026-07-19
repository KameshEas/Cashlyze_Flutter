import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env_config.dart';
import 'mcp_exception.dart';
import 'mcp_oauth_client.dart';

/// Minimal MCP (Model Context Protocol) client over Streamable HTTP.
///
/// Talks to `services/cashlyze/app/mcp/server.py` (mounted at
/// `/mcp/cashlyze/` behind the gateway). Implements just the subset of the
/// spec this app needs: the `initialize` handshake, `tools/list`,
/// `tools/call`, `resources/list`, `resources/read`. No client->server
/// sampling/roots support, no resumable-stream replay - the cashlyze tools
/// are all synchronous request/response, not long-running, so every call
/// here is a single POST awaiting a single reply (JSON or a one-shot SSE
/// event carrying the same JSON-RPC response).
class McpClient {
  McpClient({required this.oauthClient}) : _dio = Dio(
          BaseOptions(
            baseUrl: EnvConfig.mcpServerUrl,
            connectTimeout: EnvConfig.connectTimeout,
            receiveTimeout: const Duration(seconds: 30),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json, text/event-stream',
            },
          ),
        );

  final McpOAuthClient oauthClient;
  final Dio _dio;

  int _nextId = 1;
  String? _sessionId;
  bool _initialized = false;

  /// Discovers available tools. Safe to call repeatedly - the underlying
  /// session is established lazily on first use and reused after.
  Future<List<McpTool>> listTools() async {
    final result = await _request('tools/list', {});
    final tools = (result['tools'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    return tools.map(McpTool.fromJson).toList();
  }

  /// Calls a tool by name with the given arguments, returning its combined
  /// text content. Throws [McpToolException] if the tool itself reported
  /// `isError: true` (e.g. "budget not found") - this is a normal,
  /// user-relayable failure, distinct from a transport/protocol error.
  Future<String> callTool(final String name, final Map<String, dynamic> arguments) async {
    final result = await _request('tools/call', {
      'name': name,
      'arguments': arguments,
    });

    final content = (result['content'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    final text = content
        .where((final c) => c['type'] == 'text')
        .map((final c) => c['text'] as String? ?? '')
        .join('\n');

    if (result['isError'] == true) {
      throw McpToolException(name, text.isEmpty ? 'Tool call failed.' : text);
    }
    return text;
  }

  /// Closes the logical MCP session. Call on sign-out / disconnect so a
  /// stale session isn't reused after tokens are cleared.
  void reset() {
    _sessionId = null;
    _initialized = false;
  }

  // ── Internal: session + JSON-RPC plumbing ───────────────────────────────

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    final response = await _post('initialize', {
      'protocolVersion': '2025-06-18',
      'capabilities': <String, dynamic>{},
      'clientInfo': {'name': 'cashlyze-mobile', 'version': '1.0.0'},
    }, id: _nextId++);

    final sessionId = response.headers.value('mcp-session-id');
    if (sessionId != null) _sessionId = sessionId;

    _decodeSingleResponse(response); // throws on JSON-RPC error

    // Fire-and-forget notification - no `id`, no response expected.
    await _postRaw({
      'jsonrpc': '2.0',
      'method': 'notifications/initialized',
    });

    _initialized = true;
  }

  Future<Map<String, dynamic>> _request(
    final String method,
    final Map<String, dynamic> params,
  ) async {
    await _ensureInitialized();
    final token = await oauthClient.getValidAccessToken();

    Response<dynamic> response;
    try {
      response = await _post(method, params, id: _nextId++, bearerToken: token);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // Access token expired mid-session - refresh once and retry.
        final refreshed = await oauthClient.refresh();
        response = await _post(method, params, id: _nextId++, bearerToken: refreshed);
      } else {
        rethrow;
      }
    }
    return _decodeSingleResponse(response);
  }

  Future<Response<dynamic>> _post(
    final String method,
    final Map<String, dynamic> params, {
    required final int id,
    final String? bearerToken,
  }) {
    return _postRaw({
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': params,
    }, bearerToken: bearerToken);
  }

  Future<Response<dynamic>> _postRaw(
    final Map<String, dynamic> body, {
    final String? bearerToken,
  }) async {
    final headers = <String, dynamic>{};
    if (_sessionId != null) headers['Mcp-Session-Id'] = _sessionId;
    if (bearerToken != null) headers['Authorization'] = 'Bearer $bearerToken';

    try {
      return await _dio.post<dynamic>(
        '',
        data: body,
        options: Options(headers: headers, responseType: ResponseType.plain),
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw McpConnectionException(e.message ?? 'Could not reach the MCP server');
      }
      rethrow;
    }
  }

  /// Parses a response body that is either a plain JSON-RPC object, or a
  /// single `text/event-stream` frame carrying one `data: {...}` JSON-RPC
  /// message (the only shape the cashlyze server ever emits, since none of
  /// its tools stream multiple messages per call).
  Map<String, dynamic> _decodeSingleResponse(final Response<dynamic> response) {
    final raw = response.data;
    final contentType = response.headers.value('content-type') ?? '';

    late final Map<String, dynamic> message;
    try {
      if (contentType.contains('text/event-stream')) {
        message = _parseSseJson(raw as String);
      } else {
        final decoded = raw is String ? jsonDecode(raw) : raw;
        message = decoded as Map<String, dynamic>;
      }
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[McpClient] Failed to parse response: $raw');
      }
      throw McpProtocolException('Malformed MCP response: $e');
    }

    if (message['error'] != null) {
      final error = message['error'] as Map<String, dynamic>;
      throw McpProtocolException(
        error['message']?.toString() ?? 'MCP error',
        code: error['code'] as int?,
      );
    }
    return (message['result'] as Map<String, dynamic>?) ?? const {};
  }

  Map<String, dynamic> _parseSseJson(final String raw) {
    for (final line in const LineSplitter().convert(raw)) {
      if (line.startsWith('data:')) {
        return jsonDecode(line.substring(5).trim()) as Map<String, dynamic>;
      }
    }
    throw const FormatException('No data: line found in SSE response');
  }
}

/// A tool as reported by `tools/list` - just enough to build a system
/// prompt / function-calling schema for the on-device model.
class McpTool {
  const McpTool({
    required this.name,
    required this.description,
    required this.inputSchema,
  });

  factory McpTool.fromJson(final Map<String, dynamic> json) => McpTool(
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        inputSchema: (json['inputSchema'] as Map<String, dynamic>?) ?? const {},
      );

  final String name;
  final String description;
  final Map<String, dynamic> inputSchema;
}

final mcpClientProvider = Provider<McpClient>((final ref) {
  return McpClient(oauthClient: ref.watch(mcpOAuthClientProvider));
});
