Send OTP via Resend
--------------------

This directory contains a Netlify-compatible serverless function to send OTP (one-time passwords) using the Resend HTTP API.

Files
- send-otp.js — Netlify function handler. POST to this endpoint with JSON { "email": "..." }.
- .env.example — Example environment variables.

Environment
- `RESEND_API_KEY` (required) — your Resend API key. Set in your hosting provider's environment settings.
- `FROM_EMAIL` (optional) — email address to appear in the "from" field.
- `ALLOWED_ORIGIN` (optional) — allowed origin for CORS. Defaults to `https://cashlyze.netlify.app`.

Usage
1. Configure environment variables in your host (do not commit keys).
2. Deploy the `web` folder to Netlify (or any platform that supports AWS Lambda / Netlify Functions).
3. Send a POST request to the function, e.g. if deployed at `https://your-site.netlify.app` the function URL will be `https://your-site.netlify.app/.netlify/functions/send-otp`.

Example curl

```bash
curl -X POST 'https://your-site.netlify.app/.netlify/functions/send-otp' \
  -H 'Content-Type: application/json' \
  -d '{"email":"user@example.com"}'
```

Security note
- Do not store the `RESEND_API_KEY` in client-side code. Always keep it server-side.
