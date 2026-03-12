// Simple health-check Netlify Function for the API
// GET /.netlify/functions/health
// OPTIONS for CORS preflight

exports.handler = async (event) => {
  const ALLOWED_ORIGIN = process.env.ALLOWED_ORIGIN || 'https://cashlyze.netlify.app';
  const CORS_HEADERS = {
    'Access-Control-Allow-Origin': ALLOWED_ORIGIN,
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  };

  if (event.httpMethod === 'OPTIONS') {
    return { statusCode: 204, headers: CORS_HEADERS, body: '' };
  }

  if (event.httpMethod !== 'GET') {
    return {
      statusCode: 405,
      headers: CORS_HEADERS,
      body: JSON.stringify({ ok: false, error: 'Method Not Allowed' }),
    };
  }

  const payload = {
    ok: true,
    service: 'cashlyze-send-otp',
    functions: ['send-otp'],
    timestamp: new Date().toISOString(),
  };

  return {
    statusCode: 200,
    headers: Object.assign({ 'Content-Type': 'application/json' }, CORS_HEADERS),
    body: JSON.stringify(payload),
  };
};
