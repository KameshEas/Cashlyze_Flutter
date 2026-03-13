/**
 * Health-check handler — GET /api/health
 * Returns a simple JSON payload confirming the Worker is alive.
 */

import { corsHeaders, jsonResponse } from '../utils/response.js';

export async function handleHealth(request, env) {
  const CORS = corsHeaders(env);

  if (request.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: { ...CORS, 'Access-Control-Allow-Methods': 'GET, OPTIONS' } });
  }

  if (request.method !== 'GET') {
    return jsonResponse({ ok: false, error: 'Method Not Allowed' }, 405, CORS);
  }

  return jsonResponse(
    {
      ok: true,
      service: 'cashlyze-api',
      endpoints: ['/api/send-otp', '/api/verify-otp', '/api/health'],
      timestamp: new Date().toISOString(),
    },
    200,
    CORS,
  );
}
