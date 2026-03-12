// Netlify Function: verify-otp
// Expects POST { "email": "user@example.com", "otp": "123456" }
// Requires env: FIREBASE_SERVICE_ACCOUNT, OTP_SECRET

const crypto = require('crypto');
let admin;
try {
  admin = require('firebase-admin');
} catch (e) {
  admin = null;
}

function hashOtp(otp) {
  const secret = process.env.OTP_SECRET || '';
  return crypto.createHash('sha256').update(otp + secret).digest('hex');
}

async function ensureAdminInitialized() {
  if (!admin) return null;
  if (admin.apps && admin.apps.length) return admin;
  const svc = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (!svc) throw new Error('FIREBASE_SERVICE_ACCOUNT not configured');
  const creds = JSON.parse(svc);
  admin.initializeApp({ credential: admin.credential.cert(creds) });
  return admin;
}

exports.handler = async (event) => {
  const ALLOWED_ORIGIN = process.env.ALLOWED_ORIGIN || 'https://cashlyze.netlify.app';
  const CORS_HEADERS = {
    'Access-Control-Allow-Origin': ALLOWED_ORIGIN,
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  };

  if (event.httpMethod === 'OPTIONS') {
    return { statusCode: 204, headers: CORS_HEADERS, body: '' };
  }

  if (event.httpMethod !== 'POST') {
    return { statusCode: 405, headers: CORS_HEADERS, body: JSON.stringify({ error: 'Method Not Allowed' }) };
  }

  try {
    const origin = event.headers.origin || event.headers.Origin || '';
    if (origin && origin !== ALLOWED_ORIGIN) {
      return { statusCode: 403, headers: CORS_HEADERS, body: JSON.stringify({ error: 'Forbidden origin' }) };
    }

    const payload = event.body ? JSON.parse(event.body) : {};
    const email = (payload.email || '').toString().trim().toLowerCase();
    const otp = (payload.otp || '').toString().trim();
    if (!email || !otp) {
      return { statusCode: 400, headers: CORS_HEADERS, body: JSON.stringify({ error: 'Missing email or otp in request body' }) };
    }

    const a = await ensureAdminInitialized();
    if (!a) {
      return { statusCode: 500, headers: CORS_HEADERS, body: JSON.stringify({ error: 'firebase-admin not available' }) };
    }

    const db = a.firestore();
    const nowTs = a.firestore.Timestamp.now();

    // Find the most recent unused OTP for this email that hasn't expired
    const q = db.collection('otps')
      .where('email', '==', email)
      .where('used', '==', false)
      .where('expiresAt', '>=', nowTs)
      .orderBy('createdAt', 'desc')
      .limit(1);

    const snap = await q.get();
    if (snap.empty) {
      return { statusCode: 400, headers: CORS_HEADERS, body: JSON.stringify({ error: 'No valid OTP found' }) };
    }

    const doc = snap.docs[0];
    const data = doc.data();
    const expectedHash = data.otpHash;
    const givenHash = hashOtp(otp);
    if (expectedHash !== givenHash) {
      return { statusCode: 400, headers: CORS_HEADERS, body: JSON.stringify({ error: 'Invalid OTP' }) };
    }

    // Mark as used
    await doc.ref.update({ used: true, usedAt: a.firestore.Timestamp.now() });

    return { statusCode: 200, headers: CORS_HEADERS, body: JSON.stringify({ success: true }) };
  } catch (err) {
    return { statusCode: 500, headers: CORS_HEADERS, body: JSON.stringify({ error: err.message || String(err) }) };
  }
};
