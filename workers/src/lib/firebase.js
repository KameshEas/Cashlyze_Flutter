/**
 * Minimal Firebase / Firestore REST API client for Cloudflare Workers.
 *
 * The Workers runtime cannot run `firebase-admin` (Node.js only).
 * Instead we use Google's public REST APIs with a service-account JWT.
 *
 * Required env secret: FIREBASE_SERVICE_ACCOUNT
 *   The full contents of your Firebase service-account JSON file as a string.
 */

// ─────────────────────────────────────────────────────────────────────────────
// JWT / OAuth helpers
// ─────────────────────────────────────────────────────────────────────────────

function toBase64Url(buffer) {
  const bytes = new Uint8Array(buffer);
  let str = '';
  for (const b of bytes) str += String.fromCharCode(b);
  return btoa(str).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function encodeBase64Url(obj) {
  return toBase64Url(new TextEncoder().encode(JSON.stringify(obj)));
}

/**
 * Import a PEM-encoded RSA private key for signing.
 * @param {string} pem
 * @returns {Promise<CryptoKey>}
 */
async function importPrivateKey(pem) {
  const pemContents = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s+/g, '');

  const binaryDer = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));

  return crypto.subtle.importKey(
    'pkcs8',
    binaryDer.buffer,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
}

/**
 * Create and sign a Google Service Account JWT, then exchange it for an
 * OAuth2 access token.
 *
 * @param {object} serviceAccount  Parsed service-account JSON
 * @returns {Promise<string>}       Bearer access token
 */
export async function getAccessToken(serviceAccount) {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'RS256', typ: 'JWT' };
  const payload = {
    iss: serviceAccount.client_email,
    sub: serviceAccount.client_email,
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
    scope: 'https://www.googleapis.com/auth/cloud-platform',
  };

  const unsigned = `${encodeBase64Url(header)}.${encodeBase64Url(payload)}`;
  const key = await importPrivateKey(serviceAccount.private_key);
  const signatureBuffer = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  );
  const jwt = `${unsigned}.${toBase64Url(signatureBuffer)}`;

  const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });

  if (!tokenRes.ok) {
    const err = await tokenRes.text();
    throw new Error(`Failed to get access token: ${err}`);
  }

  const { access_token } = await tokenRes.json();
  return access_token;
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers for Firestore value types
// ─────────────────────────────────────────────────────────────────────────────

/** Convert a plain JS object to Firestore REST field map. */
function toFirestoreFields(obj) {
  const fields = {};
  for (const [k, v] of Object.entries(obj)) {
    fields[k] = toFirestoreValue(v);
  }
  return fields;
}

function toFirestoreValue(v) {
  if (v === null || v === undefined) return { nullValue: null };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (typeof v === 'number') return { integerValue: String(v) };
  if (typeof v === 'string') return { stringValue: v };
  if (v instanceof Date) return { timestampValue: v.toISOString() };
  if (typeof v === 'object') return { mapValue: { fields: toFirestoreFields(v) } };
  return { stringValue: String(v) };
}

/** Extract a plain JS object from a Firestore REST document. */
export function fromFirestoreDoc(doc) {
  if (!doc || !doc.fields) return null;
  const result = {};
  for (const [k, v] of Object.entries(doc.fields)) {
    result[k] = fromFirestoreValue(v);
  }
  return result;
}

function fromFirestoreValue(v) {
  if (v.nullValue !== undefined) return null;
  if (v.booleanValue !== undefined) return v.booleanValue;
  if (v.integerValue !== undefined) return Number(v.integerValue);
  if (v.doubleValue !== undefined) return v.doubleValue;
  if (v.timestampValue !== undefined) return new Date(v.timestampValue);
  if (v.stringValue !== undefined) return v.stringValue;
  if (v.mapValue !== undefined) return fromFirestoreDoc(v.mapValue);
  if (v.arrayValue !== undefined)
    return (v.arrayValue.values || []).map(fromFirestoreValue);
  return null;
}

// ─────────────────────────────────────────────────────────────────────────────
// Firestore REST operations
// ─────────────────────────────────────────────────────────────────────────────

const FIRESTORE_BASE = 'https://firestore.googleapis.com/v1';

/**
 * Add a new document to a collection.
 * @param {string} projectId
 * @param {string} collection
 * @param {object} data          Plain JS object
 * @param {string} token         OAuth2 access token
 * @returns {Promise<string>}    Created document name
 */
export async function firestoreAdd(projectId, collection, data, token) {
  const url = `${FIRESTORE_BASE}/projects/${projectId}/databases/(default)/documents/${collection}`;
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ fields: toFirestoreFields(data) }),
  });
  if (!res.ok) throw new Error(`Firestore add failed: ${await res.text()}`);
  const doc = await res.json();
  return doc.name;
}

/**
 * Run a Firestore structured query.
 * @param {string} projectId
 * @param {object} structuredQuery  Firestore StructuredQuery object
 * @param {string} token
 * @returns {Promise<Array>}  Array of { name, data } objects
 */
export async function firestoreRunQuery(projectId, structuredQuery, token) {
  const url = `${FIRESTORE_BASE}/projects/${projectId}/databases/(default)/documents:runQuery`;
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ structuredQuery }),
  });
  if (!res.ok) throw new Error(`Firestore query failed: ${await res.text()}`);
  const results = await res.json();
  return results
    .filter((r) => r.document)
    .map((r) => ({ name: r.document.name, data: fromFirestoreDoc(r.document) }));
}

/**
 * Patch (update) specific fields on a Firestore document.
 * @param {string} docName   Full document path e.g. projects/.../documents/otps/abc123
 * @param {object} data      Fields to update
 * @param {string} token
 */
export async function firestorePatch(docName, data, token) {
  const fieldPaths = Object.keys(data).join(',');
  const url = `${FIRESTORE_BASE}/${docName}?updateMask.fieldPaths=${encodeURIComponent(fieldPaths)}`;
  const res = await fetch(url, {
    method: 'PATCH',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ fields: toFirestoreFields(data) }),
  });
  if (!res.ok) throw new Error(`Firestore patch failed: ${await res.text()}`);
}
