# Security Policy

## Reporting a vulnerability

Please do not report exploitable vulnerabilities in public issues. Use GitHub's private vulnerability reporting for this repository if enabled, or contact the repository maintainers privately through their GitHub profile.

Include the affected component, impact, reproduction steps and any relevant logs with secrets removed.

## Sensitive data

Never commit:
- API keys, Cloudflare tokens or account credentials.
- Music platform cookies, QR codes, QR session identifiers or bearer tokens.
- User library contents, personal data or production database exports.
- Private upstream endpoints or deployment secrets.

If a secret is committed, revoke or rotate it immediately. Removing it from a later commit does not make the exposed secret safe.

## Security expectations

- Keep TLS verification enabled.
- Validate provider and redirect URLs; do not create open proxies.
- Apply authentication, rate limiting and bounded request sizes to gateway routes. The Worker enforces an API key, origin allowlist, bounded inbound request metadata and bounded upstream response/time. Cloudflare Rate Limiting bindings currently apply approximate per-client-IP/per-route limits (120 API requests/minute; 6 QR requests/minute); they are local to each Cloudflare location and are not strict global or per-user quotas.
- Avoid logging authorization headers, cookies and query parameters containing credentials.
- Store client credentials in Keychain and server credentials in platform secret storage.
- Do not bypass DRM, subscription checks or provider access controls.

## Production deployment boundary

- The `GATEWAY_API_KEY` is a shared gateway access gate, not a per-user identity system. Any key entered in a distributed client can be extracted by a determined user; do not treat a client-held key as a durable secret or use it as the only production abuse-control mechanism.
- Before a public multi-user release, put user authentication or a trusted server-side authorization layer in front of provider routes, apply per-user and per-IP quotas/rate limits plus account-level abuse controls, and provide a key rotation/revocation procedure. The current IP limiter is only a coarse abuse barrier; mobile carriers and shared networks can aggregate many users behind one address. Keep provider cookies out of URLs and logs.
- Before deploying, verify the two Rate Limiting namespace IDs in `CloudflareGateway/wrangler.toml` are unused in the target Cloudflare account. The API is approximate and location-local; do not treat it as a strict billing, entitlement or security boundary.
- QR login and provider credential behavior must be verified against the exact adapter versions deployed. A successful mocked smoke test does not establish that a provider's real QR flow, credential renewal, or logout semantics work.
