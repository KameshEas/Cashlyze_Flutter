/**
 * Verify-OTP handler — POST /api/verify-otp
 *
 * Request body (JSON): { "email": "user@example.com", "otp": "123456" }
 *
 * Required env secrets / vars:
 *   OTP_SECRET                — secret used to hash the OTP
 *   FIREBASE_SERVICE_ACCOUNT  — full service-account JSON string
 *   ALLOWED_ORIGIN            — CORS origin
 */

import { corsHeaders, jsonResponse, checkOrigin } from '../utils/response.js';
import { hashOtp } from '../lib/crypto-utils.js';
import { getAccessToken, firestoreRunQuery, firestorePatch } from '../lib/firebase.js';

export async function handleVerifyOtp(request, env) {
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

  const email = (payload.email || '').toString().trim().toLowerCase();
  const otp = (payload.otp || '').toString().trim();
  if (!email || !otp) {
    return jsonResponse({ error: 'Missing email or otp in request body' }, 400, CORS);
  }

  // ── Lookup OTP in Firestore ───────────────────────────────────────────────
  let serviceAccount;
  let token;
  let projectId;
  try {
    const svc = env.FIREBASE_SERVICE_ACCOUNT;
    if (!svc) throw new Error('FIREBASE_SERVICE_ACCOUNT not set');
    serviceAccount = typeof svc === 'string' ? JSON.parse(svc) : svc;
    projectId = serviceAccount.project_id;
    token = await getAccessToken(serviceAccount);
  } catch (e) {
    return jsonResponse({ error: `Firebase init failed: ${e.message}` }, 500, CORS);
  }

  const nowIso = new Date().toISOString();

  // Structured query: email == email AND used == false AND expiresAt >= now
  // order by createdAt DESC, limit 1
  const structuredQuery = {
    from: [{ collectionId: 'otps' }],
    where: {
      compositeFilter: {
        op: 'AND',
        filters: [
          {
            fieldFilter: {
              field: { fieldPath: 'email' },
              op: 'EQUAL',
              value: { stringValue: email },
            },
          },
          {
            fieldFilter: {
              field: { fieldPath: 'used' },
              op: 'EQUAL',
              value: { booleanValue: false },
            },
          },
          {
            fieldFilter: {
              field: { fieldPath: 'expiresAt' },
              op: 'GREATER_THAN_OR_EQUAL',
              value: { timestampValue: nowIso },
            },
          },
        ],
      },
    },
    orderBy: [{ field: { fieldPath: 'createdAt' }, direction: 'DESCENDING' }],
    limit: 1,
  };

  let docs;
  try {
    docs = await firestoreRunQuery(projectId, structuredQuery, token);
  } catch (e) {
    return jsonResponse({ error: `Firestore query failed: ${e.message}` }, 500, CORS);
  }

  if (!docs.length) {
    return jsonResponse({ error: 'No valid OTP found' }, 400, CORS);
  }

  const { name: docName, data } = docs[0];
  const expectedHash = data.otpHash;
  const givenHash = await hashOtp(otp, env.OTP_SECRET || '');

  if (expectedHash !== givenHash) {
    return jsonResponse({ error: 'Invalid OTP' }, 400, CORS);
  }

  // ── Mark OTP as used ─────────────────────────────────────────────────────
  try {
    await firestorePatch(docName, { used: true, usedAt: new Date() }, token);
  } catch (e) {
    console.error('Failed to mark OTP as used:', e.message || String(e));
  }

  return jsonResponse({ success: true }, 200, CORS);
}
