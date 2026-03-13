/**
 * Cashlyze API — Cloudflare Worker entry point
 *
 * Routes:
 *   GET  /api/health       — health check
 *   POST /api/send-otp     — send a 6-digit OTP to an email address
 *   POST /api/verify-otp   — verify a 6-digit OTP
 */

import { handleHealth } from './handlers/health.js';
import { handleSendOtp } from './handlers/send-otp.js';
import { handleVerifyOtp } from './handlers/verify-otp.js';

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname.replace(/\/$/, ''); // strip trailing slash

    // ── CORS pre-flight for all routes ─────────────────────────────────────
    if (request.method === 'OPTIONS') {
      const origin = env.ALLOWED_ORIGIN || 'https://cashlyze-flutter.pages.dev';
      return new Response(null, {
        status: 204,
        headers: {
          'Access-Control-Allow-Origin': origin,
          'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type',
          'Access-Control-Max-Age': '86400',
        },
      });
    }

    // ── Route dispatch ──────────────────────────────────────────────────────
    if (path === '/api/health' || path === '/health') {
      return handleHealth(request, env);
    }

    if (path === '/api/send-otp' || path === '/send-otp') {
      return handleSendOtp(request, env);
    }

    if (path === '/api/verify-otp' || path === '/verify-otp') {
      return handleVerifyOtp(request, env);
    }

    // ── Static pages — fall through to Workers Assets ───────────────────────
    if (env.ASSETS) {
      return env.ASSETS.fetch(request);
    }

    return new Response(JSON.stringify({ error: 'Not Found' }), {
      status: 404,
      headers: { 'Content-Type': 'application/json' },
    });
  },
};
