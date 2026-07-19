/// Typed exceptions for the on-device AI / MCP feature.
///
/// Kept separate from [ApiException] (which is `sealed` to its own file and
/// models the regular Cashlyze REST API) since these cover a different
/// failure surface: OAuth/PKCE handshake, MCP protocol errors, and local
/// model inference - none of which are HTTP-status-code shaped.
sealed class McpException implements Exception {
  const McpException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

// ── OAuth / connect flow ─────────────────────────────────────────────────────

/// The user isn't logged into Cashlyze yet - required before the MCP OAuth
/// authorize step can run (it needs an existing Cashlyze bearer token).
final class McpNotLoggedInException extends McpException {
  const McpNotLoggedInException()
      : super('Log in to Cashlyze first to connect on-device AI.');
}

/// The `/oauth/authorize` or `/oauth/token` exchange failed.
final class McpAuthorizationException extends McpException {
  const McpAuthorizationException(super.message);
}

/// No MCP token pair is stored yet - the user hasn't completed the connect
/// flow, or it was disconnected/revoked.
final class McpNotConnectedException extends McpException {
  const McpNotConnectedException()
      : super('On-device AI isn\'t connected yet.');
}

/// The MCP refresh token itself was rejected - the user must reconnect via
/// the full authorize flow again.
final class McpReauthRequiredException extends McpException {
  const McpReauthRequiredException()
      : super('Your on-device AI connection expired. Please reconnect.');
}

// ── MCP protocol / transport ─────────────────────────────────────────────────

/// Network/transport failure talking to the MCP server.
final class McpConnectionException extends McpException {
  const McpConnectionException([super.message = 'Could not reach the MCP server']);
}

/// The MCP server returned a JSON-RPC error object for a request.
final class McpProtocolException extends McpException {
  const McpProtocolException(super.message, {this.code});

  final int? code;
}

/// A tool call returned `isError: true` in its result.
final class McpToolException extends McpException {
  const McpToolException(this.toolName, super.message);

  final String toolName;
}

// ── On-device model ───────────────────────────────────────────────────────────

/// The Gemma model file isn't downloaded yet.
final class ModelNotDownloadedException extends McpException {
  const ModelNotDownloadedException()
      : super('The on-device AI model hasn\'t been downloaded yet.');
}

/// Model download failed (network, storage, checksum).
final class ModelDownloadException extends McpException {
  const ModelDownloadException(super.message);
}

/// Model failed to load into memory (OOM, unsupported device/ABI).
final class ModelLoadException extends McpException {
  const ModelLoadException(super.message);
}

/// The model produced output that couldn't be parsed as a valid response
/// (e.g. malformed tool-call JSON after retries).
final class ModelInferenceException extends McpException {
  const ModelInferenceException(super.message);
}

/// Too many tool-call iterations in one turn without reaching a final
/// answer - guards against a runaway local agentic loop.
final class McpMaxIterationsException extends McpException {
  const McpMaxIterationsException()
      : super('The assistant couldn\'t finish this request. Please try rephrasing.');
}
