/**
 * Shared response helpers.
 */

/**
 * Build CORS headers from the Worker environment.
 * @param {object} env  Wrangler env bindings
 * @returns {object}
 */
export function corsHeaders(env) {
  const origin = env.ALLOWED_ORIGIN || 'https://cashlyze-flutter.pages.dev';
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  };
}

/**
 * Create a JSON Response with CORS headers.
 * @param {object} body     Plain JS object — will be JSON-serialised
 * @param {number} status
 * @param {object} cors     CORS headers object
 * @returns {Response}
 */
export function jsonResponse(body, status, cors) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json',
      ...cors,
    },
  });
}

/**
 * Validate that the request origin matches the allowed origin.
 * Returns null if OK, or a Response if forbidden.
 */
export function checkOrigin(request, env) {
  const origin = request.headers.get('Origin') || '';
  const allowed = env.ALLOWED_ORIGIN || '';
  if (origin && allowed && origin !== allowed) {
    return jsonResponse({ error: 'Forbidden origin' }, 403, corsHeaders(env));
  }
  return null;
}
