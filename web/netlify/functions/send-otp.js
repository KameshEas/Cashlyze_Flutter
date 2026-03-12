const crypto = require('crypto');
let admin;
try {
  // Lazily require firebase-admin to avoid errors where not needed.
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
    return {
      statusCode: 204,
      headers: CORS_HEADERS,
      body: '',
    };
  }

  if (event.httpMethod !== 'POST') {
    return {
      statusCode: 405,
      headers: CORS_HEADERS,
      body: JSON.stringify({ error: 'Method Not Allowed' }),
    };
  }

  try {
    const origin = event.headers.origin || event.headers.Origin || '';
    if (origin && origin !== ALLOWED_ORIGIN) {
      return {
        statusCode: 403,
        headers: CORS_HEADERS,
        body: JSON.stringify({ error: 'Forbidden origin' }),
      };
    }

    const payload = event.body ? JSON.parse(event.body) : {};
    const email = (payload.email || '').toString().trim();
    if (!email) {
      return {
        statusCode: 400,
        headers: CORS_HEADERS,
        body: JSON.stringify({ error: 'Missing email in request body' }),
      };
    }

    const otp = payload.otp || (Math.floor(100000 + Math.random() * 900000)).toString();
    const from = process.env.FROM_EMAIL || 'Cashlyze <noreply@aspired2d.cloud>';
    const apiKey = process.env.RESEND_API_KEY;

    if (!apiKey) {
      return {
        statusCode: 500,
        headers: CORS_HEADERS,
        body: JSON.stringify({ error: 'RESEND_API_KEY not configured on server' }),
      };
    }

    // Resend's /emails API requires an explicit `text` or `html` field.
    // (Resend "templates" are dashboard-only and cannot be used programmatically
    // with variable substitution via the REST API.)
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
        '© Cashlyze · https://cashlyze.netlify.app',
      ].join('\n'),
    };

    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`,
      },
      body: JSON.stringify(emailPayload),
    });

    const text = await res.text();
    if (!res.ok) {
      return {
        statusCode: res.status || 502,
        headers: CORS_HEADERS,
        body: JSON.stringify({ error: 'Failed sending email', details: text }),
      };
    }

    // Store hashed OTP in Firestore for later verification (expires in 10 minutes)
    try {
      const a = await ensureAdminInitialized();
      if (!a) throw new Error('firebase-admin not available');
      const db = a.firestore();
      const now = Date.now();
      const expiresAt = new Date(now + 10 * 60 * 1000);
      const doc = {
        email: email.toLowerCase(),
        otpHash: hashOtp(otp),
        createdAt: a.firestore.Timestamp.fromMillis(now),
        expiresAt: a.firestore.Timestamp.fromMillis(expiresAt.getTime()),
        used: false,
      };
      await db.collection('otps').add(doc);
    } catch (e) {
      // Non-fatal: log server-side but keep going to allow email delivery to be tested.
      console.error('Failed to store OTP in Firestore:', e.message || e);
    }

    const devReturnOtp = process.env.DEV_RETURN_OTP === 'true';
    const responseBody = devReturnOtp
      ? { success: true, otp: otp, to: email }
      : { success: true, otp: 'generated', to: email };

    return {
      statusCode: 200,
      headers: CORS_HEADERS,
      body: JSON.stringify(responseBody),
    };
  } catch (err) {
    return {
      statusCode: 500,
      headers: CORS_HEADERS,
      body: JSON.stringify({ error: err.message }),
    };
  }
};
