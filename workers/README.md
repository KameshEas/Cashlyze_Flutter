# Cashlyze API — Cloudflare Worker

Serverless API Worker that handles OTP email delivery and verification for the Cashlyze Flutter app.

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/health` | Health check |
| `POST` | `/api/send-otp` | Send a 6-digit OTP to an email address |
| `POST` | `/api/verify-otp` | Verify a 6-digit OTP |

## Prerequisites

- [Node.js](https://nodejs.org) 18+
- Cloudflare account
- [Wrangler CLI](https://developers.cloudflare.com/workers/wrangler/) (`npm install -g wrangler`)
- [Resend](https://resend.com) API key
- Firebase project with Firestore enabled and a service-account key

## Setup

### 1. Install dependencies

```bash
cd workers
npm install
```

### 2. Authenticate Wrangler

```bash
npx wrangler login
```

### 3. Set secrets

```bash
npx wrangler secret put RESEND_API_KEY
npx wrangler secret put OTP_SECRET
npx wrangler secret put FIREBASE_SERVICE_ACCOUNT
# Paste the full JSON content of your service-account key when prompted
```

### 4. Configure non-secret vars

Edit `wrangler.toml` and update `[vars]`:

```toml
[vars]
ALLOWED_ORIGIN = "https://your-cashlyze-site.pages.dev"
FROM_EMAIL = "Cashlyze <noreply@yourdomain.com>"
```

### 5. Local development

```bash
npm run dev
# Worker available at http://localhost:8787
```

### 6. Deploy

```bash
# Production
npm run deploy

# Staging
npm run deploy:staging
```

After the first deploy, your Worker URL will be:
```
https://cashlyze-api.<your-account>.workers.dev
```

Update `lib/core/utils/api_constants.dart` with this URL.

## Request / Response examples

### Send OTP
```bash
curl -X POST https://cashlyze-api.<account>.workers.dev/api/send-otp \
  -H 'Content-Type: application/json' \
  -d '{"email":"user@example.com"}'
# → {"success":true,"otp":"generated","to":"user@example.com"}
```

### Verify OTP
```bash
curl -X POST https://cashlyze-api.<account>.workers.dev/api/verify-otp \
  -H 'Content-Type: application/json' \
  -d '{"email":"user@example.com","otp":"123456"}'
# → {"success":true}
```

### Health check
```bash
curl https://cashlyze-api.<account>.workers.dev/api/health
# → {"ok":true,"service":"cashlyze-api","endpoints":[...],"timestamp":"..."}
```

## Architecture

```
workers/
├── wrangler.toml              # Wrangler / Worker configuration
├── package.json
├── .env.example               # Template for local dev secrets
└── src/
    ├── index.js               # Entry point — route dispatcher
    ├── handlers/
    │   ├── health.js          # GET /api/health
    │   ├── send-otp.js        # POST /api/send-otp
    │   └── verify-otp.js      # POST /api/verify-otp
    ├── lib/
    │   ├── firebase.js        # Firestore REST API client (no firebase-admin)
    │   └── crypto-utils.js    # Web Crypto helpers (SHA-256 OTP hashing)
    └── utils/
        └── response.js        # JSON response + CORS helpers
```

The Worker uses only Web-standard APIs (Fetch, Web Crypto) — no Node.js built-ins
or heavy SDKs — keeping the bundle tiny and cold-start times minimal.
