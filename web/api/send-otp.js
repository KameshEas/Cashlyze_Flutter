// Netlify Function: send-otp
// Expects POST { "email": "user@example.com" } and optionally { "otp": "123456" }
// Requires environment variable: RESEND_API_KEY
// Optional env: FROM_EMAIL, ALLOWED_ORIGIN (defaults to https://cashlyze.netlify.app)

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
    const from = process.env.FROM_EMAIL || 'onboarding@resend.dev';
    const apiKey = process.env.RESEND_API_KEY;

    if (!apiKey) {
      return {
        statusCode: 500,
        headers: CORS_HEADERS,
        body: JSON.stringify({ error: 'RESEND_API_KEY not configured on server' }),
      };
    }

    const emailHtml = `<p>Your Cashlyze verification code is <strong>${otp}</strong>.</p><p>This code will expire in 10 minutes.</p>`;

    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        from,
        to: email,
        subject: 'Your Cashlyze verification code',
        html: emailHtml,
      }),
    });

    const text = await res.text();
    if (!res.ok) {
      return {
        statusCode: res.status || 502,
        headers: CORS_HEADERS,
        body: JSON.stringify({ error: 'Failed sending email', details: text }),
      };
    }

    return {
      statusCode: 200,
      headers: CORS_HEADERS,
      body: JSON.stringify({ success: true, otp: 'generated', to: email }),
    };
  } catch (err) {
    return {
      statusCode: 500,
      headers: CORS_HEADERS,
      body: JSON.stringify({ error: err.message }),
    };
  }
};
