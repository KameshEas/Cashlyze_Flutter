/**
 * Send-OTP handler — POST /api/send-otp
 *
 * Request body (JSON): { "email": "user@example.com" }
 *
 * Required env secrets / vars:
 *   RESEND_API_KEY            — Resend API key
 *   OTP_SECRET                — secret used to hash the OTP
 *   FIREBASE_SERVICE_ACCOUNT  — full service-account JSON string
 *   ALLOWED_ORIGIN            — CORS origin
 *   FROM_EMAIL                — sender address (optional)
 *   DEV_RETURN_OTP            — "true" to include raw OTP in response (dev only)
 */

import { corsHeaders, jsonResponse, checkOrigin } from '../utils/response.js';
import { hashOtp } from '../lib/crypto-utils.js';
import { getAccessToken, firestoreAdd } from '../lib/firebase.js';

export async function handleSendOtp(request, env) {
  const CORS = corsHeaders(env);

  if (request.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: { ...CORS, 'Access-Control-Allow-Methods': 'POST, OPTIONS' } });
  }

  if (request.method !== 'POST') {
    return jsonResponse({ error: 'Method Not Allowed' }, 405, CORS);
  }

  const forbidden = checkOrigin(request, env);
  if (forbidden) return forbidden;

  // ── Parse body ──────────────────────────────────────────────────────────
  let payload;
  try {
    payload = await request.json();
  } catch {
    return jsonResponse({ error: 'Invalid JSON body' }, 400, CORS);
  }

  const email = (payload.email || '').toString().trim();
  if (!email) {
    return jsonResponse({ error: 'Missing email in request body' }, 400, CORS);
  }

  // ── Generate OTP ─────────────────────────────────────────────────────────
  const otp = payload.otp || String(Math.floor(100_000 + Math.random() * 900_000));
  const from = env.FROM_EMAIL || 'Cashlyze <noreply@aspired2d.cloud>';

  if (!env.RESEND_API_KEY) {
    return jsonResponse({ error: 'RESEND_API_KEY not configured on server' }, 500, CORS);
  }

  // ── Send email via Resend ─────────────────────────────────────────────────
  const allowedOrigin = env.ALLOWED_ORIGIN || 'https://cashlyze-flutter.pages.dev';
  const emailPayload = {
    from,
    to: email,
    subject: 'Your Cashlyze verification code',
    text: [
      `Your Cashlyze verification code is: ${otp}`,
      '',
      'This code expires in 10 minutes. Do not share it with anyone.',
      '',
      'If you did not request this code, you can safely ignore this email.',
      '',
      `© Cashlyze · ${allowedOrigin}`,
    ].join('\n'),
  };

  const resendRes = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${env.RESEND_API_KEY}`,
    },
    body: JSON.stringify(emailPayload),
  });

  if (!resendRes.ok) {
    const details = await resendRes.text();
    return jsonResponse({ error: 'Failed sending email', details }, resendRes.status || 502, CORS);
  }

  // ── Store hashed OTP in Firestore ─────────────────────────────────────────
  try {
    const svc = env.FIREBASE_SERVICE_ACCOUNT;
    if (!svc) throw new Error('FIREBASE_SERVICE_ACCOUNT not set');
    const serviceAccount = typeof svc === 'string' ? JSON.parse(svc) : svc;
    const token = await getAccessToken(serviceAccount);
    const projectId = serviceAccount.project_id;

    const now = new Date();
    const expiresAt = new Date(now.getTime() + 10 * 60 * 1000);

    await firestoreAdd(
      projectId,
      'otps',
      {
        email: email.toLowerCase(),
        otpHash: await hashOtp(otp, env.OTP_SECRET || ''),
        createdAt: now,
        expiresAt,
        used: false,
      },
      token,
    );
  } catch (e) {
    // Non-fatal: log but keep going so UI is not blocked if Firestore is unavailable
    console.error('Failed to store OTP in Firestore:', e.message || String(e));
  }

  // ── Respond ───────────────────────────────────────────────────────────────
  const devReturnOtp = env.DEV_RETURN_OTP === 'true';
  return jsonResponse(
    devReturnOtp
      ? { success: true, otp, to: email }
      : { success: true, otp: 'generated', to: email },
    200,
    CORS,
  );
}
