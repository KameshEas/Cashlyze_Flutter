/**
 * Cloudflare Workers crypto utilities.
 * Uses the Web Crypto API (available globally in Workers runtime).
 */

/** Returns a hex SHA-256 digest of `otp + secret`. */
export async function hashOtp(otp, secret = '') {
  const encoder = new TextEncoder();
  const data = encoder.encode(otp + secret);
  const buffer = await crypto.subtle.digest('SHA-256', data);
  return Array.from(new Uint8Array(buffer))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}
